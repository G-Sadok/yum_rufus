import Core
import Foundation
@testable import Sources

//
// ServeurNfsDeTest
//
// Un serveur NFS version trois qui tient dans un canal.
//
// Il decode reellement les appels qu il recoit, au lieu de rejouer des reponses
// figees. C est ce qui donne au test sa valeur : un descripteur mal encode, un
// remplissage oublie ou un argument dans le mauvais ordre se soldent par un
// appel que ce serveur ne comprend pas, donc par un test rouge. Une reponse
// figee, elle, aurait valide n importe quel appel.
//
// Il ne couvre que les cinq procedures dont le partage se sert, et c est
// volontaire. Un serveur NFS complet dans une suite de tests serait un second
// projet, et les procedures d ecriture n ont rien a y faire puisque le partage
// est monte en lecture seule.
//

/// Ce qu un chemin porte sur le serveur NFS de test.
enum NoeudNfs: Sendable {
    case dossier
    case fichier(ContenuSimule)
}

/// Canal qui repond en NFS version trois sans ouvrir de connexion.
actor CanalNfsDeTest: CanalReseau {
    /// Nombre maximal d octets rendus par lecture, comme un vrai serveur.
    static let lectureMaximale = 8 * 1024

    /// Chemin de l export publie.
    let export: String

    private var arbre: [String: NoeudNfs]
    private var aRendre = Data()

    /// Les procedures reellement appelees, dans l ordre.
    private(set) var procedures: [UInt32] = []

    /// Nombre d octets rendus par les lectures.
    private(set) var octetsServis: UInt64 = 0

    /// Vrai quand le canal a ete ouvert au moins une fois.
    private(set) var ouvert = false

    init(export: String = "/export", arbre: [String: NoeudNfs]) {
        self.export = export
        self.arbre = arbre
    }

    // MARK: Canal

    func ouvrir() async throws {
        ouvert = true
    }

    func envoyer(_ octets: Data) async throws {
        var lecture = LectureXdr(octets)

        guard let entete = lecture.entier32() else {
            throw ErreurReseau.reponseIllisible
        }

        let longueur = Int(entete & 0x7FFF_FFFF)

        guard let corps = lecture.fixe(longueur) else {
            throw ErreurReseau.reponseTronquee
        }

        try aRendre.append(ClientRpc.marquer(repondre(a: corps)))
    }

    func recevoir(exactement longueur: Int) async throws -> Data {
        guard aRendre.count >= longueur else {
            throw ErreurReseau.reponseTronquee
        }

        let debut = aRendre.startIndex
        let trame = aRendre.subdata(in: debut..<(debut + longueur))
        aRendre.removeFirst(longueur)

        return trame
    }

    func fermer() async {
        ouvert = false
        aRendre.removeAll()
    }

    // MARK: Reponses

    /// Decode un appel et fabrique la reponse qui lui correspond.
    private func repondre(a appel: Data) throws -> Data {
        var lecture = LectureXdr(appel)

        guard let identifiant = lecture.entier32(),
              lecture.entier32() == 0,
              lecture.entier32() == 2,
              let programme = lecture.entier32(),
              let version = lecture.entier32(),
              let procedure = lecture.entier32(),
              lecture.entier32() == 1,
              lecture.variable() != nil,
              lecture.entier32() != nil,
              lecture.variable() != nil
        else {
            throw ErreurReseau.reponseIllisible
        }

        procedures.append(procedure)

        let resultat = try corpsDeLaReponse(
            programme: programme,
            version: version,
            procedure: procedure,
            arguments: &lecture
        )

        var ecriture = EcritureXdr()
        ecriture.entier32(identifiant)
        ecriture.entier32(1)
        ecriture.entier32(0)
        ecriture.entier32(0)
        ecriture.entier32(0)
        ecriture.entier32(0)
        ecriture.ajouter(resultat)

        return ecriture.octets
    }

    private func corpsDeLaReponse(
        programme: UInt32,
        version: UInt32,
        procedure: UInt32,
        arguments: inout LectureXdr
    ) throws -> Data {
        switch (programme, version, procedure) {
        case (100_000, 2, 3):
            return port()
        case (100_005, 3, 1):
            return try montage(&arguments)
        case (100_003, 3, 1):
            return try attributs(&arguments)
        case (100_003, 3, 3):
            return try recherche(&arguments)
        case (100_003, 3, 6):
            return try lecture(&arguments)
        case (100_003, 3, 17):
            return try listage(&arguments)
        default:
            throw ErreurReseau.reponseInattendue(code: Int(procedure))
        }
    }

    /// Le port du service de montage, ici fixe.
    private func port() -> Data {
        var ecriture = EcritureXdr()
        ecriture.entier32(20048)

        return ecriture.octets
    }

    private func montage(_ arguments: inout LectureXdr) throws -> Data {
        guard let demande = arguments.texte() else {
            throw ErreurReseau.reponseIllisible
        }

        var ecriture = EcritureXdr()

        guard demande == export else {
            // Le code un est celui d un export inconnu.
            ecriture.entier32(1)

            return ecriture.octets
        }

        ecriture.entier32(0)
        ecriture.variable(EncodageNfsDeTest.descripteur(de: ""))
        ecriture.entier32(1)
        ecriture.entier32(1)

        return ecriture.octets
    }

    private func attributs(_ arguments: inout LectureXdr) throws -> Data {
        guard let descripteur = arguments.variable(), let chemin = EncodageNfsDeTest.chemin(de: descripteur) else {
            throw ErreurReseau.reponseIllisible
        }

        var ecriture = EcritureXdr()

        guard let noeud = arbre[chemin] else {
            ecriture.entier32(2)

            return ecriture.octets
        }

        ecriture.entier32(0)
        ecriture.ajouter(EncodageNfsDeTest.blocDAttributs(noeud))

        return ecriture.octets
    }

    private func recherche(_ arguments: inout LectureXdr) throws -> Data {
        guard let dossier = arguments.variable(),
              let parent = EncodageNfsDeTest.chemin(de: dossier),
              let nom = arguments.texte()
        else {
            throw ErreurReseau.reponseIllisible
        }

        let chemin = CheminDePartage.joindre(parent, nom)
        var ecriture = EcritureXdr()

        guard let noeud = arbre[chemin] else {
            ecriture.entier32(2)

            return ecriture.octets
        }

        ecriture.entier32(0)
        ecriture.variable(EncodageNfsDeTest.descripteur(de: chemin))
        ecriture.booleen(true)
        ecriture.ajouter(EncodageNfsDeTest.blocDAttributs(noeud))
        ecriture.booleen(false)

        return ecriture.octets
    }

    private func lecture(_ arguments: inout LectureXdr) throws -> Data {
        guard let descripteur = arguments.variable(),
              let chemin = EncodageNfsDeTest.chemin(de: descripteur),
              let offset = arguments.entier64(),
              let demande = arguments.entier32()
        else {
            throw ErreurReseau.reponseIllisible
        }

        var ecriture = EcritureXdr()

        guard case let .fichier(contenu)? = arbre[chemin] else {
            ecriture.entier32(2)

            return ecriture.octets
        }

        let longueur = Int(min(UInt64(demande), UInt64(Self.lectureMaximale)))
        let octets = contenu.octets(a: offset, longueur: longueur)
        octetsServis += UInt64(octets.count)

        ecriture.entier32(0)
        ecriture.booleen(true)
        ecriture.ajouter(EncodageNfsDeTest.blocDAttributs(.fichier(contenu)))
        ecriture.entier32(UInt32(octets.count))
        ecriture.booleen(offset + UInt64(octets.count) >= contenu.taille)
        ecriture.variable(octets)

        return ecriture.octets
    }

    private func listage(_ arguments: inout LectureXdr) throws -> Data {
        guard let descripteur = arguments.variable(),
              let parent = EncodageNfsDeTest.chemin(de: descripteur),
              arguments.entier64() != nil,
              arguments.fixe(8) != nil,
              arguments.entier32() != nil,
              arguments.entier32() != nil
        else {
            throw ErreurReseau.reponseIllisible
        }

        var ecriture = EcritureXdr()

        guard case .dossier? = arbre[parent] else {
            ecriture.entier32(2)

            return ecriture.octets
        }

        ecriture.entier32(0)
        ecriture.booleen(true)
        ecriture.ajouter(EncodageNfsDeTest.blocDAttributs(.dossier))
        ecriture.fixe(Data(repeating: 0, count: 8))

        // Le dossier lui meme et son parent sont annonces comme un vrai serveur
        // le fait. Le partage doit les ecarter, sans quoi l analyse boucle.
        for nom in [".", ".."] {
            ecriture.booleen(true)
            ecriture.entier64(1)
            ecriture.texte(nom)
            ecriture.entier64(1)
            ecriture.booleen(true)
            ecriture.ajouter(EncodageNfsDeTest.blocDAttributs(.dossier))
            ecriture.booleen(false)
        }

        var rang: UInt64 = 2

        for chemin in arbre.keys.sorted() where EncodageNfsDeTest.parent(de: chemin) == parent && chemin != parent {
            guard let noeud = arbre[chemin] else {
                continue
            }

            rang += 1
            ecriture.booleen(true)
            ecriture.entier64(rang)
            ecriture.texte(CheminDePartage.nom(de: chemin))
            ecriture.entier64(rang)
            ecriture.booleen(true)
            ecriture.ajouter(EncodageNfsDeTest.blocDAttributs(noeud))
            ecriture.booleen(true)
            ecriture.variable(EncodageNfsDeTest.descripteur(de: chemin))
        }

        ecriture.booleen(false)
        ecriture.booleen(true)

        return ecriture.octets
    }
}

