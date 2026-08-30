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

    /// Planche en noir et blanc, comme un scan de manga.
    ///
    /// Les trois canaux portent strictement la meme valeur, ce qui est la
    /// definition operatoire du noir et blanc pour la colorisation : c est cette
    /// egalite qui doit disparaitre apres le traitement. Le motif melange du
    /// trait noir, des aplats gris et du blanc de page, les trois tons qu une
    /// planche encree porte reellement.
    static func noirEtBlanc(largeur: Int, hauteur: Int) -> MatriceDePixels? {
        gris(largeur: largeur, hauteur: hauteur) { colonne, ligne in
            if (colonne / 9 + ligne / 13) % 5 == 0 {
                return 0
            }

            return (colonne / 31 + ligne / 29) % 3 == 0 ? 128 : 255
        }
    }

    /// Page decodee portant ce motif, telle que la chaine d images la rend.
    static func decodee(largeur: Int, hauteur: Int) -> ImageDePage? {
        page(damier(largeur: largeur, hauteur: hauteur))
    }

    /// Page decodee en noir et blanc, telle que la chaine d images la rend.
    static func decodeeEnNoirEtBlanc(largeur: Int, hauteur: Int) -> ImageDePage? {
        page(noirEtBlanc(largeur: largeur, hauteur: hauteur))
    }

    /// Page decodee portant cette matrice.
    static func page(_ matrice: MatriceDePixels?) -> ImageDePage? {
        guard let matrice, let image = matrice.image else { return nil }

        return ImageDePage(
            image: image,
            tailleDOrigine: matrice.taille,
            tailleDecodee: matrice.taille,
            niveau: .affichage
        )
    }

    /// Matrice batie pixel par pixel, les trois canaux portant la meme valeur.
    static func gris(
        largeur: Int,
        hauteur: Int,
        valeur: (Int, Int) -> UInt8
    ) -> MatriceDePixels? {
        let parPixel = MatriceDePixels.octetsParPixel
        var octets = [UInt8](repeating: 0, count: largeur * hauteur * parPixel)

        for ligne in 0..<hauteur {
            for colonne in 0..<largeur {
                let depart = (ligne * largeur + colonne) * parPixel
                let ton = valeur(colonne, ligne)

                octets[depart] = ton
                octets[depart + 1] = ton
                octets[depart + 2] = ton
                octets[depart + 3] = 255
            }
        }

        return MatriceDePixels(largeur: largeur, hauteur: hauteur, octets: octets)
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
    /// Vrai quand chaque pixel porte la meme valeur sur ses trois canaux.
    ///
    /// C est la definition operatoire du noir et blanc retenue par les tests de
    /// colorisation. Elle sert des deux cotes : a prouver que la page d entree
    /// est bien en noir et blanc, et a prouver que celle de sortie ne l est plus.
    static func estEnNoirEtBlanc(_ matrice: MatriceDePixels) -> Bool {
        partDePixelsColores(matrice) == 0
    }

    /// Part des pixels dont les trois canaux ne sont pas tous egaux.
    static func partDePixelsColores(_ matrice: MatriceDePixels) -> Double {
        var colores = 0

        for ligne in 0..<matrice.hauteur {
            for colonne in 0..<matrice.largeur {
                let rouge = matrice.canal(0, colonne: colonne, ligne: ligne)
                let vert = matrice.canal(1, colonne: colonne, ligne: ligne)
                let bleu = matrice.canal(2, colonne: colonne, ligne: ligne)

                if rouge != vert || vert != bleu {
                    colores += 1
                }
            }
        }

        return Double(colores) / Double(max(1, matrice.largeur * matrice.hauteur))
    }

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
