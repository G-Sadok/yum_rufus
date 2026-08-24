//
// Surfaces des quatre themes, section 1.1 de DESIGN-SPEC.md.
//
// Les noms de jetons restent ceux du document, en anglais. Les traduire ferait
// perdre la correspondance directe entre une ligne du tableau 1.1 et une
// propriete du code, et rendrait la derive silencieuse.
//

/// Les douze surfaces d un theme dans une apparence donnee.
///
/// Trois regles de la section 1.1 tiennent a ces valeurs et ne se rattrapent
/// pas plus tard : `canvas` peint la zone de contenu et `window` la seule
/// coquille, `card`, `field`, `menu` et `selected` restent distincts en
/// variante claire, et `sheet` reste distinct de `menu`.
public struct JetonsDeSurface: Sendable, Equatable {
    /// Zone de contenu a l interieur de la fenetre.
    public let canvas: CouleurHexadecimale
    /// Coquille de la fenetre et gouttiere de la barre laterale.
    public let window: CouleurHexadecimale
    /// Barre de titre et barres d outils.
    public let chrome: CouleurHexadecimale
    /// Barre laterale encastree.
    public let sidebar: CouleurHexadecimale
    /// Carte de section, carte de serie, ligne de chapitre non lue.
    public let card: CouleurHexadecimale
    /// Carte au survol.
    public let cardHover: CouleurHexadecimale
    /// Menu contextuel et bouton secondaire.
    public let menu: CouleurHexadecimale
    /// Element selectionne, piste de curseur, interrupteur inactif.
    public let selected: CouleurHexadecimale
    /// Champ de saisie.
    public let field: CouleurHexadecimale
    /// Modale et feuille de configuration.
    public let sheet: CouleurHexadecimale
    /// Fond du lecteur par defaut du theme.
    public let reader: CouleurHexadecimale
    /// Fond des blocs premium.
    public let premium: CouleurHexadecimale

    /// Noms des jetons de surface, dans l ordre du tableau 1.1.
    public static let nomsDeJetons = [
        "surface.canvas",
        "surface.window",
        "surface.chrome",
        "surface.sidebar",
        "surface.card",
        "surface.cardHover",
        "surface.menu",
        "surface.selected",
        "surface.field",
        "surface.sheet",
        "surface.reader",
        "surface.premium",
    ]

    /// Valeurs indexees par le nom de jeton du document.
    ///
    /// Sert a la verification contre DESIGN-SPEC.md, et a tout code qui doit
    /// parcourir la palette sans connaitre chaque propriete a l avance.
    public var parNom: [String: CouleurHexadecimale] {
        [
            "surface.canvas": canvas,
            "surface.window": window,
            "surface.chrome": chrome,
            "surface.sidebar": sidebar,
            "surface.card": card,
            "surface.cardHover": cardHover,
            "surface.menu": menu,
            "surface.selected": selected,
            "surface.field": field,
            "surface.sheet": sheet,
            "surface.reader": reader,
            "surface.premium": premium,
        ]
    }

    /// Surfaces du theme demande dans l apparence demandee.
    public static func pour(theme: ThemeDeSurface, apparence: Apparence) -> JetonsDeSurface {
        switch (theme, apparence) {
        case (.midnight, .sombre): midnightSombre
        case (.midnight, .clair): midnightClair
        case (.obsidian, .sombre): obsidianSombre
        case (.obsidian, .clair): obsidianClair
        case (.slate, .sombre): slateSombre
        case (.slate, .clair): slateClair
        case (.paper, .sombre): paperSombre
        case (.paper, .clair): paperClair
        }
    }

    static let midnightSombre = JetonsDeSurface(
        canvas: CouleurHexadecimale(0x0E0E10),
        window: CouleurHexadecimale(0x131315),
        chrome: CouleurHexadecimale(0x161618),
        sidebar: CouleurHexadecimale(0x1B1B1D),
        card: CouleurHexadecimale(0x202023),
        cardHover: CouleurHexadecimale(0x26262A),
        menu: CouleurHexadecimale(0x2C2C30),
        selected: CouleurHexadecimale(0x3A3A3E),
        field: CouleurHexadecimale(0x141416),
        sheet: CouleurHexadecimale(0x1F1F22),
        reader: CouleurHexadecimale(0x000000),
        premium: CouleurHexadecimale(0x1C2740)
    )

    static let midnightClair = JetonsDeSurface(
        canvas: CouleurHexadecimale(0xF2F2F5),
        window: CouleurHexadecimale(0xFAFAFC),
        chrome: CouleurHexadecimale(0xF0F0F4),
        sidebar: CouleurHexadecimale(0xE9E9EE),
        card: CouleurHexadecimale(0xFFFFFF),
        cardHover: CouleurHexadecimale(0xF4F4F8),
        menu: CouleurHexadecimale(0xE6E6EB),
        selected: CouleurHexadecimale(0xD5D5DC),
        field: CouleurHexadecimale(0xFFFFFF),
        sheet: CouleurHexadecimale(0xFFFFFF),
        reader: CouleurHexadecimale(0xFFFFFF),
        premium: CouleurHexadecimale(0xE4EDFB)
    )

