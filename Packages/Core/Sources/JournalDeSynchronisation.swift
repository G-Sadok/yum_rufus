import Foundation

//
// JournalDeSynchronisation
//
// Le journal de changements de la section 2.2 du cahier de developpement, celui
// qui remplace le miroir automatique de CloudKit.
//
// Le miroir automatique a ete ecarte pour une raison qui tient en une ligne :
// il ne dit jamais ce qu il a fait. Quand deux appareils ne montrent pas la
// meme page, il n existe aucun endroit ou lire ce qui est parti, ce qui est
// arrive, et ce qui a ete ecarte. Un journal explicite donne cet endroit, et
// c est aussi lui qui rend le mode hors ligne possible : ce qui n a pas pu
// partir reste ecrit, ligne a ligne, jusqu a la reconnexion.
//
// Le point le plus important de ce fichier est le regroupement par cle. Une
// lecture enregistre sa position toutes les deux secondes, un chapitre lu
// pendant vingt minutes produit donc six cents ecritures pour un seul chapitre.
// Les empiler telles quelles remplirait le journal de cinq cent quatre vingt
// dix neuf lignes perimees, que le retour du reseau enverrait toutes. Le
// journal ne garde donc qu un changement par cle, le plus recent, et une
// journee entiere de lecture hors ligne pese autant de lignes qu il y a de
// chapitres touches.
//

/// Ce qu une ligne de journal decrit.
///
/// L enumeration est volontairement courte. Elle ne porte que ce que la section
/// iCloud des reglages annonce a l utilisateur, une entree par interrupteur, et
/// chaque cas dit lui meme quel interrupteur le gouverne et quelle ecriture de
/// session il represente. Un cas ajoute sans repondre a ces deux questions ne
/// compile pas.
public enum EntiteSynchronisee: String, Sendable, Codable, CaseIterable, Hashable {
    /// La position de lecture et l etat lu d un chapitre.
    case progressionDeChapitre

    /// La presence d une serie dans la bibliotheque et ses categories.
    case serieDeBibliotheque

    /// Interrupteur de la section iCloud qui gouverne cette entite.
    public var reglageConcerne: IdentifiantDeReglage {
        switch self {
        case .progressionDeChapitre: .synchroniserLaProgression
        case .serieDeBibliotheque: .synchroniserLaBibliotheque
        }
    }

    /// Ecriture de session que l envoi de cette entite represente, section 11.
    ///
    /// C est par cette correspondance que le mode incognito s applique a
    /// iCloud, et non par un cas supplementaire dans `EcritureDeSession`.
    /// Envoyer une position de lecture est exactement l ecriture
    /// `positionDeLecture`, deposee ailleurs : lui donner un nom distinct
    /// aurait laisse croire qu il existe deux regles, et qu une session
    /// incognito pourrait bloquer l une sans bloquer l autre.
    public var ecritureConcernee: EcritureDeSession {
        switch self {
        case .progressionDeChapitre: .positionDeLecture
        case .serieDeBibliotheque: .bibliotheque
        }
    }
}

/// Ce qu une ligne de journal identifie, de facon stable entre appareils.
///
/// L identifiant est textuel et non un `UUID`, parce que la cle sert aussi de
/// nom d enregistrement cote CloudKit, ou tout est chaine. La conversion se
/// fait donc ici, une fois, plutot qu a chaque appel de l entrepot.
public struct CleDeChangement: Sendable, Codable, Hashable {
    /// Nature de ce qui a change.
    public let entite: EntiteSynchronisee

    /// Identifiant de l objet chez nous, le meme sur tous les appareils.
    public let identifiant: String

    public init(entite: EntiteSynchronisee, identifiant: String) {
        self.entite = entite
        self.identifiant = identifiant
    }

    public init(entite: EntiteSynchronisee, identifiant: UUID) {
        self.init(entite: entite, identifiant: identifiant.uuidString)
    }

    /// Forme textuelle de la cle, employee comme nom d enregistrement distant.
    ///
    /// Le separateur est deux points parce qu il n apparait ni dans un nom de
    /// cas d enumeration ni dans un `UUID`, ce qui rend la forme reversible.
    public var texte: String {
        "\(entite.rawValue):\(identifiant)"
    }

    /// Cle relue depuis sa forme textuelle, nulle quand le texte ne vient pas
    /// d une version connue du produit.
    public static func lire(_ texte: String) -> CleDeChangement? {
        let morceaux = texte.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)

        guard morceaux.count == 2,
              let entite = EntiteSynchronisee(rawValue: String(morceaux[0])),
              morceaux[1].isEmpty == false
        else {
            return nil
        }

        return CleDeChangement(entite: entite, identifiant: String(morceaux[1]))
    }
}

