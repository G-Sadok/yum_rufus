import CoreGraphics
import Foundation
@testable import ImagePipeline

//
// CoinsDeRampe
//
// Les quatre coins d une page decodee, mesures en niveaux de gris.
//
// C est l assertion qui distingue une image correctement decodee d une image
// retournee, transposee ou remplie de noir. Toutes gardent leurs dimensions,
// seuls les tons des coins changent.
//
// Les points sont pris a cinq pour cent du bord et non sur le pixel du coin.
// Un codec avec perte, une palette de 256 couleurs ou un lissage de bord
// deplacent le tout premier pixel, jamais une zone.
//

struct CoinsDeRampe {
    let hautGauche: Double
    let hautDroit: Double
    let basGauche: Double
    let basDroit: Double

    /// Part du cote a laquelle les points sont pris.
    private static let retrait = 0.05

    /// Mesure les quatre coins, ou rend nil quand la matrice est refusee.
    init?(_ image: CGImage) {
        guard let matrice = MatriceDeGris(image), matrice.largeur > 2, matrice.hauteur > 2 else {
            return nil
        }

        let gauche = Int(Double(matrice.largeur) * Self.retrait)
        let droite = matrice.largeur - 1 - gauche
        let haut = Int(Double(matrice.hauteur) * Self.retrait)
        let bas = matrice.hauteur - 1 - haut

        hautGauche = Double(matrice.valeur(colonne: gauche, ligne: haut))
        hautDroit = Double(matrice.valeur(colonne: droite, ligne: haut))
        basGauche = Double(matrice.valeur(colonne: gauche, ligne: bas))
        basDroit = Double(matrice.valeur(colonne: droite, ligne: bas))
    }
}