///
/// EncodageNfsDeTest
///
/// Ce que le serveur de test ecrit sur le fil, et la facon dont il fabrique ses
/// descripteurs.
///
/// Le descripteur est un chemin prefixe, et rien de plus. Un vrai serveur y range
/// un numero d inode et un identifiant de systeme de fichiers ; ce qui compte
/// pour le test est seulement qu il soit opaque cote client, ce que le prefixe
/// garantit : un client qui fabriquerait un descripteur au lieu de le recevoir ne
/// tomberait jamais sur la bonne forme.
///
enum EncodageNfsDeTest {
    /// Le bloc d attributs de quatre vingt quatre octets impose par la norme.
    static func blocDAttributs(_ noeud: NoeudNfs) -> Data {
        var ecriture = EcritureXdr()

        switch noeud {
        case .dossier:
            ecriture.entier32(2)
            ecriture.entier32(0o040755)
        case .fichier:
            ecriture.entier32(1)
            ecriture.entier32(0o100644)
        }

        ecriture.entier32(1)
        ecriture.entier32(0)
        ecriture.entier32(0)

        let taille: UInt64 = if case let .fichier(contenu) = noeud {
            contenu.taille
        } else {
            4096
        }

        ecriture.entier64(taille)
        ecriture.entier64(taille)
        ecriture.entier32(0)
        ecriture.entier32(0)
        ecriture.entier64(1)
        ecriture.entier64(2)
        ecriture.entier32(1_700_000_000)
        ecriture.entier32(0)
        ecriture.entier32(1_700_000_100)
        ecriture.entier32(0)
        ecriture.entier32(1_700_000_200)
        ecriture.entier32(0)

        return ecriture.octets
    }

    /// Le descripteur d un chemin, opaque cote client comme cote serveur.
    static func descripteur(de chemin: String) -> Data {
        Data(("fh:" + chemin).utf8)
    }

    /// Le chemin que porte un descripteur, ou nul s il n en vient pas.
    static func chemin(de descripteur: Data) -> String? {
        guard let texte = String(bytes: descripteur, encoding: .utf8), texte.hasPrefix("fh:") else {
            return nil
        }

        return String(texte.dropFirst(3))
    }

    /// Le dossier qui porte ce chemin, chaine vide pour la racine.
    static func parent(de chemin: String) -> String {
        guard let separateur = chemin.lastIndex(of: "/") else {
            return ""
        }

        return String(chemin[chemin.startIndex..<separateur])
    }
}
