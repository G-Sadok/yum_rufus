import Core
import CoreGraphics
import Foundation
@testable import ImagePipeline

//
// PlancheLarge
//
// Fabrique une planche double dont chaque colonne porte une signature unique.
//
// Les tests de division mesurent un raccord. Une planche unie, ou meme un
// damier a deux valeurs, laisserait passer les trois fautes qui comptent : une
// colonne prise deux fois, une colonne perdue, et un decalage d un pixel entre
// la moitie et la planche. Sur une planche unie, les trois rendent exactement
// la meme image.
//
// La valeur d un pixel est donc fonction de sa colonne et de sa ligne, avec un
// pas premier sur chaque axe. Deux colonnes voisines different sur toutes leurs
// lignes, ce qui rend tout decalage visible ou que l on regarde.
//

enum PlancheLarge {
    /// Pas applique a la colonne. Premier, pour que le motif ne se repete pas
    /// avant d avoir couvert toute la largeur des planches de test.
    private static let pasDeColonne = 37

    /// Pas applique a la ligne.
    private static let pasDeLigne = 11

    /// Matrice dont chaque pixel depend de sa colonne et de sa ligne.
    static func matrice(taille: TailleEnPixels) -> MatriceDeGris? {
        var valeurs = [UInt8](repeating: 0, count: taille.largeur * taille.hauteur)

        for ligne in 0..<taille.hauteur {
            for colonne in 0..<taille.largeur {
                let signature = (colonne * pasDeColonne + ligne * pasDeLigne) % 256
                valeurs[ligne * taille.largeur + colonne] = UInt8(signature)
            }
        }

        return MatriceDeGris(largeur: taille.largeur, hauteur: taille.hauteur, valeurs: valeurs)
    }

    /// Planche decodee portant ce motif.
    static func page(taille: TailleEnPixels) -> ImageDePage? {
        guard let matrice = matrice(taille: taille) else {
            return nil
        }

        return PageAMarges.page(de: matrice)
    }

    /// Nombre de pixels d une moitie qui different de la planche d origine.
    ///
    /// La comparaison se fait avec la matrice relue sur la planche elle meme, et
    /// non avec les valeurs posees au depart. Les deux images traversent alors
    /// la meme conversion vers le gris, et ce que le test mesure est bien la
    /// decoupe, pas l espace de couleur.
    ///
    /// - Parameters:
    ///   - moitie: matrice relue sur la moitie decoupee.
    ///   - planche: matrice relue sur la planche entiere.
    ///   - origineX: colonne de la planche ou la moitie commence.
    /// - Returns: nombre de pixels differents, ou le nombre de pixels de la
    ///   moitie entiere quand elle deborde de la planche. Une moitie qui deborde
    ///   est aussi fausse qu une moitie decalee, et la compter plutot que la
    ///   lire hors bornes rend un test rouge la ou un acces direct planterait
    ///   toute la suite.
    static func ecarts(entre moitie: MatriceDeGris, et planche: MatriceDeGris, origineX: Int) -> Int {
        let pixels = moitie.largeur * moitie.hauteur

        guard origineX >= 0,
              origineX + moitie.largeur <= planche.largeur,
              moitie.hauteur <= planche.hauteur
        else {
            return pixels
        }

        var compte = 0

        for ligne in 0..<moitie.hauteur {
            for colonne in 0..<moitie.largeur {
                let attendue = planche.valeur(colonne: origineX + colonne, ligne: ligne)

                if moitie.valeur(colonne: colonne, ligne: ligne) != attendue {
                    compte += 1
                }
            }
        }

        return compte
    }
}
