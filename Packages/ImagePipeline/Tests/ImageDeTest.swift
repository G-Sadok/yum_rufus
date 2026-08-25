import Core
import CoreGraphics
import Foundation
@testable import ImagePipeline

//
// ImageDeTest
//
// Fabrique des pages decodees de poids choisi, sans passer par un encodeur.
//
// Les tests de cache portent sur la comptabilite des octets et sur l ordre
// d eviction, pas sur le decodage, que couvre deja la suite de F010. Fabriquer
// ici une matrice directement evite d encoder puis de redecoder des dizaines de
// pages, ce qui allongerait la suite de plusieurs secondes sans rien prouver de
// plus.
//
// Un cote de 512 pixels donne une matrice d exactement un mebioctet, ce qui
// rend les plafonds des tests lisibles. Les tests lisent malgre tout
// `octetsEnMemoire` sur la page produite plutot que de supposer ce compte.
//

enum ImageDeTest {
    /// Page decodee carree, ou nil si le systeme refuse la matrice.
    static func page(cote: Int = 512) -> ImageDePage? {
        guard let contexte = CGContext(
            data: nil,
            width: cote,
            height: cote,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            return nil
        }

        contexte.setFillColor(gray: 0.5, alpha: 1)
        contexte.fill(CGRect(x: 0, y: 0, width: cote, height: cote))

        guard let image = contexte.makeImage() else {
            return nil
        }

        let taille = TailleEnPixels(largeur: cote, hauteur: cote)

        return ImageDePage(
            image: image,
            tailleDOrigine: taille,
            tailleDecodee: taille,
            niveau: .affichage
        )
    }
}
