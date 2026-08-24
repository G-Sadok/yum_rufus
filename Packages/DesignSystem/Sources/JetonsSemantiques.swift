//
// Jetons semantiques, section 1.3 de DESIGN-SPEC.md.
//

/// Les dix jetons semantiques d une apparence.
///
/// `accent` ne change pas d une apparence a l autre. `accent.text` est une
/// derivation obligatoire pour le texte sous 18 px, parce que `#0A84FF` sur
/// fond blanc plafonne a 3.3:1. En aplat on utilise toujours `accent`.
public struct JetonsSemantiques: Sendable, Equatable {
    /// Aplat d action, pastille de non lus, filet de progression.
    public let accent: CouleurHexadecimale
    /// Etat presse d un controle accentue.
    public let accentPressed: CouleurHexadecimale
    /// Texte accentue sous 18 px.
    public let accentText: CouleurHexadecimale
    /// Serveur connecte, telechargement termine.
    public let success: CouleurHexadecimale
    /// Avertissement, connexion instable.
    public let warning: CouleurHexadecimale
    /// Suppression, echec critique.
    public let danger: CouleurHexadecimale
    /// Filet entre deux lignes d une meme carte.
    public let separator: CouleurHexadecimale
    /// Contour de champ, de menu, de feuille.
    public let border: CouleurHexadecimale
    /// Contour de focus clavier, jamais supprime.
    public let focusRing: CouleurHexadecimale
    /// Voile pose sous une modale.
    public let scrim: CouleurHexadecimale

    /// Noms des jetons semantiques, dans l ordre du tableau 1.3.
    public static let nomsDeJetons = [
        "accent",
        "accent.pressed",
        "accent.text",
        "success",
        "warning",
        "danger",
        "separator",
        "border",
        "focusRing",
        "scrim",
    ]

    /// Valeurs indexees par le nom de jeton du document.
    public var parNom: [String: CouleurHexadecimale] {
        [
            "accent": accent,
            "accent.pressed": accentPressed,
            "accent.text": accentText,
            "success": success,
            "warning": warning,
            "danger": danger,
            "separator": separator,
            "border": border,
            "focusRing": focusRing,
            "scrim": scrim,
        ]
    }

    /// Jetons semantiques de l apparence demandee.
    public static func pour(apparence: Apparence) -> JetonsSemantiques {
        switch apparence {
        case .sombre: sombre
        case .clair: clair
        }
    }

    static let sombre = JetonsSemantiques(
        accent: CouleurHexadecimale(0x0A84FF),
        accentPressed: CouleurHexadecimale(0x0774E0),
        accentText: CouleurHexadecimale(0x0A84FF),
        success: CouleurHexadecimale(0x30D158),
        warning: CouleurHexadecimale(0xFF9F0A),
        danger: CouleurHexadecimale(0xFF453A),
        separator: CouleurHexadecimale(0x2E2E32),
        border: CouleurHexadecimale(0x3A3A3E),
        focusRing: CouleurHexadecimale(0x0A84FF),
        scrim: CouleurHexadecimale(0x000000, opacite: 0.45)
    )

    static let clair = JetonsSemantiques(
        accent: CouleurHexadecimale(0x0A84FF),
        accentPressed: CouleurHexadecimale(0x0774E0),
        accentText: CouleurHexadecimale(0x0B6BCB),
        success: CouleurHexadecimale(0x248A3D),
        warning: CouleurHexadecimale(0xB25000),
        danger: CouleurHexadecimale(0xD70015),
        separator: CouleurHexadecimale(0xE3E3E6),
        border: CouleurHexadecimale(0xD1D1D6),
        focusRing: CouleurHexadecimale(0x0A84FF),
        scrim: CouleurHexadecimale(0x000000, opacite: 0.30)
    )
}
