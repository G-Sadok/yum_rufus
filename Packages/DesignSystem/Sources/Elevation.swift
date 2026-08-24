//
// Elevation, section 1.8 de DESIGN-SPEC.md.
//
// Aucune ombre sur les cartes. La hierarchie passe par la valeur de surface.
//

/// Ombre portee d un niveau d elevation.
public struct Ombre: Sendable, Equatable {
    /// Decalage vertical en points.
    public let decalageVertical: Double
    /// Rayon de flou tel que le document l ecrit, en notation CSS.
    public let flou: Double
    /// Couleur de l ombre, opacite comprise.
    public let couleur: CouleurHexadecimale

    /// Rayon a passer a la couche vue.
    ///
    /// La couche vue mesure le rayon comme la moitie du flou de la notation
    /// CSS retenue par le document. Confondre les deux double l ombre.
    public var rayon: Double {
        flou / 2
    }

    /// Notation telle qu elle apparait dans le tableau 1.8.
    public var notation: String {
        "0 \(entier(decalageVertical))px \(entier(flou))px \(couleur.notation)"
    }

    private func entier(_ valeur: Double) -> String {
        String(Int(valeur))
    }
}

/// Complement impose en plus de l ombre.
public enum ComplementDElevation: String, Sendable {
    /// Aucun complement.
    case aucun
    /// Contour `border`.
    case contour
    /// Voile `scrim` pose sous l element.
    case voile
}

/// Les trois niveaux d elevation du produit.
public enum NiveauDElevation: Int, CaseIterable, Sendable {
    /// Contenu, cartes de reglages, cartes de serie.
    case contenu = 0
    /// Menu contextuel, popover, barre d actions de selection.
    case flottant = 1
    /// Modale, feuille de configuration, mur premium.
    case modal = 2

    /// Ombre du niveau, absente au niveau 0.
    public var ombre: Ombre? {
        switch self {
        case .contenu:
            nil
        case .flottant:
            Ombre(
                decalageVertical: 8,
                flou: 24,
                couleur: CouleurHexadecimale(0x000000, opacite: 0.44)
            )
        case .modal:
            Ombre(
                decalageVertical: 24,
                flou: 64,
                couleur: CouleurHexadecimale(0x000000, opacite: 0.60)
            )
        }
    }

    /// Complement impose en plus de l ombre.
    public var complement: ComplementDElevation {
        switch self {
        case .contenu: .aucun
        case .flottant: .contour
        case .modal: .voile
        }
    }
}

extension Jetons {
    /// Elevation, section 1.8.
    public enum Elevation {
        /// Contenu, cartes de reglages, cartes de serie.
        public static let contenu = NiveauDElevation.contenu
        /// Menu contextuel, popover, barre d actions de selection.
        public static let flottant = NiveauDElevation.flottant
        /// Modale, feuille de configuration, mur premium.
        public static let modal = NiveauDElevation.modal
    }
}
