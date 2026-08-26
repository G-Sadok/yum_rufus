import Core
import CoreGraphics

//
// DivisionDImageLarge
//
// Coupe en deux une planche plus large que haute, deuxieme etape de la chaine
// de traitement de la section 6.3.
//
// Deux promesses, et le reste en decoule.
//
// Le raccord ne laisse aucun artefact. Les colonnes de l image d origine sont
// partagees exactement entre les deux moities : la moitie de gauche prend
// `0..<milieu`, celle de droite prend `milieu..<largeur`. Aucune colonne n est
// prise deux fois, aucune n est perdue. Une colonne partagee dessinerait un
// trait double au bord interieur des deux moities, une colonne perdue ferait
// sauter le trait au meme endroit, et les deux se voient exactement la ou l oeil
// se pose en tournant la page. La coupe tombe sur une frontiere de pixel, jamais
// entre deux, et la moitie est redessinee a l echelle un pour un : aucun
// reechantillonnage n intervient, donc aucun pixel n est interpole.
//
// L ordre des deux moities suit le sens de lecture, et cet ordre vient de
// `SensDeLecture.ordreDesMoities`. En droite a gauche la moitie droite est
// rendue en premier.
//
// La division ne remonte aucune erreur. C est une etape de confort : quand le
// systeme refuse une matrice, la page s affiche entiere, elle ne manque pas.
//

/// Portion de colonnes qu une moitie preleve dans l image d origine.
public struct DecoupeDeMoitie: Sendable, Hashable {
    /// Moitie que cette decoupe produit.
    public let moitie: MoitieDImageLarge

    /// Colonne du premier pixel preleve, comptee depuis le bord gauche.
    public let origineX: Int

    /// Dimensions de la moitie.
    public let taille: TailleEnPixels

    public init(moitie: MoitieDImageLarge, origineX: Int, taille: TailleEnPixels) {
        self.moitie = moitie
        self.origineX = max(0, origineX)
        self.taille = taille
    }

    /// Colonnes de l image d origine que cette moitie emporte.
    public var colonnes: Range<Int> {
        origineX..<(origineX + taille.largeur)
    }
}

/// Moitie d une image large, une fois decoupee.
public struct MoitieDePage: Sendable {
    /// Cote de l image d origine dont cette page provient.
    public let moitie: MoitieDImageLarge

    /// Page decodee correspondante.
    public let page: ImageDePage

    public init(moitie: MoitieDImageLarge, page: ImageDePage) {
        self.moitie = moitie
        self.page = page
    }
}

/// Coupe une image large en deux moities rangees dans le sens de lecture.
public struct DivisionDImageLarge: Sendable {
    /// Parametres appliques par cette division.
    public let reglages: ReglagesDeDivision

    public init(reglages: ReglagesDeDivision = .parDefaut) {
        self.reglages = reglages
    }

    /// Vrai quand une page de cette taille doit etre coupee en deux.
    ///
    /// Aucune des deux moities ne peut sortir vide de la coupe. Une page
    /// declaree large est plus large que haute et sa hauteur n est pas nulle,
    /// donc sa largeur vaut au moins deux colonnes, et chaque moitie en recoit
    /// au moins une.
    public func doitDiviser(_ taille: TailleEnPixels) -> Bool {
        guard reglages.actif else {
            return false
        }

        return reglages.detection.estLarge(taille)
    }

    /// Colonne ou passe la coupe, celle du premier pixel de la moitie de droite.
    ///
    /// Une largeur impaire ne se partage pas en deux parts egales. La colonne
    /// supplementaire va a la moitie de droite. Le choix est arbitraire, mais il
    /// est fixe : ce qui compte est que les deux moities se suivent sans trou ni
    /// recouvrement, pas qu elles pesent le meme nombre de colonnes.
    public static func milieu(de largeur: Int) -> Int {
        largeur / 2
    }

