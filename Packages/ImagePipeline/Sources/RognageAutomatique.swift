import Core
import CoreGraphics

//
// RognageAutomatique
//
// Detection et suppression des marges d une page, premiere etape de la chaine
// de traitement de la section 6.3.
//
// L analyse se fait en deux passes. Les lignes d abord, sur toute la largeur,
// ce qui donne la bande verticale utile. Les colonnes ensuite, mais seulement
// a l interieur de cette bande. L ordre compte : mesurer les colonnes sur toute
// la hauteur les ferait passer par les marges hautes et basses, qui sont unies
// et tireraient chaque colonne vers la marge, jusqu a ne plus rien rogner sur
// les cotes.
//
// Une bande unie proche du blanc ou du noir est une marge. Les deux conditions
// sont exigees ensemble, voir `ReglagesDeRognage`.
//
// Trois refus explicites, tous rendant la page entiere plutot qu une page
// abimee. Une page entierement unie, cas de la page noire pleine, n a pas de
// contenu a cadrer. Une page sans aucune bande unie n a pas de marge. Un
// rognage qui laisserait moins que la part minimale s est trompe.
//
// Le rognage ne remonte aucune erreur. C est une etape de confort : quand elle
// echoue, la page s affiche non rognee, elle ne manque pas.
//

/// Zone d une page que le rognage conserve, en pixels, origine en haut a gauche.
public struct ZoneUtile: Sendable, Hashable {
    /// Colonne du premier pixel conserve.
    public let origineX: Int

    /// Ligne du premier pixel conserve, comptee depuis le haut.
    public let origineY: Int

    /// Dimensions de la zone conservee.
    public let taille: TailleEnPixels

    public init(origineX: Int, origineY: Int, taille: TailleEnPixels) {
        self.origineX = max(0, origineX)
        self.origineY = max(0, origineY)
        self.taille = taille
    }

    /// Zone qui couvre toute une page, celle d une page que rien ne rogne.
    public static func entiere(_ taille: TailleEnPixels) -> ZoneUtile {
        ZoneUtile(origineX: 0, origineY: 0, taille: taille)
    }

    /// Vrai quand la zone couvre exactement ces dimensions.
    public func couvreToute(_ dimensions: TailleEnPixels) -> Bool {
        origineX == 0 && origineY == 0 && taille == dimensions
    }
}

/// Detecte les marges d une page et les supprime.
public struct RognageAutomatique: Sendable {
    /// Parametres appliques par ce rognage.
    public let reglages: ReglagesDeRognage

    public init(reglages: ReglagesDeRognage = .parDefaut) {
        self.reglages = reglages
    }

    /// Zone utile d une page decodee.
    ///
    /// Rend la zone entiere quand le rognage est inactif, quand la page n a
    /// aucune marge, ou quand la detection est jugee peu sure.
    public func zoneUtile(de page: ImageDePage) -> ZoneUtile {
        zoneUtile(de: page.image)
    }

    /// Page rognee de ses marges, ou la page telle quelle si rien n est a couper.
    public func rogner(_ page: ImageDePage) -> ImageDePage {
        appliquer(zoneUtile(de: page), a: page)
    }

    /// Applique une zone deja connue a une page.
    ///
    /// Separe de la detection pour que la zone puisse venir d un cache plutot
    /// que d une nouvelle analyse.
    ///
    /// La page rognee est redessinee dans une matrice a elle. `cropping` seul
    /// rendrait une image qui garde la matrice complete vivante derriere elle :
    /// la page paraitrait plus petite sans qu un octet soit rendu, et le compte
    /// du cache memoire deviendrait faux.
    public func appliquer(_ zone: ZoneUtile, a page: ImageDePage) -> ImageDePage {
        let dimensions = TailleEnPixels(largeur: page.image.width, hauteur: page.image.height)

        guard zone.couvreToute(dimensions) == false,
              zone.taille.estVide == false,
              zone.origineX + zone.taille.largeur <= dimensions.largeur,
              zone.origineY + zone.taille.hauteur <= dimensions.hauteur,
              let coupee = page.image.cropping(
                  to: CGRect(
                      x: zone.origineX,
                      y: zone.origineY,
                      width: zone.taille.largeur,
                      height: zone.taille.hauteur
                  )
              ),
              let materialisee = DecodeurDePage.materialiser(coupee)
        else {
            return page
        }

        return ImageDePage(
            image: materialisee,
            tailleDOrigine: page.tailleDOrigine,
            tailleDecodee: TailleEnPixels(largeur: materialisee.width, hauteur: materialisee.height),
            niveau: page.niveau
        )
    }

