import Foundation

//
// DepotICloud
//
// Ce que le systeme sait dire d un fichier d iCloud Drive, et le seul moyen de
// lui demander de le rapatrier.
//
// Le protocole existe pour une raison de verification. Un telechargement iCloud
// reel demande un compte, un reseau, et un delai que personne ne controle : une
// suite de tests qui en dependrait ne prouverait rien et ne passerait nulle
// part. Le telechargeur, lui, doit etre verifiable pas a pas, y compris sur le
// telechargement qui n avance plus. Il parle donc a ce protocole, dont
// `DepotICloudDuSysteme` est l implementation reelle.
//

/// Presence d un fichier d iCloud Drive sur l appareil.
public enum PresenceICloud: Sendable, Equatable {
    /// Le fichier est la, en entier, et se lit immediatement.
    case local

    /// Le fichier existe dans le nuage mais rien n a encore ete rapatrie.
    case absent

    /// Le rapatriement est en cours, une partie des octets est deja la.
    case enCours
}

/// Etat d un fichier d iCloud Drive a un instant donne.
public struct EtatDeFichierICloud: Sendable, Equatable {
    public let presence: PresenceICloud

    /// Octets deja poses sur l appareil.
    public let octetsPresents: Int64

    /// Poids annonce du fichier complet.
    ///
    /// Connu meme quand rien n est telecharge : c est le nuage qui l annonce,
    /// et c est ce qui permet d afficher une progression des le premier octet
    /// plutot qu une attente sans fin annoncee.
    public let octetsAttendus: Int64

    public init(presence: PresenceICloud, octetsPresents: Int64, octetsAttendus: Int64) {
        self.presence = presence
        self.octetsPresents = max(0, octetsPresents)
        self.octetsAttendus = max(0, octetsAttendus)
    }

    /// Vrai quand le fichier se lit sans rien attendre.
    public var estLocal: Bool {
        presence == .local
    }
}

/// Acces au dossier iCloud Drive, vu du telechargeur.
public protocol DepotICloud: Sendable {
    /// Rend l etat du fichier tel que le systeme le connait maintenant.
    ///
    /// - Parameter fichier: emplacement reel sur le disque, substitut compris.
    func etat(de fichier: URL) async throws -> EtatDeFichierICloud

    /// Demande au systeme de rapatrier le fichier.
    ///
    /// La demande rend la main aussitot. Le telechargement se suit ensuite par
    /// `etat(de:)`, parce que c est le systeme qui le mene et non nous.
    func demanderLeTelechargement(de fichier: URL) async throws
}

/// Avancement du rapatriement d un fichier, tel qu il est publie.
public struct ProgressionDeTelechargement: Sendable, Equatable {
    /// Ce que le telechargement rapatrie, du point de vue de l appelant.
    ///
    /// C est l identifiant de chapitre quand la source en demande un, ce qui
    /// permet a un ecran de rattacher la progression a la ligne qu il affiche
    /// sans connaitre le moindre chemin de fichier.
    public let identifiant: String

    public let octetsRecus: Int64
    public let octetsAttendus: Int64

    /// Vrai pour la derniere progression d un telechargement, et elle seule.
    ///
    /// Le drapeau est porte plutot que deduit d une comparaison d octets : un
    /// fichier vide a autant d octets recus qu attendus des le debut, et une
    /// deduction annoncerait la fin avant le commencement.
    public let estTermine: Bool

    public init(identifiant: String, octetsRecus: Int64, octetsAttendus: Int64, estTermine: Bool) {
        self.identifiant = identifiant
        self.octetsRecus = max(0, octetsRecus)
        self.octetsAttendus = max(0, octetsAttendus)
        self.estTermine = estTermine
    }

    /// Avancement entre zero et un, pour une barre de progression.
    public var fraction: Double {
        guard estTermine == false else { return 1 }
        guard octetsAttendus > 0 else { return 0 }

        return min(1, Double(octetsRecus) / Double(octetsAttendus))
    }
}
