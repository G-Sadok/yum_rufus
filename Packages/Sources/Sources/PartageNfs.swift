import Core
import Foundation

//
// PartageNfs
//
// Le partage NFS du tableau 4.2, en version trois, monte en lecture seule.
//
// La version trois et non la quatre, et le choix se defend. La version quatre
// est un protocole a etat, avec baux a renouveler, delegations a rendre et
// recuperation apres redemarrage du serveur ; elle demande une machine a etats
// qui vit en permanence, meme quand personne ne lit. La version trois est sans
// etat : chaque appel porte le descripteur du fichier qu il vise, donc une
// coupure ne perd rien d autre que l appel en cours, et la reprise du deuxieme
// critere est gratuite. Sur un NAS domestique, qui est le cas d usage de cette
// fonctionnalite, la version trois est de plus celle qui est activee par defaut.
//
// Trois programmes distincts participent, et il faut les trois.
//
// Le premier est le repertoire de ports, qui dit sur quel port ecoute le
// service de montage. Ce port change a chaque demarrage du serveur sur la
// plupart des systemes, le coder en dur ne marcherait que par chance.
//
// Le deuxieme est le service de montage, qui echange un chemin d export contre
// le descripteur de son dossier racine. C est la seule facon d obtenir un
// premier descripteur : tous les autres se deduisent de celui la, de proche en
// proche, par des recherches de noms.
//
// Le troisieme est NFS lui meme, qui ecoute presque toujours sur le port 2049.
//
// Aucun mot de passe ne circule, et ce n est pas un oubli. NFS version trois
// n en a pas : il annonce un identifiant d utilisateur, et le serveur decide d y
// croire selon l adresse d ou vient l appel. Un export se protege par reseau,
// jamais par identifiants, et la feuille de configuration doit le dire.
//