/// Une ligne du journal de changements.
///
/// La charge est opaque au journal et au moteur : ni l un ni l autre n a
/// besoin de savoir ce qu il transporte pour decider s il part, quand il part
/// et lequel gagne un conflit. C est ce qui permet d ajouter une entite sans
/// toucher au moteur, et c est la couche metier de chaque entite qui encode et
/// decode sa charge.
public struct ChangementSynchronise: Sendable, Codable, Hashable {
    /// Ce que cette ligne decrit.
    public let cle: CleDeChangement

    /// Etat de l objet, encode par la couche qui le connait.
    public let charge: Data

    /// Instant ou le changement a eu lieu sur l appareil qui l a produit.
    ///
    /// C est l horodatage de l evenement, jamais celui de l envoi. Un
    /// changement produit hors ligne le lundi et envoye le jeudi ne doit pas
    /// ecraser un changement produit le mardi sur un autre appareil.
    public let horodatage: Date

    /// Appareil qui a produit le changement.
    public let appareil: String

    /// Vrai quand la ligne dit que l objet a disparu.
    public let supprime: Bool

    public init(
        cle: CleDeChangement,
        charge: Data,
        horodatage: Date,
        appareil: String,
        supprime: Bool = false
    ) {
        self.cle = cle
        self.charge = charge
        self.horodatage = horodatage
        self.appareil = appareil
        self.supprime = supprime
    }
}

/// Les changements produits localement et pas encore accuses par le distant.
///
/// La structure est une valeur, pas un acteur. Elle est manipulee par le moteur
/// de synchronisation, qui est deja un acteur : en faire un second n aurait
/// ajoute qu un point de suspension entre deux etats coherents.
public struct JournalDeChangements: Sendable, Codable, Equatable {
    private var parCle: [String: ChangementSynchronise]

    /// Journal vide, celui d une installation neuve.
    public static let vide = JournalDeChangements()

    public init(_ changements: [ChangementSynchronise] = []) {
        parCle = [:]

        for changement in changements {
            consigner(changement)
        }
    }

    /// Changements en attente, dans l ordre ou ils partiront.
    ///
    /// L ordre est celui des horodatages, la cle textuelle departageant les
    /// egalites. Il est donc total et ne depend pas de l ordre d insertion :
    /// deux appareils qui poussent le meme journal poussent la meme suite, ce
    /// qui rend un incident reproductible.
    public var changements: [ChangementSynchronise] {
        parCle.values.sorted { premier, second in
            if premier.horodatage != second.horodatage {
                return premier.horodatage < second.horodatage
            }

            return premier.cle.texte < second.cle.texte
        }
    }

    /// Nombre de changements en attente, celui que l indicateur d etat affiche.
    public var nombreEnAttente: Int {
        parCle.count
    }

    /// Vrai quand rien n attend d etre envoye.
    public var estVide: Bool {
        parCle.isEmpty
    }

    /// Instant du plus ancien changement en attente, nul quand le journal est
    /// vide.
    ///
    /// Le moteur s en sert pour son delai de regroupement : il attend que le
    /// plus ancien changement ait mure, et non que le plus recent se taise,
    /// faute de quoi une lecture continue repousserait l envoi indefiniment.
    public var plusAncienChangement: Date? {
        parCle.values.map(\.horodatage).min()
    }

    /// Ajoute un changement, en ne gardant que le plus recent de sa cle.
    ///
    /// Un changement plus ancien que celui deja en attente est ecarte. Le cas
    /// n est pas theorique : l horloge d un appareil peut reculer apres une
    /// synchronisation reseau, et sans cette garde un enregistrement de
    /// position ferait revenir la page atteinte en arriere sur tous les
    /// appareils.
    public mutating func consigner(_ changement: ChangementSynchronise) {
        let cle = changement.cle.texte

        guard let existant = parCle[cle] else {
            parCle[cle] = changement
            return
        }

        parCle[cle] = ResolutionDeConflit.gagnant(existant, changement).changement
    }

    /// Ajoute une suite de changements.
    public mutating func consigner(_ changements: [ChangementSynchronise]) {
        for changement in changements {
            consigner(changement)
        }
    }

    /// Retire du journal ce que le distant vient d accuser.
    ///
    /// Le retrait ne porte que sur des lignes identiques a celles qui sont
    /// parties. Une position enregistree pendant l envoi remplace la ligne en
    /// attente, et cette ligne la ne doit surtout pas disparaitre au retour de
    /// l accuse : elle n est jamais partie. C est exactement ainsi qu une
    /// derniere page de chapitre se perd, et c est invisible tant qu on ne lit
    /// pas pendant une synchronisation.
    public mutating func retirer(_ envoyes: [ChangementSynchronise]) {
        for envoye in envoyes where parCle[envoye.cle.texte] == envoye {
            parCle.removeValue(forKey: envoye.cle.texte)
        }
    }

    /// Changement en attente pour cette cle, nul quand il n y en a aucun.
    public func changement(pour cle: CleDeChangement) -> ChangementSynchronise? {
        parCle[cle.texte]
    }
}
