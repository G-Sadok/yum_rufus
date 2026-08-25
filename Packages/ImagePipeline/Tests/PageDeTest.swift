import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

//
// PageDeTest
//
// Fabrique des pages de scan synthetiques, encodees en JPEG comme celles que
// contiennent les archives reelles.
//
// La page de reference fait 3000 par 4500, la taille exacte du critere de la
// fonctionnalite. Elle est construite une seule fois, parce que la construire
// demande une matrice de 54 Mo qui fausserait toute mesure memoire prise
// pendant sa fabrication.
//

enum PageDeTest {
    /// Page de 3000 par 4500, celle du critere de budget memoire.
    static let standard: Data = fabriquer(largeur: 3000, hauteur: 4500)

    /// Octets JPEG d une page unie decoupee en bandes.
    ///
    /// Les bandes evitent une image parfaitement uniforme, que l encodeur
    /// reduirait a quelques centaines d octets et dont le decodage ne
    /// ressemblerait plus a celui d un scan.
    ///
    /// - Returns: les octets encodes, ou des octets vides si le systeme refuse
    ///   la matrice. Les tests verifient que la page n est pas vide plutot que
    ///   de forcer un deballage interdit par l analyse statique.
    static func fabriquer(largeur: Int, hauteur: Int) -> Data {
        guard let contexte = CGContext(
            data: nil,
            width: largeur,
            height: hauteur,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            return Data()
        }

        dessinerDesBandes(dans: contexte, largeur: largeur, hauteur: hauteur)

        guard let image = contexte.makeImage() else {
            return Data()
        }

        return encoderEnJpeg(image)
    }

    private static func dessinerDesBandes(dans contexte: CGContext, largeur: Int, hauteur: Int) {
        let nombreDeBandes = 32
        let hauteurDeBande = max(1, hauteur / nombreDeBandes)

        for bande in 0..<nombreDeBandes {
            // Un scan est un gris, et le remplissage en gris evite en prime le
            // motif de couleur en dur que le controle 5 cherche dans les vues.
            let ton = CGFloat(bande % 2 == 0 ? 0.18 : 0.92)
            contexte.setFillColor(gray: ton, alpha: 1)
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
