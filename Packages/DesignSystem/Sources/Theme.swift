//
// Theme et apparence, section 1.1 de DESIGN-SPEC.md.
//

/// Les quatre themes du produit.
///
/// Un theme ne permute que les surfaces. Les jetons de texte et les jetons
/// semantiques dependent de l apparence, jamais du theme.
public enum ThemeDeSurface: String, CaseIterable, Sendable {
    /// Defaut, gris neutre tres sombre.
    case midnight
    /// Noir absolu pour ecrans OLED, toutes les surfaces descendent d un cran.
    case obsidian
    /// Gris bleute, teinte decalee vers le bleu, contraste interne reduit.
    case slate
    /// Theme concu pour la variante claire, inversion complete.
    case paper

    /// Theme applique tant que l utilisateur n a rien choisi.
    public static let defaut = ThemeDeSurface.midnight
}

/// Les deux apparences, pilotees par le reglage Apparence de la section 5.5.
public enum Apparence: String, CaseIterable, Sendable {
    case sombre
    case clair

    /// Apparence appliquee tant que l utilisateur n a rien choisi.
    ///
    /// La regle 6 de la section 0 impose le mode sombre par defaut.
    public static let defaut = Apparence.sombre
}
