import CoreVideo
import Foundation

//
// TamponDePixels
//
// Traduction entre la matrice de pixels du projet et le tampon que Core ML
// attend.
//
// Core ML ne prend pas un tableau d octets, il prend un `CVPixelBuffer`, et les
// modeles d image convertis annoncent presque tous le format 32BGRA. Deux
// details de ce format ont deja coule des portages entiers, ils sont traites
// ici et nulle part ailleurs.
//
// L ordre des canaux est inverse. Un tampon 32BGRA range bleu, vert, rouge,
// alpha, la matrice range rouge, vert, bleu, ignore. Recopier sans permuter
// donne une planche aux couleurs echangees, ce qui ne se voit pas sur un scan
// en noir et blanc et saute aux yeux sur une couverture.
//
// La longueur de ligne du tampon n est pas sa largeur. Core Video aligne ses
// lignes sur une frontiere qui lui appartient, et une tuile de 256 peut fort
// bien porter des lignes de 1024 octets comme de 1088. Lire la ligne suivante
// en supposant la largeur decale l image d un cran par ligne et la penche.
//
// L aller retour est verifie par la suite de tests sur des tuiles reelles, ce
// qui couvre la partie du pont Core ML qu un test peut atteindre sans embarquer
// un reseau de plusieurs dizaines de megaoctets dans le depot.
//

/// Pont entre une matrice de pixels et un tampon Core Video 32BGRA.
enum TamponDePixels {
    /// Tampon 32BGRA portant les pixels de cette matrice.
    ///
    /// Le tampon est cree avec une surface partageable, ce que Core ML exige
    /// pour eviter une recopie a chaque prediction.
    static func creer(_ matrice: MatriceDePixels) -> CVPixelBuffer? {
        let attributs: [CFString: Any] = [
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary,
        ]

        var tampon: CVPixelBuffer?
        let statut = CVPixelBufferCreate(
            kCFAllocatorDefault,
            matrice.largeur,
            matrice.hauteur,
            kCVPixelFormatType_32BGRA,
            attributs as CFDictionary,
            &tampon
        )

        guard statut == kCVReturnSuccess, let tampon else { return nil }
        guard CVPixelBufferLockBaseAddress(tampon, []) == kCVReturnSuccess else { return nil }

        defer { CVPixelBufferUnlockBaseAddress(tampon, []) }

        guard let base = CVPixelBufferGetBaseAddress(tampon) else { return nil }

        let parPixel = MatriceDePixels.octetsParPixel
        let octetsParLigne = CVPixelBufferGetBytesPerRow(tampon)
        let destination = base.bindMemory(
            to: UInt8.self,
            capacity: octetsParLigne * matrice.hauteur
        )

        for ligne in 0..<matrice.hauteur {
            let depart = ligne * octetsParLigne

            for colonne in 0..<matrice.largeur {
                let pixel = depart + colonne * parPixel

                destination[pixel] = matrice.canal(2, colonne: colonne, ligne: ligne)
                destination[pixel + 1] = matrice.canal(1, colonne: colonne, ligne: ligne)
                destination[pixel + 2] = matrice.canal(0, colonne: colonne, ligne: ligne)
                destination[pixel + 3] = 255
            }
        }

        return tampon
    }

    /// Matrice portant les pixels de ce tampon.
    ///
    /// Rend nil sur tout format autre que 32BGRA. Un modele qui rendrait des
    /// niveaux de gris ou du flottant demande une conversion qui lui est propre,
    /// et la deviner ici donnerait une planche fausse au lieu d une erreur.
    static func matrice(de tampon: CVPixelBuffer) -> MatriceDePixels? {
        guard CVPixelBufferGetPixelFormatType(tampon) == kCVPixelFormatType_32BGRA else {
            return nil
        }

        guard CVPixelBufferLockBaseAddress(tampon, .readOnly) == kCVReturnSuccess else {
            return nil
        }

        defer { CVPixelBufferUnlockBaseAddress(tampon, .readOnly) }

        let largeur = CVPixelBufferGetWidth(tampon)
        let hauteur = CVPixelBufferGetHeight(tampon)
        let octetsParLigne = CVPixelBufferGetBytesPerRow(tampon)

        guard largeur > 0, hauteur > 0, let base = CVPixelBufferGetBaseAddress(tampon) else {
            return nil
        }

        let parPixel = MatriceDePixels.octetsParPixel
        let source = base.bindMemory(to: UInt8.self, capacity: octetsParLigne * hauteur)
        var octets = [UInt8](repeating: 0, count: largeur * hauteur * parPixel)

        for ligne in 0..<hauteur {
            let depart = ligne * octetsParLigne
            let arrivee = ligne * largeur * parPixel

            for colonne in 0..<largeur {
                let pixel = depart + colonne * parPixel

                octets[arrivee + colonne * parPixel] = source[pixel + 2]
                octets[arrivee + colonne * parPixel + 1] = source[pixel + 1]
                octets[arrivee + colonne * parPixel + 2] = source[pixel]
                octets[arrivee + colonne * parPixel + 3] = 255
            }
        }

        return MatriceDePixels(largeur: largeur, hauteur: hauteur, octets: octets)
    }
}