    static let obsidianSombre = JetonsDeSurface(
        canvas: CouleurHexadecimale(0x000000),
        window: CouleurHexadecimale(0x000000),
        chrome: CouleurHexadecimale(0x0B0B0C),
        sidebar: CouleurHexadecimale(0x101012),
        card: CouleurHexadecimale(0x161618),
        cardHover: CouleurHexadecimale(0x1B1B1D),
        menu: CouleurHexadecimale(0x202023),
        selected: CouleurHexadecimale(0x2C2C30),
        field: CouleurHexadecimale(0x050506),
        sheet: CouleurHexadecimale(0x1A1A1D),
        reader: CouleurHexadecimale(0x000000),
        premium: CouleurHexadecimale(0x151E33)
    )

    static let obsidianClair = JetonsDeSurface(
        canvas: CouleurHexadecimale(0xFFFFFF),
        window: CouleurHexadecimale(0xFFFFFF),
        chrome: CouleurHexadecimale(0xF7F7F9),
        sidebar: CouleurHexadecimale(0xF0F0F3),
        card: CouleurHexadecimale(0xF4F4F7),
        cardHover: CouleurHexadecimale(0xEDEDF1),
        menu: CouleurHexadecimale(0xE8E8EC),
        selected: CouleurHexadecimale(0xDADAE0),
        field: CouleurHexadecimale(0xFFFFFF),
        sheet: CouleurHexadecimale(0xFFFFFF),
        reader: CouleurHexadecimale(0xFFFFFF),
        premium: CouleurHexadecimale(0xE4EDFC)
    )

    static let slateSombre = JetonsDeSurface(
        canvas: CouleurHexadecimale(0x0E0F13),
        window: CouleurHexadecimale(0x131418),
        chrome: CouleurHexadecimale(0x16171C),
        sidebar: CouleurHexadecimale(0x1B1C22),
        card: CouleurHexadecimale(0x202128),
        cardHover: CouleurHexadecimale(0x26272F),
        menu: CouleurHexadecimale(0x2C2D36),
        selected: CouleurHexadecimale(0x3A3B45),
        field: CouleurHexadecimale(0x141519),
        sheet: CouleurHexadecimale(0x1F2027),
        reader: CouleurHexadecimale(0x000000),
        premium: CouleurHexadecimale(0x1C2740)
    )

    static let slateClair = JetonsDeSurface(
        canvas: CouleurHexadecimale(0xEDEFF4),
        window: CouleurHexadecimale(0xF7F8FC),
        chrome: CouleurHexadecimale(0xEBEDF2),
        sidebar: CouleurHexadecimale(0xE4E7EE),
        card: CouleurHexadecimale(0xFFFFFF),
        cardHover: CouleurHexadecimale(0xF2F4F9),
        menu: CouleurHexadecimale(0xE0E4EC),
        selected: CouleurHexadecimale(0xD0D5E0),
        field: CouleurHexadecimale(0xFFFFFF),
        sheet: CouleurHexadecimale(0xFFFFFF),
        reader: CouleurHexadecimale(0xFFFFFF),
        premium: CouleurHexadecimale(0xE2EBFA)
    )

    static let paperSombre = JetonsDeSurface(
        canvas: CouleurHexadecimale(0x121110),
        window: CouleurHexadecimale(0x171614),
        chrome: CouleurHexadecimale(0x1A1917),
        sidebar: CouleurHexadecimale(0x1F1E1B),
        card: CouleurHexadecimale(0x242320),
        cardHover: CouleurHexadecimale(0x2A2926),
        menu: CouleurHexadecimale(0x302F2B),
        selected: CouleurHexadecimale(0x3E3D39),
        field: CouleurHexadecimale(0x171614),
        sheet: CouleurHexadecimale(0x232220),
        reader: CouleurHexadecimale(0x000000),
        premium: CouleurHexadecimale(0x1C2740)
    )

    /// Surfaces de Paper en variante claire.
    ///
    /// Le document donne `surface.reader` a `#000000` pour Paper clair, la
    /// seule valeur de la ligne qui ne suit pas l inversion du theme. La regle
    /// 0.1 rend le texte normatif pour toute valeur chiffree, la valeur est
    /// donc reprise telle quelle. Le reglage Fond du lecteur de la section 1.4
    /// reste de toute facon prioritaire des que l utilisateur y touche.
    static let paperClair = JetonsDeSurface(
        canvas: CouleurHexadecimale(0xF5F5F7),
        window: CouleurHexadecimale(0xFFFFFF),
        chrome: CouleurHexadecimale(0xF2F2F4),
        sidebar: CouleurHexadecimale(0xECECEF),
        card: CouleurHexadecimale(0xFFFFFF),
        cardHover: CouleurHexadecimale(0xF5F5F7),
        menu: CouleurHexadecimale(0xE8E8EB),
        selected: CouleurHexadecimale(0xDBDBDF),
        field: CouleurHexadecimale(0xFFFFFF),
        sheet: CouleurHexadecimale(0xFFFFFF),
        reader: CouleurHexadecimale(0x000000),
        premium: CouleurHexadecimale(0xE8F0FC)
    )
}
