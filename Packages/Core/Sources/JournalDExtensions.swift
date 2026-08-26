import Foundation

//
// JournalDExtensions
//
// La trace des requetes refusees a une extension, exigee par le deuxieme
// critere de la section 4.3 : toute requete hors liste blanche est bloquee
// **et journalisee**.
//
// Le contenu d une entree suit la regle de journalisation de la section 11, a
// une exception pres, deja posee par `ErreurReseau.domaineNonAutorise` : le
// domaine refuse est nomme. Il le faut, sans quoi le journal dirait qu une
// extension a ete bloquee sans jamais dire vers ou elle allait, ce qui ne
// permet a l utilisateur de decider de rien. Rien d autre n y figure. Ni titre
// de serie, ni chemin, ni parametre de requete, ni identifiant d utilisateur.
//
// C est un protocole et non un type concret parce que l implantation de
// production ecrira dans le journal du systeme, la ou les tests ont besoin de
// relire ce qui a ete consigne. Un journal qui ne se relit pas ne se teste pas,
// et un critere qui ne se teste pas regressera.
//

/// Pourquoi une requete d extension a ete refusee.
public enum MotifDeRefus: String, Sendable, Codable, CaseIterable, Hashable {
    /// Le domaine vise ne figure pas dans la liste blanche du manifeste.
    case domaineHorsListe

    /// Le serveur a redirige vers un domaine hors de la liste blanche.
    ///
    /// Distinct du precedent parce que la responsabilite differe : la premiere
    /// requete etait legitime, c est le serveur autorise qui a renvoye
    /// ailleurs.
    case redirectionHorsListe

    /// L adresse visee n est pas en HTTPS.
    case transportNonChiffre

    /// La requete a depasse le delai maximal accorde a une extension.
    case delaiDepasse

    /// Le serveur a enchaine plus de redirections que la limite autorisee.
    case tropDeRedirections
}

/// Une requete refusee a une extension.
public struct RefusDExtension: Sendable, Hashable {
    /// Identifiant de l extension, tel qu il figure dans son manifeste.
    ///
    /// C est un identifiant public de paquet, pas une donnee de l utilisateur.
    public let extensionVisee: String

    /// Domaine que l extension a tente de joindre.
    ///
    /// Vide quand l adresse n en portait pas, ce qui arrive pour une adresse
    /// mal formee.
    public let domaine: String

    public let motif: MotifDeRefus

    public let instant: Date

    public init(extensionVisee: String, domaine: String, motif: MotifDeRefus, instant: Date) {
        self.extensionVisee = extensionVisee
        self.domaine = domaine
        self.motif = motif
        self.instant = instant
    }

    /// Ligne de journal, sans aucune donnee personnelle.
    public var ligneDeJournal: String {
        "extension.refus \(motif.rawValue) \(extensionVisee) \(domaine)"
    }
}

/// Ce qui recoit les refus opposes aux extensions.
public protocol JournalDExtensions: Sendable {
    /// Consigne un refus.
    func consigner(_ refus: RefusDExtension) async
}

/// Journal en memoire, borne, relisable.
///
/// Il sert aux tests et a l ecran qui montre a l utilisateur ce qu une
/// extension a tente. Le plafond n est pas un detail : une extension qui boucle
/// sur un domaine interdit produirait un refus par tentative, et un journal
/// sans plafond ferait tomber l application par la memoire au lieu de la
/// proteger.
public actor JournalDExtensionsEnMemoire: JournalDExtensions {
    /// Nombre de refus conserves, les plus recents.
    public static let plafondParDefaut = 200

    private let plafond: Int
    private var refus: [RefusDExtension] = []
    private var comptes: [String: Int] = [:]

    public init(plafond: Int = JournalDExtensionsEnMemoire.plafondParDefaut) {
        self.plafond = max(1, plafond)
    }

    public func consigner(_ refus: RefusDExtension) {
        self.refus.append(refus)
        comptes[refus.extensionVisee, default: 0] += 1

        if self.refus.count > plafond {
            self.refus.removeFirst(self.refus.count - plafond)
        }
    }

    /// Les refus conserves, du plus ancien au plus recent.
    public var consignes: [RefusDExtension] {
        refus
    }

    /// Nombre total de refus opposes a une extension depuis le lancement.
    ///
    /// Compte tous les refus, y compris ceux que le plafond a fait sortir de la
    /// liste : un compteur qui baisserait en meme temps que la liste ne dirait
    /// plus rien de l extension la plus insistante, qui est justement celle
    /// qu il faut voir.
    public func nombreDeRefus(pour extensionVisee: String) -> Int {
        comptes[extensionVisee] ?? 0
    }

    /// Les domaines refuses a une extension, sans doublon et tries.
    public func domainesRefuses(pour extensionVisee: String) -> [String] {
        Set(refus.filter { $0.extensionVisee == extensionVisee }.map(\.domaine)).sorted()
    }
}