/// Partage reseau servi par un export NFS version trois.
public actor PartageNfs: PartageReseau {
    /// Numeros des trois programmes employes.
    enum Programme {
        static let repertoireDePorts: UInt32 = 100_000
        static let montage: UInt32 = 100_005
        static let fichiers: UInt32 = 100_003
    }

    /// Port sur lequel NFS ecoute presque toujours.
    public static let portParDefaut: UInt16 = 2049

    /// Nombre d octets demandes au plus par lecture.
    ///
    /// Trente deux kilo octets est la taille de lecture que les serveurs NFS
    /// annoncent le plus souvent. Demander davantage ne rend pas davantage, et
    /// demander moins multiplie les allers retours pour rien.
    public static let lectureMaximale = 32 * 1024

    /// Nombre d entrees demandees par tour de listage.
    static let entreesParTour: UInt32 = 8 * 1024

    public nonisolated let libelle: String

    /// Chemin de l export, tel que le serveur le publie.
    let export: String

    let clientNfs: ClientRpc
    let clientMontage: ClientRpc

    /// Descripteur du dossier racine de l export, obtenu au montage.
    var racine: Data?

    /// Descripteurs deja resolus, par chemin relatif.
    ///
    /// NFS ne connait pas les chemins : il ne connait que des descripteurs et
    /// des recherches de nom. Sans cette memoire, ouvrir la page d un chapitre
    /// range trois niveaux plus bas couterait trois recherches a chaque lecture
    /// de plage, soit trois allers retours par bloc.
    var descripteurs: [String: Data] = [:]

    /// Attributs deja lus, par chemin relatif.
    var attributsConnus: [String: EntreeDePartage] = [:]

    /// Construit le partage sur les canaux des deux services.
    ///
    /// - Parameters:
    ///   - canalNfs: canal vers le service de fichiers, port 2049 en general.
    ///   - canalMontage: canal vers le service de montage, dont le port se
    ///     demande au repertoire de ports.
    public init(
        libelle: String,
        export: String,
        canalNfs: any CanalReseau,
        canalMontage: any CanalReseau,
        identite: IdentiteUnix = IdentiteUnix()
    ) {
        self.libelle = libelle
        self.export = export.hasPrefix("/") ? export : "/" + export
        clientNfs = ClientRpc(canal: canalNfs, identite: identite)
        clientMontage = ClientRpc(canal: canalMontage, identite: identite)
    }

    // MARK: Protocole

    public func lister(_ chemin: String) async throws -> [EntreeDePartage] {
        let descripteur = try await descripteur(de: chemin)

        var entrees: [EntreeDePartage] = []
        var curseur: UInt64 = 0
        var verificateur = Data(repeating: 0, count: 8)

        while true {
            try Task.checkCancellation()

            let tour = try await lireUnTourDeDossier(
                descripteur,
                parent: chemin,
                curseur: curseur,
                verificateur: verificateur
            )

            entrees.append(contentsOf: tour.entrees)

            for entree in tour.entrees {
                attributsConnus[entree.chemin] = entree
            }
            for (chemin, descripteur) in tour.descripteurs {
                descripteurs[chemin] = descripteur
            }

            guard tour.termine == false, let dernier = tour.dernierCurseur else {
                return entrees
            }

            curseur = dernier
            verificateur = tour.verificateur
        }
    }

    public func attributs(de chemin: String) async throws -> EntreeDePartage {
        if let connus = attributsConnus[chemin] {
            return connus
        }

        let descripteur = try await descripteur(de: chemin)
        let attributs = try await attributs(descripteur: descripteur, chemin: chemin)
        attributsConnus[chemin] = attributs

        return attributs
    }

    public func lire(_ chemin: String, a offset: UInt64, longueur: Int) async throws -> Data {
        guard longueur > 0 else {
            return Data()
        }

        let descripteur = try await descripteur(de: chemin)
        let demande = min(longueur, Self.lectureMaximale)

        var arguments = EcritureXdr()
        arguments.variable(descripteur)
        arguments.entier64(offset)
        arguments.entier32(UInt32(demande))

        var resultat = try await appeler(procedure: 6, arguments: arguments.octets)

        try Self.verifierLeStatut(&resultat)

        // Attributs du fichier apres lecture, puis compte, drapeau de fin, et
        // enfin les octets. Les attributs sont sautes : la taille qui compte est
        // celle qui a servi a ouvrir le conteneur, et la relire ici ferait
        // changer la taille d une archive au milieu de sa lecture.
        _ = AttributsNfs.lireOptionnels(&resultat)

        guard resultat.entier32() != nil, resultat.booleen() != nil, let octets = resultat.variable() else {
            throw ErreurReseau.reponseTronquee
        }

        return octets
    }

    public func fermer() async {
        racine = nil
        descripteurs.removeAll()
        attributsConnus.removeAll()
    }

    // MARK: Montage

    /// Ouvre un partage sur un serveur NFS joint par TCP.
    ///
    /// Le port du service de montage est demande au repertoire de ports, parce
    /// qu il change a chaque demarrage du serveur sur la plupart des systemes.
    ///
    /// - Throws: `ErreurReseau`, dans le cas nomme qui correspond a ce qui s est
    ///   passe, notamment `connexionRefusee` quand le repertoire de ports ne
    ///   connait aucun service de montage, ce qui veut dire que l hote ne sert
    ///   pas de NFS.
    public static func surTcp(
        libelle: String,
        hote: String,
        export: String,
        portNfs: UInt16 = PartageNfs.portParDefaut,
        identite: IdentiteUnix = IdentiteUnix()
    ) async throws -> PartageNfs {
        let repertoire = CanalTcp(hote: hote, port: 111)
        let portDeMontage = try await portDuService(
            Programme.montage,
            version: 3,
            client: ClientRpc(canal: repertoire, identite: identite)
        )
        await repertoire.fermer()

        return PartageNfs(
            libelle: libelle,
            export: export,
            canalNfs: CanalTcp(hote: hote, port: portNfs),
            canalMontage: CanalTcp(hote: hote, port: portDeMontage),
            identite: identite
        )
    }

    /// Demande au repertoire de ports le port d un programme.
    ///
    /// - Parameter protocole: six pour TCP, la seule valeur employee ici.
    static func portDuService(
        _ programme: UInt32,
        version: UInt32,
        protocole: UInt32 = 6,
        client: ClientRpc
    ) async throws -> UInt16 {
        var arguments = EcritureXdr()
        arguments.entier32(programme)
        arguments.entier32(version)
        arguments.entier32(protocole)
        arguments.entier32(0)

        var resultat = try await client.appeler(
            programme: Programme.repertoireDePorts,
            version: 2,
            procedure: 3,
            arguments: arguments.octets
        )

        guard let port = resultat.entier32(), port > 0, port <= UInt32(UInt16.max) else {
            throw ErreurReseau.connexionRefusee
        }

        return UInt16(port)
    }

    /// Monte l export et rend le descripteur de sa racine.
    ///
    /// Interne et non prive : la resolution des descripteurs vit dans un autre
    /// fichier, et c est elle qui a besoin du premier d entre eux.
    func monter() async throws -> Data {
        if let racine {
            return racine
        }

        var arguments = EcritureXdr()
        arguments.texte(export)

        var resultat = try await clientMontage.appeler(
            programme: Programme.montage,
            version: 3,
            procedure: 1,
            arguments: arguments.octets
        )

        guard let statut = resultat.entier32() else {
            throw ErreurReseau.reponseIllisible
        }
        guard statut == 0 else {
            throw ErreurRpc.statut(programme: Programme.montage, code: statut).reseau
        }
        guard let descripteur = resultat.variable(), descripteur.isEmpty == false else {
            throw ErreurReseau.reponseIllisible
        }

        racine = descripteur

        return descripteur
    }
}
