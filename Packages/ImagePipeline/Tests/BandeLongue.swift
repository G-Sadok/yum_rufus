import Core
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
@testable import ImagePipeline

//
// BandeLongue
//
// Fabrique des bandes de webtoon dont chaque ligne porte une signature unique.
//
// Les tests de tuilage mesurent un raccord horizontal. Une bande unie, ou meme
// un damier, laisserait passer les trois fautes qui comptent : une ligne prise
// deux fois, une ligne perdue, et une tuile posee a l envers dans la pile. Sur
// une bande unie, les trois rendent exactement la meme image.
//
// La valeur d un pixel ne depend donc que de sa ligne, avec un pas premier qui
// ne repasse par la meme valeur qu au bout de 256 lignes. Une tuile lue au bon
// endroit porte la suite de valeurs attendue, une tuile decalee d une seule
// ligne ne la porte plus.
//
// L encodage se fait en PNG et non en JPEG. Le tuilage compare des pixels, et la
// perte du JPEG ferait echouer la comparaison pour une raison qui n a rien a
// voir avec la decoupe.
//

enum BandeLongue {
    /// Pas applique a la ligne. Premier avec 256, donc le motif ne se repete
    /// jamais avant d avoir parcouru toutes les valeurs.
    private static let pasDeLigne = 37

    /// Valeur attendue sur une ligne de la bande.
    static func ton(ligne: Int) -> Int {
        (ligne * pasDeLigne) % 256
    }

    /// Matrice dont chaque ligne porte sa propre valeur.
    static func matrice(taille: TailleEnPixels) -> MatriceDeGris? {
        var valeurs = [UInt8](repeating: 0, count: taille.largeur * taille.hauteur)

        for ligne in 0..<taille.hauteur {
            let signature = UInt8(ton(ligne: ligne))

            for colonne in 0..<taille.largeur {
                valeurs[ligne * taille.largeur + colonne] = signature
            }
        }

        return MatriceDeGris(largeur: taille.largeur, hauteur: taille.hauteur, valeurs: valeurs)
    }

    /// Bande decodee portant ce motif.
    static func page(taille: TailleEnPixels) -> ImageDePage? {
        guard let matrice = matrice(taille: taille) else {
            return nil
        }

        return PageAMarges.page(de: matrice)
    }

    /// Octets PNG d une bande portant ce motif.
    ///
    /// - Returns: les octets encodes, ou des octets vides si le systeme refuse
    ///   la matrice. Les tests verifient que la bande n est pas vide plutot que
    ///   de forcer un deballage interdit par l analyse statique.
    static func octets(taille: TailleEnPixels) -> Data {
        guard let matrice = matrice(taille: taille),
              let image = PageAMarges.image(de: matrice)
        else {
            return Data()
        }

        let tampon = NSMutableData()

        guard let destination = CGImageDestinationCreateWithData(
            tampon as CFMutableData,
            UTType.png.identifier as CFString,
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

    /// Nombre de lignes d une tuile qui ne portent pas la valeur attendue.
    ///
    /// - Parameters:
    ///   - tuile: matrice relue sur la tuile decoupee.
    ///   - origineY: ligne de la bande ou la tuile commence.
    ///   - tolerance: ecart accepte, pour absorber la conversion vers le gris.
    static func lignesFausses(dans tuile: MatriceDeGris, origineY: Int, tolerance: Int = 2) -> Int {
        var compte = 0

        for ligne in 0..<tuile.hauteur {
            let attendue = ton(ligne: origineY + ligne)
            let lue = Int(tuile.valeur(colonne: 0, ligne: ligne))

            if abs(lue - attendue) > tolerance {
                compte += 1
            }
        }

        return compte
    }
}
