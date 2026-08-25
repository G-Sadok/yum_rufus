import Core
import CoreGraphics
import Foundation

//
// RasterisateurSvg
//
// Rendu d un document SVG a la taille exacte a laquelle il sera affiche.
//
// Un format vectoriel echappe au piege du sous echantillonnage : il n a pas de
// pleine resolution a reduire, on le dessine directement a la taille voulue.
// Il n echappe pas au budget memoire pour autant. Un document dont la taille
// propre est de 8000 par 12000 remplirait 384 Mo si on la prenait au mot, le
// meme plafond que les images matricielles s applique donc.
//
// La matrice produite garde son canal alpha, contrairement a celle des images
// matricielles. Un dessin vectoriel est presque toujours pose sur un fond
// transparent, et l aplatir sur du noir des le decodage rendrait noir tout
// dessin au trait. Le fond du lecteur, lui, est un jeton de design, ce paquet
// n a pas a le choisir.
//

/// Rendu d un document SVG vers une page decodee.
enum RasterisateurSvg {
    /// Rasterise un document a la taille de la zone, sous le budget memoire.
    ///
    /// - Parameters:
    ///   - donnees: octets du document.
    ///   - nom: nom de l entree, repris dans les erreurs.
    ///   - zone: zone d affichage en pixels reels.
    ///   - budget: plafond memoire de la page rendue.
    /// - Throws: `ErreurDeDecodage` quand le document n est pas lisible ou que
    ///   le systeme refuse la matrice.
    static func rasteriser(
        _ donnees: Data,
        nom: String,
        dans zone: TailleEnPixels,
        budget: BudgetDeDecodage
    ) throws -> ImageDePage {
        guard let document = DocumentSvg.lire(donnees) else {
            throw ErreurDeDecodage.formatInconnu(nom: nom)
        }

        let tailleDOrigine = taillePropre(de: document)

        guard tailleDOrigine.estVide == false else {
            throw ErreurDeDecodage.dimensionsIllisibles(nom: nom)
        }

        let cible = tailleDeRendu(pour: tailleDOrigine, dans: zone, budget: budget)

        guard let image = dessiner(document, dans: cible) else {
            throw ErreurDeDecodage.decodageImpossible(nom: nom)
        }

        return ImageDePage(
            image: image,
            tailleDOrigine: tailleDOrigine,
            tailleDecodee: TailleEnPixels(largeur: image.width, hauteur: image.height),
            niveau: .affichage
        )
    }

    /// Dimensions annoncees par le document, sans rien dessiner.
    static func dimensions(_ donnees: Data, nom: String) throws -> TailleEnPixels {
        guard let document = DocumentSvg.lire(donnees) else {
            throw ErreurDeDecodage.formatInconnu(nom: nom)
        }

        let taille = taillePropre(de: document)

        guard taille.estVide == false else {
            throw ErreurDeDecodage.dimensionsIllisibles(nom: nom)
        }

        return taille
    }

    /// Taille propre du document, arrondie au pixel.
    private static func taillePropre(de document: DocumentSvg) -> TailleEnPixels {
        TailleEnPixels(
            largeur: Int(document.taille.width.rounded()),
            hauteur: Int(document.taille.height.rounded())
        )
    }

    /// Taille de la matrice a produire, zone et budget appliques.
    ///
    /// Le meme calcul que pour une image matricielle, aux memes bornes. La zone
    /// nulle, celle d une vue pas encore mesuree, laisse le budget seul decider,
    /// exactement comme le decodeur d images.
    private static func tailleDeRendu(
        pour taille: TailleEnPixels,
        dans zone: TailleEnPixels,
        budget: BudgetDeDecodage
    ) -> TailleEnPixels {
        let ajuste = AjustementDePage.coteMaximalADecoder(page: taille, dans: zone)
        let cote = budget.coteMaximal(pour: taille, sansDepasser: ajuste)

        return BudgetDeDecodage.reduction(de: taille, vers: cote)
    }

    /// Peint le document dans une matrice de la taille demandee.
    private static func dessiner(_ document: DocumentSvg, dans taille: TailleEnPixels) -> CGImage? {
        let format = CGImageAlphaInfo.premultipliedLast.rawValue

        guard taille.estVide == false,
              let contexte = CGContext(
                  data: nil,
                  width: taille.largeur,
                  height: taille.hauteur,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: format
              )
        else {
            return nil
        }

        contexte.setShouldAntialias(true)
        appliquerLeCadre(document.cadre, dans: contexte, taille: taille)

        for peinture in document.peintures {
            peindre(peinture, dans: contexte)
        }

        return contexte.makeImage()
    }

    /// Envoie le cadre du document sur la matrice entiere.
    ///
    /// Le retournement vertical est fait ici, une seule fois. L ordonnee croit
    /// vers le bas dans un document SVG et vers le haut dans un contexte Core
    /// Graphics, et retourner chaque forme separement inverserait au passage le
    /// sens de rotation des arcs.
    private static func appliquerLeCadre(_ cadre: CGRect, dans contexte: CGContext, taille: TailleEnPixels) {
        contexte.translateBy(x: 0, y: CGFloat(taille.hauteur))
        contexte.scaleBy(x: 1, y: -1)
        contexte.scaleBy(
            x: CGFloat(taille.largeur) / cadre.width,
            y: CGFloat(taille.hauteur) / cadre.height
        )
        contexte.translateBy(x: -cadre.minX, y: -cadre.minY)
    }

    private static func peindre(_ peinture: PeintureSvg, dans contexte: CGContext) {
        if let remplissage = peinture.style.remplissageEffectif {
            contexte.addPath(peinture.chemin)
            contexte.setFillColor(remplissage)
            contexte.fillPath(using: peinture.style.regleDeRemplissage)
        }

        guard let contour = peinture.style.contourEffectif else { return }

        contexte.addPath(peinture.chemin)
        contexte.setStrokeColor(contour)
        contexte.setLineWidth(peinture.style.epaisseurDeContour)
        contexte.setLineCap(peinture.style.extremite)
        contexte.setLineJoin(peinture.style.jointure)
        contexte.strokePath()
    }
}