    /// Decoupes des deux moities, dans l ordre de lecture.
    ///
    /// Rend une liste vide quand la page ne doit pas etre coupee, ce qui laisse
    /// l appelant afficher la page entiere sans avoir a redemander pourquoi.
    public func decoupes(de taille: TailleEnPixels, sens: SensDeLecture) -> [DecoupeDeMoitie] {
        guard doitDiviser(taille) else {
            return []
        }

        let milieu = Self.milieu(de: taille.largeur)
        let decoupes: [MoitieDImageLarge: DecoupeDeMoitie] = [
            .gauche: DecoupeDeMoitie(
                moitie: .gauche,
                origineX: 0,
                taille: TailleEnPixels(largeur: milieu, hauteur: taille.hauteur)
            ),
            .droite: DecoupeDeMoitie(
                moitie: .droite,
                origineX: milieu,
                taille: TailleEnPixels(largeur: taille.largeur - milieu, hauteur: taille.hauteur)
            ),
        ]

        return sens.ordreDesMoities.compactMap { decoupes[$0] }
    }

    /// Moities d une page large, dans l ordre de lecture.
    ///
    /// Rend une liste vide quand la page n est pas coupee, et quand le systeme
    /// refuse l une des deux matrices. Dans les deux cas l appelant affiche la
    /// page entiere.
    public func moities(de page: ImageDePage, sens: SensDeLecture) -> [MoitieDePage] {
        let decoupes = decoupes(de: dimensions(de: page), sens: sens)

        guard decoupes.isEmpty == false else {
            return []
        }

        let moities = decoupes.compactMap { decoupe in
            appliquer(decoupe, a: page).map { MoitieDePage(moitie: decoupe.moitie, page: $0) }
        }

        // Une seule moitie produite laisserait la moitie de la planche invisible
        // sans que rien ne le signale. Mieux vaut alors la planche entiere.
        guard moities.count == decoupes.count else {
            return []
        }

        return moities
    }

    /// Pages a afficher pour cette page source, dans l ordre de lecture.
    ///
    /// Deux pages quand la planche est coupee, la page elle meme sinon. C est le
    /// point d entree de la chaine de traitement : il rend toujours de quoi
    /// afficher.
    public func pages(de page: ImageDePage, sens: SensDeLecture) -> [ImageDePage] {
        let moities = moities(de: page, sens: sens)

        guard moities.isEmpty == false else {
            return [page]
        }

        return moities.map(\.page)
    }

    /// Dimensions reelles de la matrice d une page.
    ///
    /// Mesurees sur l image et non sur `tailleDecodee`, qui decrit ce que le
    /// decodeur visait. Une page deja rognee porte une matrice plus petite que
    /// ce que le fichier annoncait, et c est la matrice que l on coupe.
    private func dimensions(de page: ImageDePage) -> TailleEnPixels {
        TailleEnPixels(largeur: page.image.width, hauteur: page.image.height)
    }

    /// Extrait une moitie, redessinee dans une matrice a elle.
    ///
    /// `cropping` seul rendrait une image qui garde la matrice complete vivante
    /// derriere elle : la planche coupee paraitrait deux fois plus legere sans
    /// qu un octet soit rendu, et les deux moities feraient ensemble trois fois
    /// le poids de la planche d origine dans le compte du cache memoire.
    ///
    /// Le redessin se fait a l echelle un pour un, dans un contexte de la taille
    /// exacte de la moitie. Aucune interpolation n intervient, donc les pixels
    /// de la moitie sont ceux de l image d origine, y compris ceux de la colonne
    /// qui borde la coupe.
    private func appliquer(_ decoupe: DecoupeDeMoitie, a page: ImageDePage) -> ImageDePage? {
        let dimensions = dimensions(de: page)

        guard decoupe.taille.estVide == false,
              decoupe.colonnes.upperBound <= dimensions.largeur,
              decoupe.taille.hauteur <= dimensions.hauteur,
              let coupee = page.image.cropping(
                  to: CGRect(
                      x: decoupe.origineX,
                      y: 0,
                      width: decoupe.taille.largeur,
                      height: decoupe.taille.hauteur
                  )
              ),
              let materialisee = DecodeurDePage.materialiser(coupee)
        else {
            return nil
        }

        return ImageDePage(
            image: materialisee,
            tailleDOrigine: page.tailleDOrigine,
            tailleDecodee: TailleEnPixels(largeur: materialisee.width, hauteur: materialisee.height),
            niveau: page.niveau
        )
    }
}
