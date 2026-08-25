import CoreGraphics
import Foundation
@testable import ImagePipeline

//
// EchantillonDePage
//
// Lecture d un ton en un point precis d une page decodee.
//
// Sert aux tests de geometrie du rasterisateur SVG, ou l assertion porte sur
// ce qui a ete peint et ou. Les coordonnees sont donnees dans le repere du
// document, ordonnee vers le bas, pour que le test se lise en regard du
// fichier SVG.
//

struct EchantillonDePage {
    private let matrice: MatriceDeGris
    private let cote: Double

    /// Prepare la lecture d une image rendue sur un carre de `cote` unites.
    init?(_ image: CGImage, cote: Double) {
        guard let matrice = MatriceDeGris(image), cote > 0 else { return nil }

        self.matrice = matrice
        self.cote = cote
    }

    /// Ton lu au point donne du document, de 0 pour le noir a 255 pour le blanc.
    func ton(abscisse: Double, ordonnee: Double) -> Double {
        let largeur = Double(matrice.largeur)
        let hauteur = Double(matrice.hauteur)
        let colonne = min(matrice.largeur - 1, max(0, Int(abscisse / cote * largeur)))
        let ligne = min(matrice.hauteur - 1, max(0, Int(ordonnee / cote * hauteur)))

        return Double(matrice.valeur(colonne: colonne, ligne: ligne))
    }

    /// Vrai quand le point est peint en noir.
    func estNoir(abscisse: Double, ordonnee: Double) -> Bool {
        ton(abscisse: abscisse, ordonnee: ordonnee) < 64
    }

    /// Vrai quand le point est peint en blanc.
    func estBlanc(abscisse: Double, ordonnee: Double) -> Bool {
        ton(abscisse: abscisse, ordonnee: ordonnee) > 191
    }
}
