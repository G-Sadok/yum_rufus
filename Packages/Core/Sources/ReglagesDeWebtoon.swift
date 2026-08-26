//
// ReglagesDeWebtoon
//
// Les deux reglages de mise en page du lecteur webtoon, section 5.8 de
// DESIGN-SPEC.md : la largeur de la colonne et l espace laisse entre deux pages.
//
// Ils vivent dans Core et non dans DesignSystem, parce que ce sont des valeurs
// choisies par l utilisateur et persistees, pas des jetons de style. Ce que le
// systeme de design possede ici est l echelle sur laquelle l espacement se pose,
// et le modele s y conforme au lieu de la contourner : la section 1.7 n autorise
// que des multiples de quatre, une valeur intermediaire est donc ramenee au pas
// le plus proche des sa construction.
//
// Les bornes sont dans les types plutot que dans la vue. Un curseur d interface
// borne ce qu il affiche, il ne borne pas ce qu une reprise de synchronisation,
// une base migree ou un prereglage importe peut faire entrer dans le modele. La
// seule facon qu une valeur hors bornes n existe jamais est qu aucun
// constructeur ne sache en fabriquer une.
//

/// Part de la largeur disponible qu occupe la colonne, en pour cent.
///
/// La section 5.8 fixe la plage de la valeur libre a quarante pour cent
/// minimum : en dessous, la colonne devient une bande ou le dessin d un webtoon
/// n est plus lisible.
public struct PourcentageDeColonne: Sendable, Hashable, Codable, Comparable {
    /// Part la plus etroite qu une colonne libre accepte.
    public static let minimum = 40

    /// Part la plus large, celle qui remplit la fenetre.
    public static let maximum = 100

    /// Valeur retenue, toujours dans la plage.
    public let valeur: Int

    /// Construit une part, ramenee dans la plage.
    public init(_ valeur: Int) {
        self.valeur = min(max(valeur, Self.minimum), Self.maximum)
    }

    /// Part exprimee entre zero et un.
    public var fraction: Double {
        Double(valeur) / 100
    }

