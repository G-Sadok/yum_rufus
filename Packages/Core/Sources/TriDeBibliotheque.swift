import Foundation

//
// TriDeBibliotheque
//
// Tri de la grille de bibliotheque : menu de la section 5.1 de DESIGN-SPEC.md,
// repris a l identique par la section 6.6, et sens du tri du tableau 6.7.
//
// Le tri appartient au modele et non a la vue. La section 5.5 le range dans les
// reglages, ou il devient persistant et partage avec le mode liste compacte.
// Le poser ici evite qu il vive deux fois.
//

/// Critere de tri de la grille de bibliotheque.
///
/// Les cinq criteres sont ceux du menu de tri, dans l ordre du menu.
public enum CritereDeTri: String, CaseIterable, Sendable, Codable, Hashable {
    /// Tri alphabetique, coche par defaut dans le menu de la section 5.1.
    case aAZ
    case derniereLecture
    case derniereMiseAJour
    case dateAjout
    case nonLu

    /// Libelle du critere tel que le document l ecrit.
    ///
    /// Il ne s affiche jamais : une vue passe par le catalogue de chaines. Il
    /// existe pour que la suite de tests puisse comparer l ordre et le contenu
    /// de cette enumeration au menu du document, sans recopier ce menu.
    public var nomDuDocument: String {
        switch self {
        case .aAZ: "A a Z"
        case .derniereLecture: "Derniere lecture"
        case .derniereMiseAJour: "Derniere mise a jour"
        case .dateAjout: "Date d ajout"
        case .nonLu: "Non lu"
        }
    }
}

/// Sens du tri, tableau 6.7.
public enum OrdreDeTri: String, CaseIterable, Sendable, Codable, Hashable {
    case croissant
    case decroissant

    /// Libelle du sens tel que le document l ecrit, jamais affiche.
    public var nomDuDocument: String {
        switch self {
        case .croissant: "Croissant"
        case .decroissant: "Decroissant"
        }
    }

    public var estCroissant: Bool {
        self == .croissant
    }
}

/// Tri complet applique a la grille de bibliotheque.
public struct TriDeBibliotheque: Sendable, Codable, Hashable {
    public var critere: CritereDeTri
    public var ordre: OrdreDeTri

    public init(critere: CritereDeTri = .aAZ, ordre: OrdreDeTri = .croissant) {
        self.critere = critere
        self.ordre = ordre
    }

    /// Tri applique tant que l utilisateur n a rien choisi.
    ///
    /// La section 5.1 dessine le menu de tri avec la coche sur `A a Z`.
    public static let defaut = TriDeBibliotheque()
}
