//
// Palette resolue, sections 1.1 a 1.3 de DESIGN-SPEC.md.
//

/// Ensemble des couleurs applicables pour un theme et une apparence donnes.
///
/// C est l objet que la couche vue transporte. Une vue ne choisit jamais un
/// theme ni une apparence, elle lit la palette qu on lui donne.
public struct Palette: Sendable, Equatable {
    /// Theme dont la palette est issue.
    public let theme: ThemeDeSurface
    /// Apparence dont la palette est issue.
    public let apparence: Apparence
    /// Surfaces, les seules valeurs que le theme permute.
    public let surfaces: JetonsDeSurface
    /// Couleurs de texte, dependantes de la seule apparence.
    public let textes: JetonsDeTexte
    /// Jetons semantiques, dependants de la seule apparence.
    public let semantiques: JetonsSemantiques

    /// Palette du theme et de l apparence demandes.
    public static func pour(theme: ThemeDeSurface, apparence: Apparence) -> Palette {
        Palette(
            theme: theme,
            apparence: apparence,
            surfaces: JetonsDeSurface.pour(theme: theme, apparence: apparence),
            textes: JetonsDeTexte.pour(apparence: apparence),
            semantiques: JetonsSemantiques.pour(apparence: apparence)
        )
    }

    /// Palette appliquee tant que l utilisateur n a rien choisi.
    public static let defaut = Palette.pour(
        theme: ThemeDeSurface.defaut,
        apparence: Apparence.defaut
    )
}

extension Jetons {
    /// Acces aux couleurs, sections 1.1 a 1.4.
    public enum Couleur {
        /// Palette du theme et de l apparence demandes.
        public static func palette(theme: ThemeDeSurface, apparence: Apparence) -> Palette {
            Palette.pour(theme: theme, apparence: apparence)
        }

        /// Couleur du fond de lecteur demande.
        public static func fondDeLecteur(_ fond: FondDeLecteur) -> CouleurHexadecimale {
            fond.couleur
        }
    }
}
