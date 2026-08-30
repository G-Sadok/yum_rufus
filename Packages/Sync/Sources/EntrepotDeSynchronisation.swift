import Core
import Foundation

//
// EntrepotDeSynchronisation
//
// Le distant, vu par le moteur : deux verbes, pousser et tirer, et un jeton
// opaque qui dit ou on en etait.
//
// Le protocole existe pour que le moteur ne connaisse pas CloudKit. Ce n est
// pas une precaution de style : sans lui, verifier qu une progression traverse
// deux appareils en moins de trente secondes demanderait deux comptes iCloud,
// un reseau, et une attente reelle de trente secondes par execution. Avec lui,
// la meme verification tient dans une suite de tests qui fait avancer une
// horloge et ne touche jamais le reseau.
//
// L entrepot ne resout aucun conflit et ne connait aucune regle. Il transporte
// des lignes de journal. Toute la logique est dans `ResolutionDeConflit` et
// dans le moteur, ce qui permet d ecrire une seconde implementation, un jour,
// sans reecrire une seconde fois la regle de conflit.
//

/// Ce que le distant rend quand on lui demande ce qui a change.
public struct LotDistant: Sendable, Equatable {
    /// Changements produits par les autres appareils depuis le jeton fourni.
    public let changements: [ChangementSynchronise]

    /// Nouveau point de reprise, a garder pour la prochaine demande.
    public let jeton: Data?

    /// Vrai quand le distant a d autres pages a livrer tout de suite.
    ///
    /// CloudKit livre une zone par lots. Un appelant qui ignorerait ce drapeau
    /// s arreterait au premier lot et croirait avoir tout recu.
    public let suite: Bool

    public init(changements: [ChangementSynchronise], jeton: Data?, suite: Bool = false) {
        self.changements = changements
        self.jeton = jeton
        self.suite = suite
    }

    /// Lot vide, celui d un distant qui n a rien de neuf.
    public static func vide(jeton: Data?) -> LotDistant {
        LotDistant(changements: [], jeton: jeton)
    }
}

/// Ce qui peut mal tourner face au distant.
public enum ErreurDEntrepot: Error, Sendable, Equatable {
    /// Le reseau est absent ou l appel a expire. Le journal est garde et la
    /// tentative sera refaite.
    case reseauIndisponible

    /// Aucun compte iCloud n est ouvert, ou il a ete change.
    case compteIndisponible

    /// Le jeton de reprise a ete refuse par le serveur.
    ///
    /// CloudKit le fait apres une longue absence. La reponse est de repartir
    /// d un jeton nul, ce qui redemande la zone entiere ; la resolution de
    /// conflit se charge du reste, elle rend le meme etat quel que soit le
    /// nombre de fois qu une ligne est recue.
    case jetonPerime

    /// La zone n existe pas encore chez le distant.
    case zoneAbsente

    /// Le service a refuse pour une raison qui ne se retente pas telle quelle.
    case refuse(code: Int)
}

/// Le distant ou le journal de changements est publie et relu.
public protocol EntrepotDeSynchronisation: Sendable {
    /// Publie des lignes de journal.
    ///
    /// L operation est idempotente : republier une ligne deja publiee ne change
    /// rien. C est ce qui permet de retenter un envoi dont la reponse s est
    /// perdue, sans se demander s il etait passe.
    func pousser(_ changements: [ChangementSynchronise]) async throws

    /// Demande ce qui a change depuis ce point de reprise.
    ///
    /// Un jeton nul demande tout ce que la zone contient.
    func tirer(depuis jeton: Data?) async throws -> LotDistant
}
