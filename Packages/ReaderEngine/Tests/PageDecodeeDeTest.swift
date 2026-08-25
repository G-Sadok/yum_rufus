import Core
import CoreGraphics
import Foundation
import ImageIO
import ImagePipeline
import UniformTypeIdentifiers

//
// PageDecodeeDeTest
//
// Fabriques de pages pour les tests du moteur de lecture : une page decodee
// legere pour les tests de file, et une page de scan encodee en JPEG pour la
// mesure de la tourne de page.
//
// Ces fabriques existent deja, presque a l identique, dans les tests
// d ImagePipeline. La duplication est assumee : SwiftPM ne permet pas a une
// cible de test de dependre d une autre cible de test, et exposer un jeu de
// fixtures dans le code livre pour eviter de le recopier ici serait un remede
// pire que le mal.
//

enum PageDecodeeDeTest {
    /// Page decodee carree, ou nil si le systeme refuse la matrice.
    static func image(cote: Int = 64) -> ImageDePage? {
        guard let contexte = matrice(largeur: cote, hauteur: cote) else {
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

    /// Page de scan de 3000 par 4500, encodee en JPEG comme dans une archive.
    ///
    /// Construite une seule fois : sa fabrication demande une matrice de 54 Mo,
    /// que la mesure de tourne de page n a aucune raison de payer a chaque test.
    static let scanStandard: Data = scan(largeur: 3000, hauteur: 4500)

    private static func scan(largeur: Int, hauteur: Int) -> Data {
        guard let contexte = matrice(largeur: largeur, hauteur: hauteur) else {
            return Data()
        }

        dessinerDesBandes(dans: contexte, largeur: largeur, hauteur: hauteur)

        guard let image = contexte.makeImage() else {
            return Data()
        }

        return encoderEnJpeg(image)
    }

    private static func matrice(largeur: Int, hauteur: Int) -> CGContext? {
        CGContext(
            data: nil,
            width: largeur,
            height: hauteur,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )
    }

    /// Bandes plutot qu aplat uni : une image uniforme se compresse en quelques
    /// centaines d octets et son decodage ne ressemble plus a celui d un scan.
    private static func dessinerDesBandes(dans contexte: CGContext, largeur: Int, hauteur: Int) {
        let nombreDeBandes = 32
        let hauteurDeBande = max(1, hauteur / nombreDeBandes)

        for bande in 0..<nombreDeBandes {
            contexte.setFillColor(gray: CGFloat(bande % 2 == 0 ? 0.18 : 0.92), alpha: 1)
            contexte.fill(CGRect(
                x: 0,
                y: bande * hauteurDeBande,
                width: largeur,
                height: hauteurDeBande
            ))
        }
    }

    private static func encoderEnJpeg(_ image: CGImage) -> Data {
        let tampon = NSMutableData()

        guard let destination = CGImageDestinationCreateWithData(
            tampon as CFMutableData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return Data()
        }

        CGImageDestinationAddImage(destination, image, nil)

        guard CGImageDestinationFinalize(destination) else {
            return Data()
        }

        return tampon as Data
    }
}
