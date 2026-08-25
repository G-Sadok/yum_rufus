import Core
import CoreGraphics
import Foundation
@testable import ImagePipeline

//
// PageAMarges
//
// Fabrique des pages de test aux marges connues au pixel pres.
//
// Les tests de rognage portent sur des bordures dont on connait exactement
// l epaisseur, ce qu aucun scan reel ne garantit. La page est donc peinte ici,
// matrice par matrice, puis convertie en image quand le test a besoin du chemin
// complet. Les valeurs sont posees en gris huit bits et l image est produite
// dans le meme espace, sans conversion de couleur qui decalerait les niveaux.
//
// Le contenu est toujours texture, jamais uni : un bloc uni au milieu d une
// page serait une marge selon les memes regles, et le test ne prouverait rien.
//

enum PageAMarges {
    /// Rectangle de contenu, en coordonnees de matrice, origine en haut a gauche.
    struct Bloc {
        let origineX: Int
        let origineY: Int
        let largeur: Int
        let hauteur: Int

        var colonnes: Range<Int> {
            origineX..<(origineX + largeur)
        }

        var lignes: Range<Int> {
            origineY..<(origineY + hauteur)
        }
    }

    /// Couple de valeurs alternees en damier qui simule un dessin.
    struct Contenu {
        let clair: UInt8
        let sombre: UInt8
    }

    /// Page unie d un bord a l autre.
    static func unie(taille: TailleEnPixels, valeur: UInt8) -> MatriceDeGris? {
        MatriceDeGris(
            largeur: taille.largeur,
            hauteur: taille.hauteur,
            valeurs: [UInt8](repeating: valeur, count: taille.largeur * taille.hauteur)
        )
    }

    /// Page a fond uni portant un bloc de contenu texture.
    ///
    /// Le contenu alterne deux valeurs en damier, ce qui donne une variance
    /// franche sur ses lignes comme sur ses colonnes.
    static func avecContenu(
        taille: TailleEnPixels,
        fond: UInt8,
        bloc: Bloc,
        contenu: Contenu
    ) -> MatriceDeGris? {
        var valeurs = [UInt8](repeating: fond, count: taille.largeur * taille.hauteur)

        peindre(bloc, contenu: contenu, dans: &valeurs, taille: taille)

        return MatriceDeGris(largeur: taille.largeur, hauteur: taille.hauteur, valeurs: valeurs)
    }

    /// Page dont chaque pixel alterne deux valeurs, sans aucune bande unie.
    static func texturee(taille: TailleEnPixels, claire: UInt8, sombre: UInt8) -> MatriceDeGris? {
        var valeurs = [UInt8](repeating: claire, count: taille.largeur * taille.hauteur)

        alterner(sombre, dans: &valeurs, taille: taille)

        return MatriceDeGris(largeur: taille.largeur, hauteur: taille.hauteur, valeurs: valeurs)
    }

    /// Page a fond alternant deux valeurs proches, portant un bloc de contenu.
    ///
    /// Sert a mesurer le seuil de variance : le fond reste clair en moyenne,
    /// seule sa variance decide s il est vu comme une marge.
    static func avecFondAlterne(
        taille: TailleEnPixels,
        fond: Contenu,
        bloc: Bloc
    ) -> MatriceDeGris? {
        var valeurs = [UInt8](repeating: fond.clair, count: taille.largeur * taille.hauteur)

        alterner(fond.sombre, dans: &valeurs, taille: taille)
        peindre(bloc, contenu: Contenu(clair: 90, sombre: 30), dans: &valeurs, taille: taille)

        return MatriceDeGris(largeur: taille.largeur, hauteur: taille.hauteur, valeurs: valeurs)
    }

    /// Image en gris huit bits portant exactement les valeurs de la matrice.
    static func image(de matrice: MatriceDeGris) -> CGImage? {
        guard let contexte = CGContext(
            data: nil,
            width: matrice.largeur,
            height: matrice.hauteur,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ), let base = contexte.data else {
            return nil
        }

        let octetsParLigne = contexte.bytesPerRow
        let destination = base.bindMemory(to: UInt8.self, capacity: octetsParLigne * matrice.hauteur)

        for ligne in 0..<matrice.hauteur {
            for colonne in 0..<matrice.largeur {
                destination[ligne * octetsParLigne + colonne] = matrice.valeur(colonne: colonne, ligne: ligne)
            }
        }

        return contexte.makeImage()
    }

    /// Page decodee portant cette matrice, taille d origine egale a la matrice.
    ///
    /// L image passe par le meme redessin que celui du decodeur, ce qui la pose
    /// dans une matrice quatre octets par pixel. Sans ce passage, la page de
    /// test peserait quatre fois moins qu une page reelle et les comparaisons
    /// de memoire ne voudraient rien dire.
    static func page(de matrice: MatriceDeGris) -> ImageDePage? {
        guard let grise = image(de: matrice),
              let image = DecodeurDePage.materialiser(grise)
        else {
            return nil
        }

        let taille = TailleEnPixels(largeur: matrice.largeur, hauteur: matrice.hauteur)

        return ImageDePage(
            image: image,
            tailleDOrigine: taille,
            tailleDecodee: taille,
            niveau: .affichage
        )
    }

    /// Nombre de pixels d une matrice qui s ecartent du fond de plus de dix niveaux.
    static func pixelsDeContenu(dans matrice: MatriceDeGris, fond: UInt8) -> Int {
        var compte = 0

        for ligne in 0..<matrice.hauteur {
            for colonne in 0..<matrice.largeur {
                let valeur = Int(matrice.valeur(colonne: colonne, ligne: ligne))

                if abs(valeur - Int(fond)) > 10 {
                    compte += 1
                }
            }
        }

        return compte
    }

    /// Pose le damier du contenu dans le rectangle du bloc.
    private static func peindre(
        _ bloc: Bloc,
        contenu: Contenu,
        dans valeurs: inout [UInt8],
        taille: TailleEnPixels
    ) {
        for ligne in bloc.lignes where ligne >= 0 && ligne < taille.hauteur {
            for colonne in bloc.colonnes where colonne >= 0 && colonne < taille.largeur {
                let clair = (colonne + ligne).isMultiple(of: 2)
                valeurs[ligne * taille.largeur + colonne] = clair ? contenu.clair : contenu.sombre
            }
        }
    }

    /// Pose une valeur un pixel sur deux, en damier, sur toute la page.
    private static func alterner(_ valeur: UInt8, dans valeurs: inout [UInt8], taille: TailleEnPixels) {
        for ligne in 0..<taille.hauteur {
            for colonne in 0..<taille.largeur where (colonne + ligne).isMultiple(of: 2) == false {
                valeurs[ligne * taille.largeur + colonne] = valeur
            }
        }
    }
}