    /// Zone utile d une image, mesuree sur sa matrice de gris.
    func zoneUtile(de image: CGImage) -> ZoneUtile {
        let dimensions = TailleEnPixels(largeur: image.width, hauteur: image.height)

        guard reglages.actif, let matrice = MatriceDeGris(image) else {
            return .entiere(dimensions)
        }

        return zoneUtile(de: matrice)
    }

    /// Zone utile mesuree sur une matrice de gris.
    func zoneUtile(de matrice: MatriceDeGris) -> ZoneUtile {
        let dimensions = matrice.taille

        guard reglages.actif else {
            return .entiere(dimensions)
        }

        let toutesLesColonnes = 0..<matrice.largeur

        guard let lignes = bandeUtile(dans: 0..<matrice.hauteur, uniforme: { ligne in
            estUneMarge(matrice.statistiques(ligne: ligne, colonnes: toutesLesColonnes))
        }) else {
            return .entiere(dimensions)
        }

        guard let colonnes = bandeUtile(dans: toutesLesColonnes, uniforme: { colonne in
            estUneMarge(matrice.statistiques(colonne: colonne, lignes: lignes))
        }) else {
            return .entiere(dimensions)
        }

        return zoneAvecMarge(colonnes: colonnes, lignes: lignes, dans: dimensions)
    }

    /// Bande qui reste une fois les indices uniformes retires de chaque bout.
    ///
    /// Rend nil quand tous les indices sont uniformes : la page est alors unie
    /// d un bord a l autre et n a pas de contenu a cadrer.
    private func bandeUtile(dans indices: Range<Int>, uniforme: (Int) -> Bool) -> Range<Int>? {
        var debut = indices.lowerBound
        var fin = indices.upperBound

        while debut < fin, uniforme(debut) {
            debut += 1
        }

        guard debut < fin else {
            return nil
        }

        while fin > debut, uniforme(fin - 1) {
            fin -= 1
        }

        return debut..<fin
    }

    /// Zone finale, marge de securite rendue au contenu et garde appliquee.
    private func zoneAvecMarge(
        colonnes: Range<Int>,
        lignes: Range<Int>,
        dans dimensions: TailleEnPixels
    ) -> ZoneUtile {
        let marge = reglages.margeDeSecurite
        let gauche = max(0, colonnes.lowerBound - marge)
        let droite = min(dimensions.largeur, colonnes.upperBound + marge)
        let haut = max(0, lignes.lowerBound - marge)
        let bas = min(dimensions.hauteur, lignes.upperBound + marge)

        let zone = ZoneUtile(
            origineX: gauche,
            origineY: haut,
            taille: TailleEnPixels(largeur: droite - gauche, hauteur: bas - haut)
        )

        guard partConservee(zone, dans: dimensions) >= reglages.partMinimaleConservee else {
            return .entiere(dimensions)
        }

        return zone
    }

    /// Part de la surface d origine que cette zone conserve.
    private func partConservee(_ zone: ZoneUtile, dans dimensions: TailleEnPixels) -> Double {
        let surfaceDOrigine = Double(dimensions.largeur) * Double(dimensions.hauteur)

        guard surfaceDOrigine > 0 else {
            return 0
        }

        return Double(zone.taille.largeur) * Double(zone.taille.hauteur) / surfaceDOrigine
    }

    /// Vrai quand une bande est unie et assez proche du blanc ou du noir pur.
    private func estUneMarge(_ statistiques: MatriceDeGris.Statistiques) -> Bool {
        guard statistiques.variance <= reglages.seuilDeVariance else {
            return false
        }

        return statistiques.moyenne >= 1 - reglages.toleranceDeBlanc
            || statistiques.moyenne <= reglages.toleranceDeNoir
    }
}
