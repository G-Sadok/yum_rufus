import Foundation

//
// SelectionDeChapitres
//
// Selection multiple de la liste des chapitres et barre d actions qu elle
// ouvre, section 4.5 de DESIGN-SPEC.md.
//
// La regle tient en une phrase : la barre existe si et seulement si la
// selection n est pas vide. Elle vit ici et non dans la vue, parce qu une vue
// qui decide seule quand montrer sa barre finit toujours par la laisser
// ouverte sur une selection videe par ailleurs.
//

/// Action proposee par la barre de selection multiple, section 4.5.
///
/// L ordre des cas est celui du document : compteur, Marquer lu, Telecharger,
/// Supprimer.
public enum ActionDeSelectionDeChapitres: String, Sendable, Codable, CaseIterable, Hashable {
    case marquerLu
    case telecharger
    case supprimer

    /// Vrai pour l action qui detruit, affichee en `danger`.
    public var estDestructive: Bool {
        self == .supprimer
    }
}

/// Chapitres selectionnes dans la liste, et etat de la barre d actions.
///
/// La selection se fait par clic maintenu ou Cmd clic, et s etend d une ancre
/// jusqu a un chapitre par Maj clic. L ancre est le dernier chapitre ajoute a
/// la main, jamais un chapitre ajoute par une extension precedente : sans cela
/// deux Maj clic successifs deplaceraient l ancre et l utilisateur perdrait le
/// point de depart qu il croit tenir.
public struct SelectionDeChapitres: Sendable, Equatable {
    /// Chapitres retenus.
    public private(set) var identifiants: Set<UUID>

    /// Point de depart d une extension par Maj clic.
    public private(set) var ancre: UUID?

    public init(identifiants: Set<UUID> = [], ancre: UUID? = nil) {
        self.identifiants = identifiants
        self.ancre = ancre
    }

    /// Les trois actions de la barre, dans l ordre du document.
    public static let actions = ActionDeSelectionDeChapitres.allCases

    /// Vrai quand aucun chapitre n est retenu.
    public var estVide: Bool {
        identifiants.isEmpty
    }

    /// Nombre de chapitres retenus, affiche par le compteur `N selectionnes`.
    public var nombre: Int {
        identifiants.count
    }

    /// Vrai quand la barre d actions contextuelle est a l ecran.
    ///
    /// C est la seule condition. Une selection vide ferme la barre, une
    /// selection non vide l ouvre.
    public var barreEstOuverte: Bool {
        !estVide
    }

    /// Actions offertes par la barre, vides tant qu aucun chapitre n est retenu.
    public var actionsDisponibles: [ActionDeSelectionDeChapitres] {
        barreEstOuverte ? Self.actions : []
    }

    /// Vrai quand le chapitre fait partie de la selection.
    public func contient(_ identifiant: UUID) -> Bool {
        identifiants.contains(identifiant)
    }

    /// Ajoute le chapitre s il est absent, le retire sinon.
    ///
    /// Le chapitre devient l ancre dans les deux cas : c est le dernier endroit
    /// que l utilisateur a designe.
    public mutating func basculer(_ identifiant: UUID) {
        if identifiants.contains(identifiant) {
            identifiants.remove(identifiant)
        } else {
            identifiants.insert(identifiant)
        }

        ancre = identifiant
    }

    /// Etend la selection de l ancre jusqu au chapitre designe.
    ///
    /// Sans ancre, le geste vaut une selection simple. L etendue suit l ordre
    /// de la liste affichee, pas celui de la serie : l utilisateur selectionne
    /// ce qu il voit entre deux lignes.
    public mutating func etendre(jusqua identifiant: UUID, dans chapitres: [ChapitreDeFiche]) {
        guard let ancre,
              let depart = chapitres.firstIndex(where: { $0.id == ancre }),
              let arrivee = chapitres.firstIndex(where: { $0.id == identifiant })
        else {
            basculer(identifiant)
            return
        }

        let etendue = depart <= arrivee ? depart...arrivee : arrivee...depart
        identifiants.formUnion(chapitres[etendue].map(\.id))
    }

    /// Retient tous les chapitres de la liste affichee.
    public mutating func toutSelectionner(_ chapitres: [ChapitreDeFiche]) {
        identifiants = Set(chapitres.map(\.id))
        ancre = chapitres.last?.id
    }

    /// Vide la selection et referme la barre.
    public mutating func vider() {
        identifiants.removeAll()
        ancre = nil
    }

    /// Retire de la selection les chapitres qui ne sont plus dans la liste.
    ///
    /// Un changement de filtre ne doit pas laisser derriere lui une barre
    /// ouverte sur des chapitres invisibles, ni un compteur qui annonce plus de
    /// lignes que la liste n en montre.
    public mutating func restreindre(a chapitres: [ChapitreDeFiche]) {
        let visibles = Set(chapitres.map(\.id))
        identifiants.formIntersection(visibles)

        if let ancre, !visibles.contains(ancre) {
            self.ancre = nil
        }
    }
}