    /// Relit une part persistee en la faisant repasser par les bornes.
    ///
    /// Le decodage synthetise par le compilateur poserait la valeur telle quelle
    /// et laisserait entrer une part de cinq cents pour cent ecrite par une
    /// version plus permissive, ou par une synchronisation venue d ailleurs. La
    /// borne ne vaut que si elle tient sur tous les chemins d entree.
    public init(from decoder: any Decoder) throws {
        try self.init(decoder.singleValueContainer().decode(Int.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var conteneur = encoder.singleValueContainer()

        try conteneur.encode(valeur)
    }

    public static func < (gauche: PourcentageDeColonne, droite: PourcentageDeColonne) -> Bool {
        gauche.valeur < droite.valeur
    }
}

/// Largeur de la colonne centrale du lecteur webtoon, section 5.8.
public enum LargeurDeColonne: Sendable, Hashable, Codable {
    /// Colonne posee a la largeur naturelle de la page, sans agrandissement.
    ///
    /// Ce choix peut descendre sous les quarante pour cent de la valeur libre,
    /// et ce n est pas une incoherence : il ne fixe aucune part, il suit la
    /// planche. Une bande de 800 pixels dans une fenetre large tombe au cas de
    /// reference de la section 5.8, trente deux pour cent.
    case ajustee

    /// Colonne etalee sur toute la largeur disponible.
    case pleineLargeur

    /// Part libre de la largeur disponible, entre quarante et cent pour cent.
    case libre(PourcentageDeColonne)

    /// Choix applique tant que l utilisateur n a rien regle.
    public static let parDefaut = LargeurDeColonne.ajustee

    /// Construit une largeur libre a partir d un entier quelconque.
    public static func libre(pourCent: Int) -> LargeurDeColonne {
        .libre(PourcentageDeColonne(pourCent))
    }

    /// Part retenue, nulle quand la largeur suit la page plutot qu une part.
    public var pourcentage: PourcentageDeColonne? {
        guard case let .libre(part) = self else { return nil }

        return part
    }

    /// Largeur de la colonne, en points.
    ///
    /// - Parameters:
    ///   - disponible: largeur utile de la fenetre, marges deduites.
    ///   - largeurNaturelle: largeur de la page telle qu elle serait posee sans
    ///     agrandissement. Ignoree par les deux autres choix.
    /// - Returns: une largeur jamais negative et jamais superieure au
    ///   disponible. Une colonne plus large que la fenetre imposerait un
    ///   defilement horizontal, que le mode vertical ne propose pas.
    public func largeur(dans disponible: Double, largeurNaturelle: Double = 0) -> Double {
        let utile = max(0, disponible)

        switch self {
        case .ajustee:
            return largeurNaturelle > 0 ? min(largeurNaturelle, utile) : utile
        case .pleineLargeur:
            return utile
        case let .libre(part):
            return utile * part.fraction
        }
    }
}

/// Espace vertical laisse entre deux pages du defilement webtoon, section 5.8.
///
/// Zero est une valeur ordinaire et meme le defaut : le tableau 7.1 du cahier de
/// developpement decrit le webtoon comme un defilement vertical sans separation,
/// et une bande decoupee en plusieurs fichiers doit se recoller sans couture.
public struct EspacementEntrePages: Sendable, Hashable, Codable, Comparable {
    /// Aucun espace, les pages se touchent.
    public static let minimum = 0

    /// Espace le plus large, dernier cran de l echelle de la section 1.7.
    public static let maximum = 24

    /// Pas de l echelle d espacement du systeme de design.
    public static let pas = 4

    /// Espace retenu, en points, toujours un multiple du pas.
    public let points: Int

    /// Construit un espacement, borne puis ramene au cran le plus proche.
    public init(points: Int) {
        let borne = min(max(points, Self.minimum), Self.maximum)

        self.points = (borne + Self.pas / 2) / Self.pas * Self.pas
    }

    /// Espacement applique tant que l utilisateur n a rien regle.
    public static let parDefaut = EspacementEntrePages(points: 0)

    /// Les sept seules valeurs que le reglage peut prendre.
    public static let valeursProposees: [EspacementEntrePages] = stride(
        from: minimum,
        through: maximum,
        by: pas
    ).map { EspacementEntrePages(points: $0) }

    /// Espace exprime dans l unite de la pile de defilement.
    public var interstice: Double {
        Double(points)
    }

    /// Relit un espacement persiste en le faisant repasser par les bornes et par
    /// l echelle, pour la meme raison que la part de colonne.
    public init(from decoder: any Decoder) throws {
        try self.init(points: decoder.singleValueContainer().decode(Int.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var conteneur = encoder.singleValueContainer()

        try conteneur.encode(points)
    }

    public static func < (gauche: EspacementEntrePages, droite: EspacementEntrePages) -> Bool {
        gauche.points < droite.points
    }
}

/// Reglages de mise en page du lecteur webtoon.
public struct ReglagesDeWebtoon: Sendable, Hashable, Codable {
    /// Largeur de la colonne centrale.
    public let largeurDeColonne: LargeurDeColonne

    /// Espace entre deux pages empilees.
    public let espacement: EspacementEntrePages

    public init(
        largeurDeColonne: LargeurDeColonne = .parDefaut,
        espacement: EspacementEntrePages = .parDefaut
    ) {
        self.largeurDeColonne = largeurDeColonne
        self.espacement = espacement
    }

    /// Reglages appliques a l ouverture, avant tout choix de l utilisateur.
    public static let parDefaut = ReglagesDeWebtoon()

    /// Largeur de la colonne pour cette fenetre, en points.
    public func largeurDeColonne(dans disponible: Double, largeurNaturelle: Double = 0) -> Double {
        largeurDeColonne.largeur(dans: disponible, largeurNaturelle: largeurNaturelle)
    }
}
