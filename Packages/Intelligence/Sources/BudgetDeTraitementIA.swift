import Core

//
// BudgetDeTraitementIA
//
// Plafond memoire d une page produite par un modele embarque.
//
// Le budget n est pas celui du modele, qui est borne par le tuilage, mais celui
// du resultat. Une page produite est tenue entiere en memoire le temps d etre
// rendue puis mise en cache, et une planche de webtoon surelevee par deux depasse
// facilement ce que la section 12 accorde a la lecture entiere. Le plafond est
// donc verifie avant le premier pixel : refuser une page coute une page non
// amelioree, la laisser passer coute l application.
//

/// Plafond memoire d une page produite par un traitement IA.
public struct BudgetDeTraitementIA: Sendable, Hashable {
    /// Nombre d octets que la page produite ne doit pas depasser.
    public let octetsParPage: Int

    /// Construit un budget, en refusant un plafond plus petit qu une tuile.
    public init(octetsParPage: Int) {
        self.octetsParPage = max(Self.plancher, octetsParPage)
    }

    /// Budget de l amelioration IA en deux fois.
    ///
    /// Quarante huit millions d octets, soit exactement quatre fois le plafond
    /// de decodage de la section 6.1. Une surelevation par deux quadruple le
    /// nombre de pixels : une page decodee sous son budget rentre donc toujours
    /// sous celui ci, et une page qui n y rentre pas est une page que le
    /// decodage n aurait pas du produire.
    public static let surelevation = BudgetDeTraitementIA(octetsParPage: 48_000_000)

    /// Budget de la colorisation par IA.
    ///
    /// Le meme plafond que la surelevation, et non celui du decodage. La
    /// colorisation ne change pas les dimensions, mais la section 6.3 la place
    /// apres l amelioration : quand les deux interrupteurs sont armes, son
    /// entree est deja quadruplee, et un plafond de douze millions d octets
    /// refuserait toute page des que l amelioration est active.
    public static let colorisation = BudgetDeTraitementIA(octetsParPage: 48_000_000)

    /// Budget de la detection de cases.
    ///
    /// Le detecteur ne produit pas de page, il produit une poignee de
    /// rectangles. Le budget porte donc sur son entree, la planche recopiee en
    /// matrice pour etre donnee au reseau, et il vaut le plafond de decodage de
    /// la section 6.1 : une page que le decodage a laisse passer entre ici, une
    /// page plus lourde n a pas a etre recopiee une seconde fois en memoire
    /// pour un zoom.
    public static let detectionDeCases = BudgetDeTraitementIA(octetsParPage: 12_000_000)

    /// Budget de la traduction des bulles.
    ///
    /// Le meme plafond que la detection de cases, et pour la meme raison : la
    /// traduction ne produit pas de page, elle produit une poignee de
    /// rectangles et de phrases. Le budget porte donc sur son entree, la planche
    /// recopiee en matrice pour etre lue, et il vaut le plafond de decodage de
    /// la section 6.1.
    public static let traduction = BudgetDeTraitementIA(octetsParPage: 12_000_000)

    /// Plus petit plafond accepte, celui d une tuile de 256 surelevee par deux.
    private static let plancher = 512 * 512 * MatriceDePixels.octetsParPixel

    /// Vrai quand une page de cette taille tient sous le plafond.
    public func accepte(_ taille: TailleEnPixels) -> Bool {
        taille.estVide == false && taille.octetsUneFoisDecodee <= octetsParPage
    }
}
