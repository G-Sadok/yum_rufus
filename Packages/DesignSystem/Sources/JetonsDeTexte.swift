//
// Couleurs de texte, section 1.2 de DESIGN-SPEC.md.
//

/// Les sept couleurs de texte d une apparence.
///
/// Elles ne dependent pas du theme. En variante claire, `tertiary` et
/// `quaternary` sont assombris pour tenir le seuil de contraste de 4.5:1.
public struct JetonsDeTexte: Sendable, Equatable {
    /// Titres et libelles de ligne.
    public let primary: CouleurHexadecimale
    /// Valeurs de reglage et texte courant.
    public let secondary: CouleurHexadecimale
    /// Descriptions et metadonnees.
    public let tertiary: CouleurHexadecimale
    /// Mention legale, version, sous ligne d un chapitre lu.
    ///
    /// En variante sombre ce jeton mesure 3.1:1. La section 7 le reserve au
    /// texte redondant, jamais porteur d une information unique. Toute autre
    /// utilisation passe a `tertiary`.
    public let quaternary: CouleurHexadecimale
    /// Element inactif.
    public let disabled: CouleurHexadecimale
    /// Texte pose sur un aplat accent.
    public let onAccent: CouleurHexadecimale
    /// Glyphe d etat vide.
    public let emptyGlyph: CouleurHexadecimale

    /// Noms des jetons de texte, dans l ordre du tableau 1.2.
    public static let nomsDeJetons = [
        "text.primary",
        "text.secondary",
        "text.tertiary",
        "text.quaternary",
        "text.disabled",
        "text.onAccent",
        "text.emptyGlyph",
    ]

    /// Valeurs indexees par le nom de jeton du document.
    public var parNom: [String: CouleurHexadecimale] {
        [
            "text.primary": primary,
            "text.secondary": secondary,
            "text.tertiary": tertiary,
            "text.quaternary": quaternary,
            "text.disabled": disabled,
            "text.onAccent": onAccent,
            "text.emptyGlyph": emptyGlyph,
        ]
    }

    /// Couleurs de texte de l apparence demandee.
    public static func pour(apparence: Apparence) -> JetonsDeTexte {
        switch apparence {
        case .sombre: sombre
        case .clair: clair
        }
    }

    static let sombre = JetonsDeTexte(
        primary: CouleurHexadecimale(0xF2F2F7),
        secondary: CouleurHexadecimale(0xC7C7CC),
        tertiary: CouleurHexadecimale(0x8E8E93),
        quaternary: CouleurHexadecimale(0x6E6E73),
        disabled: CouleurHexadecimale(0x48484C),
        onAccent: CouleurHexadecimale(0xFFFFFF),
        emptyGlyph: CouleurHexadecimale(0x4A4A4F)
    )

    static let clair = JetonsDeTexte(
        primary: CouleurHexadecimale(0x1C1C1E),
        secondary: CouleurHexadecimale(0x3C3C43),
        tertiary: CouleurHexadecimale(0x5C5C61),
        quaternary: CouleurHexadecimale(0x6E6E73),
        disabled: CouleurHexadecimale(0xABABB0),
        onAccent: CouleurHexadecimale(0xFFFFFF),
        emptyGlyph: CouleurHexadecimale(0xB4B4BA)
    )
}
