import Foundation

//
// PlanificateurDeTelechargements
//
// Qui demarre, qui retourne attendre. Rien d autre.
//
// Le calcul est une fonction pure, separee du moteur qui l applique, parce que
// la limite de telechargements simultanes est un critere d acceptation et qu un
// critere se verifie. Mesurer une limite sur un moteur reel demande de compter
// des taches en vol, ce qui ne prouve la limite que pour l enchainement qui
// s est produit ce jour la. Ici la question se pose sur un etat de file complet,
// y compris ceux qu un enchainement reel met des heures a produire.
//
// Le reseau entre dans le calcul et non a cote. Le reglage 12 dit
// `En Wi-Fi seulement`, ce qui ne veut pas dire refuser d ajouter a la file : la
// file se remplit hors Wi-Fi, elle ne se vide pas. Melanger les deux ferait
// perdre la demande de l utilisateur au moment ou son telephone bascule sur le
// reseau cellulaire.
//

/// Nature du reseau disponible au moment du calcul.
///
/// Trois cas et non un simple booleen : hors ligne et cellulaire produisent le
/// meme arret mais pas le meme message, et la section 4.10 exige qu une erreur
/// nomme sa cause reelle.
public enum EtatDuReseau: String, Sendable, Codable, CaseIterable, Hashable {
    /// Reseau sans compteur, ou lien filaire.
    case wifi

    /// Reseau mobile, potentiellement facture au volume.
    case cellulaire

    /// Aucun reseau joignable.
    case horsLigne
}

/// Reglages du sous ecran de telechargement de la section 9 du cahier de
/// developpement.
///
/// Ils ne sont pas des lignes de `CatalogueDeReglages`. La section 5.5 de
/// DESIGN-SPEC.md arrete l ecran Reglages a quatre lignes pour la section 12, et
/// le cahier range le reste dans le sous ecran ouvert par la ligne de
/// navigation. Ce type porte ce sous ecran.
public struct ReglagesDeTelechargement: Sendable, Equatable, Hashable, Codable {
    /// Plus petit nombre de telechargements simultanes acceptes.
    public static let limiteMinimale = 1

    /// Plus grand nombre de telechargements simultanes accepte.
    public static let limiteMaximale = 5

    /// Nombre de telechargements simultanes sur une installation neuve.
    public static let limiteParDefaut = 3

    /// Nombre de telechargements menes de front.
    ///
    /// Toujours dans les bornes du cahier, quelle que soit la valeur passee a la
    /// construction. Une limite hors bornes lue dans une base ecrite par une
    /// version anterieure ne doit pas ouvrir cinquante connexions.
    public let simultanes: Int

    /// Vrai quand la file ne travaille que sur un reseau sans compteur.
    public let enWiFiSeulement: Bool

    public init(simultanes: Int = ReglagesDeTelechargement.limiteParDefaut, enWiFiSeulement: Bool = true) {
        self.simultanes = min(Self.limiteMaximale, max(Self.limiteMinimale, simultanes))
        self.enWiFiSeulement = enWiFiSeulement
    }

    /// Vrai quand ce reseau autorise la file a travailler.
    public func autorise(_ reseau: EtatDuReseau) -> Bool {
        switch reseau {
        case .wifi: true
        case .cellulaire: enWiFiSeulement == false
        case .horsLigne: false
        }
    }
}

/// Ce que le planificateur demande au moteur de faire.
///
/// Les deux listes sont disjointes et rendues dans l ordre de passage, pour que
/// le moteur les applique telles quelles sans avoir a les retrier.
public struct DecisionDeFile: Sendable, Equatable {
    /// Taches a mettre en route.
    public let aDemarrer: [UUID]

    /// Taches en cours a renvoyer dans la file.
    ///
    /// Elles retournent en attente et non en suspension. La suspension est le
    /// geste de l utilisateur sur la ligne, section 4.11 : une tache que le
    /// reseau a arretee doit repartir toute seule au retour du Wi-Fi, une tache
    /// que l utilisateur a mise en pause ne le doit pas.
    public let aRemettreEnAttente: [UUID]

    public init(aDemarrer: [UUID] = [], aRemettreEnAttente: [UUID] = []) {
        self.aDemarrer = aDemarrer
        self.aRemettreEnAttente = aRemettreEnAttente
    }

    /// Vrai quand rien n est a faire.
    public var estVide: Bool {
        aDemarrer.isEmpty && aRemettreEnAttente.isEmpty
    }
}

/// Decide de ce qui tourne, a partir de la file entiere.
public enum PlanificateurDeTelechargements {
    /// Ce qui doit demarrer et ce qui doit s arreter, dans cet etat de file.
    ///
    /// - Parameters:
    ///   - taches: la file entiere, dans n importe quel ordre.
    ///   - reglages: limite simultanee et restriction au Wi-Fi.
    ///   - reseau: reseau disponible a cet instant.
    public static func decision(
        taches: [TelechargementAffiche],
        reglages: ReglagesDeTelechargement,
        reseau: EtatDuReseau
    ) -> DecisionDeFile {
        let enCours = OrdreDeLaFile.trier(taches.filter(\.occupeUnePlace))

        guard reglages.autorise(reseau) else {
            return DecisionDeFile(aRemettreEnAttente: enCours.map(\.id))
        }

        // Le depassement se traite avant le demarrage. Une file qui tourne deja
        // au dela de sa limite, parce que l utilisateur vient de la baisser,
        // doit rendre des places avant qu on lui en demande de nouvelles.
        let enTrop = enCours.count > reglages.simultanes
            ? Array(enCours.suffix(enCours.count - reglages.simultanes))
            : []

        let placesLibres = max(0, reglages.simultanes - (enCours.count - enTrop.count))

        let candidates = OrdreDeLaFile
            .trier(taches.filter(\.attendSonTour))
            .prefix(placesLibres)

        return DecisionDeFile(
            aDemarrer: candidates.map(\.id),
            aRemettreEnAttente: enTrop.map(\.id)
        )
    }

    /// Nombre de taches qui tourneront apres application de la decision.
    ///
    /// Sert aux tests et au journal. C est la valeur que la limite borne, et la
    /// calculer ici evite que chaque appelant la recompte a sa facon.
    public static func actives(
        apres decision: DecisionDeFile,
        sur taches: [TelechargementAffiche]
    ) -> Int {
        let arretees = Set(decision.aRemettreEnAttente)
        let demarrees = Set(decision.aDemarrer)

        return taches.filter { tache in
            if arretees.contains(tache.id) {
                return false
            }

            return tache.occupeUnePlace || demarrees.contains(tache.id)
        }.count
    }
}
