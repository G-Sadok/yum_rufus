import Core
import Foundation

//
// PartageSmb
//
// Le partage SMB du tableau 4.2, en dialecte deux, monte en lecture seule.
//
// La session s ouvre en quatre temps, et les quatre sont obligatoires avant la
// premiere lecture : negocier le dialecte, ouvrir la session par NTLM version
// deux, se connecter a l arborescence du partage, puis ouvrir le fichier. Les
// quatre etats vivent dans cet acteur parce qu ils vivent dans la connexion, et
// c est ce qui explique que le partage soit un acteur et non une structure.
//
// Le fichier ne porte que ce que le protocole `PartageReseau` demande. La
// negociation et l ouverture de session vivent dans `SessionSmb`, l ouverture de
// fichiers et le listage dans `FichiersSmb` : trois sujets distincts, dont un
// seul, celui d ici, est lu par le reste du projet.
//
// Le chiffrement du dialecte trois n est pas mis en oeuvre, et le dialecte n est
// donc pas annonce. Annoncer un dialecte dont on ne tient pas les obligations
// est la meilleure facon d obtenir des refus incomprehensibles chez la moitie
// des serveurs.
//
// Les descripteurs de fichiers ouverts sont retenus par chemin. Un CBZ lu en
// flux demande une dizaine de lectures pour une seule page, et rouvrir le
// fichier a chaque plage couterait deux allers retours de plus par bloc, pour
// rien.
//

/// Ce que l utilisateur a saisi pour un partage SMB.
public enum IdentifiantsSmb: Sendable, Hashable {
    /// Connexion invitee, sans compte.
    case invite

    /// Compte et mot de passe, avec le domaine quand le serveur en a un.
    case compte(compte: String, motDePasse: String, domaine: String = "")
}

