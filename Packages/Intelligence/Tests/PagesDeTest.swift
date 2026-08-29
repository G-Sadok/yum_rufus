import Core
import Foundation
import ImagePipeline
@testable import Intelligence

//
// PagesDeTest
//
// Matrices de pixels aux motifs choisis, sur lesquelles la surelevation est
// mesuree.
//
// Les motifs ne sont pas decoratifs. Les rayures a fort contraste imitent le
// trait encre d une planche, qui est exactement ce qui fait extrapoler un
// reseau de convolution au bord de son entree : c est sur elles qu un raccord
// mal recompose se voit. Le degrade sert aux mesures de continuite, ou une
// variation lente rend visible toute marche ajoutee par la recomposition.
//

enum PagesDeTest {
    /// Rayures verticales a fort contraste, comme un trait encre.
    static func rayures(largeur: Int, hauteur: Int, periode: Int = 8) -> MatriceDePixels? {
        motif(largeur: largeur, hauteur: hauteur) { colonne, _ in
            (colonne / max(1, periode)) % 2 == 0 ? 255 : 0
        }
    }

    /// Degrade horizontal, du noir au blanc.
    static func degrade(largeur: Int, hauteur: Int) -> MatriceDePixels? {
        motif(largeur: largeur, hauteur: hauteur) { colonne, _ in
            UInt8(min(255, colonne * 255 / max(1, largeur - 1)))
        }
    }

    /// Damier fin, qui varie dans les deux directions.
    static func damier(largeur: Int, hauteur: Int, cote: Int = 6) -> MatriceDePixels? {
        motif(largeur: largeur, hauteur: hauteur) { colonne, ligne in
            (colonne / max(1, cote) + ligne / max(1, cote)) % 2 == 0 ? 240 : 16
        }
    }

    /// Page decodee portant ce motif, telle que la chaine d images la rend.
    static func decodee(largeur: Int, hauteur: Int) -> ImageDePage? {
        guard let matrice = damier(largeur: largeur, hauteur: hauteur),
              let image = matrice.image
        else {
            return nil
        }

        let taille = TailleEnPixels(largeur: largeur, hauteur: hauteur)

        return ImageDePage(
            image: image,
            tailleDOrigine: taille,
            tailleDecodee: taille,
            niveau: .affichage
        )
    }

    /// Matrice batie pixel par pixel, les trois canaux portant la meme valeur
    /// decalee, pour qu une permutation de canaux ne passe pas inapercue.
    static func motif(
        largeur: Int,
        hauteur: Int,
        valeur: (Int, Int) -> UInt8
    ) -> MatriceDePixels? {
        let parPixel = MatriceDePixels.octetsParPixel
        var octets = [UInt8](repeating: 0, count: largeur * hauteur * parPixel)

        for ligne in 0..<hauteur {
            for colonne in 0..<largeur {
                let depart = (ligne * largeur + colonne) * parPixel
                let ton = Int(valeur(colonne, ligne))

                octets[depart] = UInt8(min(255, ton))
                octets[depart + 1] = UInt8(min(255, max(0, ton - 4)))
                octets[depart + 2] = UInt8(min(255, max(0, ton - 8)))
                octets[depart + 3] = 255
            }
        }

        return MatriceDePixels(largeur: largeur, hauteur: hauteur, octets: octets)
    }
}

//
// EcartsDePixels
//
// Mesures de comparaison entre deux matrices de meme taille.
//

enum EcartsDePixels {
    /// Plus grand ecart entre deux matrices, canal par canal.
    ///
    /// Rend nil quand les tailles different, ce qui est une erreur de test et
    /// non un ecart de zero.
    static func maximum(_ premiere: MatriceDePixels, _ seconde: MatriceDePixels) -> Int? {
        guard premiere.taille == seconde.taille else { return nil }

        var maximum = 0

        for indice in 0..<premiere.octets.count where indice % MatriceDePixels.octetsParPixel != 3 {
            let ecart = abs(Int(premiere.octets[indice]) - Int(seconde.octets[indice]))

            maximum = max(maximum, ecart)
        }

        return maximum
    }

    /// Plus grand ecart mesure dans une bande de colonnes.
    static func maximum(
        _ premiere: MatriceDePixels,
        _ seconde: MatriceDePixels,
        colonnes: Range<Int>
    ) -> Int? {
        guard premiere.taille == seconde.taille else { return nil }

        var maximum = 0

        for ligne in 0..<premiere.hauteur {
            for colonne in colonnes where colonne >= 0 && colonne < premiere.largeur {
                for canal in 0..<3 {
                    let ecart = abs(
                        Int(premiere.canal(canal, colonne: colonne, ligne: ligne))
                            - Int(seconde.canal(canal, colonne: colonne, ligne: ligne))
                    )

                    maximum = max(maximum, ecart)
                }
            }
        }

        return maximum
    }
}