/// Partage reseau servi par un serveur SMB version deux.
public actor PartageSmb: PartageReseau {
    /// Dialectes annonces, du plus ancien au plus recent.
    static let dialectes: [UInt16] = [0x0202, 0x0210]

    /// Nombre d octets demandes au plus par lecture.
    ///
    /// Un mega octet est la taille de lecture que les serveurs annoncent le plus
    /// souvent. La valeur reelle est celle que la negociation rend, et c est elle
    /// qui borne les demandes ; celle ci n est que le plafond de depart.
    public static let lectureMaximale: UInt32 = 1024 * 1024

    /// Taille du tampon demande pour un listage de dossier.
    static let tamponDeListage: UInt32 = 64 * 1024

    /// Drapeau du mode de securite qui dit que le serveur exige la signature.
    static let signatureExigee: UInt16 = 0x0002

    /// Attribut qui marque un dossier dans une reponse SMB.
    static let attributDeDossier: UInt32 = 0x0000_0010

    public nonisolated let libelle: String

    let hote: String
    let partage: String
    let identifiants: IdentifiantsSmb
    let canal: any CanalReseau
    let posteDeTravail: String
    let defiDuClient: @Sendable () -> Data
    let horodatage: @Sendable () -> UInt64

    var prochainMessage: UInt64 = 0
    var session: UInt64 = 0
    var arborescence: UInt32 = 0
    var cleDeSignature: Data?
    var lectureMaximaleNegociee = PartageSmb.lectureMaximale
    var signatureReclamee = false
    var ouverte = false

    var descripteurs: [String: Data] = [:]
    var attributsConnus: [String: EntreeDePartage] = [:]

    /// Construit le partage sur un canal deja pret.
    ///
    /// - Parameters:
    ///   - defiDuClient: huit octets tires au hasard pour l echange NTLM.
    ///     Injectes pour que les tests puissent recalculer la preuve.
    ///   - horodatage: instant Windows employe par l echange NTLM, injecte pour
    ///     la meme raison.
    public init(
        libelle: String,
        hote: String,
        partage: String,
        canal: any CanalReseau,
        identifiants: IdentifiantsSmb = .invite,
        posteDeTravail: String = "TSUZUKI",
        defiDuClient: @escaping @Sendable () -> Data = PartageSmb.defiAleatoire,
        horodatage: @escaping @Sendable () -> UInt64 = PartageSmb.horodatageWindows
    ) {
        self.libelle = libelle
        self.hote = hote
        self.partage = partage
        self.canal = canal
        self.identifiants = identifiants
        self.posteDeTravail = posteDeTravail
        self.defiDuClient = defiDuClient
        self.horodatage = horodatage
    }

    /// Ouvre un partage sur un serveur SMB joint par TCP.
    public static func surTcp(
        libelle: String,
        hote: String,
        partage: String,
        port: UInt16 = 445,
        identifiants: IdentifiantsSmb = .invite
    ) -> PartageSmb {
        PartageSmb(
            libelle: libelle,
            hote: hote,
            partage: partage,
            canal: CanalTcp(hote: hote, port: port),
            identifiants: identifiants
        )
    }

    /// Huit octets tires au hasard, comme la norme l exige.
    public static let defiAleatoire: @Sendable () -> Data = {
        var octets = Data(count: 8)
        octets.withUnsafeMutableBytes { tampon in
            for indice in 0..<tampon.count {
                tampon[indice] = UInt8.random(in: 0...255)
            }
        }

        return octets
    }

    /// L instant courant, compte comme Windows le compte.
    public static let horodatageWindows: @Sendable () -> UInt64 = {
        UInt64((Date().timeIntervalSince1970 + NomsSmb2.secondesEntre1601Et1970) * 10_000_000)
    }

    // MARK: Protocole

    public func lister(_ chemin: String) async throws -> [EntreeDePartage] {
        try await preparer()

        let descripteur = try await ouvrirDescripteur(chemin, dossier: true)

        defer {
            Task { await self.fermerDescripteur(descripteur) }
        }

        var entrees: [EntreeDePartage] = []

        while let tour = try await interrogerLeDossier(descripteur, parent: chemin) {
            try Task.checkCancellation()
            entrees.append(contentsOf: tour)
        }

        for entree in entrees {
            attributsConnus[entree.chemin] = entree
        }

        return entrees
    }

    public func attributs(de chemin: String) async throws -> EntreeDePartage {
        if let connus = attributsConnus[chemin] {
            return connus
        }

        try await preparer()

        let ouverture = try await creer(chemin, dossier: false)
        descripteurs[chemin] = ouverture.descripteur

        let entree = EntreeDePartage(
            chemin: chemin,
            estDossier: ouverture.estDossier,
            taille: ouverture.taille,
            dateModification: NomsSmb2.date(ouverture.derniereEcriture)
        )
        attributsConnus[chemin] = entree

        return entree
    }

    public func lire(_ chemin: String, a offset: UInt64, longueur: Int) async throws -> Data {
        guard longueur > 0 else {
            return Data()
        }

        try await preparer()

        let descripteur = try await ouvrirDescripteur(chemin, dossier: false)
        let demande = min(UInt32(min(longueur, Int(UInt32.max))), lectureMaximaleNegociee)

        var corps = EcritureSmb2()
        corps.entier16(49)
        corps.entier8(0)
        corps.entier8(0)
        corps.entier32(demande)
        corps.entier64(offset)
        corps.fixe(descripteur)
        corps.entier32(1)
        corps.entier32(0)
        corps.entier32(0)
        corps.entier16(0)
        corps.entier16(0)
        corps.entier8(0)

        let reponse = try await echanger(.lire, corps: corps.octets, statutsAcceptes: [StatutSmb2.finDeFichier])

        guard reponse.entete.statut != StatutSmb2.finDeFichier else {
            return Data()
        }

        return try Self.octetsLus(dans: reponse)
    }

    public func fermer() async {
        for descripteur in descripteurs.values {
            await fermerDescripteur(descripteur)
        }

        descripteurs.removeAll()
        attributsConnus.removeAll()
        session = 0
        arborescence = 0
        cleDeSignature = nil
        ouverte = false

        await canal.fermer()
    }

    /// Extrait les octets rendus par une reponse de lecture.
    ///
    /// La position des octets est comptee depuis le debut de l en tete et non
    /// depuis le debut du corps. La compter depuis le corps rendrait la page
    /// decalee de soixante quatre octets, ce que la somme de controle du ZIP
    /// signalerait comme une archive corrompue plutot que comme un defaut de
    /// lecture.
    static func octetsLus(dans reponse: ReponseSmb2) throws -> Data {
        var lecture = LectureSmb2(reponse.corps)

        guard lecture.entier16() == 17,
              let position = lecture.entier8(),
              lecture.sauter(1),
              let longueur = lecture.entier32()
        else {
            throw ErreurReseau.reponseIllisible
        }
        guard let octets = lecture.tranche(a: Int(position) - EnTeteSmb2.taille, longueur: Int(longueur)) else {
            throw ErreurReseau.reponseTronquee
        }

        return octets
    }
}
