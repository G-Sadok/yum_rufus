import Core
import CoreGraphics

//
// MatriceDeGris
//
// Vue en niveaux de gris d une page decodee, sur laquelle le rognage mesure ses
// lignes et ses colonnes.
//
// La couleur n apporte rien a la detection d une marge et coute trois fois plus
// de lecture. La page est donc redessinee une fois en gris huit bits, puis
// mesuree sur cette matrice. C est ce passage qui coute, et c est pour lui que
// le resultat de l analyse est mis en cache.
//
// La ligne zero de la matrice est la ligne du haut de l image, comme dans le
// systeme de coordonnees de `CGImage`. Sans cette correspondance, une bordure
// haute serait rendue au rognage comme une bordure basse, et le decalage
// n apparaitrait que sur les pages a marges asymetriques.
//
// Un pixel transparent devient noir, parce que le contexte opaque part du noir.
// Une bordure transparente est donc traitee comme une bordure noire, ce qui est
// le comportement voulu : c est une marge dans les deux cas.
//

/// Matrice de niveaux de gris d une image, ligne zero en haut.
struct MatriceDeGris: Sendable {
    /// Moyenne et variance d une bande de pixels, en valeurs normalisees.
    struct Statistiques: Sendable, Hashable {
        let moyenne: Double
        let variance: Double
    }

    /// Nombre de colonnes.
    let largeur: Int

    /// Nombre de lignes.
    let hauteur: Int

    private let valeurs: [UInt8]

    /// Construit une matrice a partir de valeurs deja en gris.
    ///
    /// Rend nil quand les dimensions sont vides ou ne collent pas au compte.
    init?(largeur: Int, hauteur: Int, valeurs: [UInt8]) {
        guard largeur > 0, hauteur > 0, valeurs.count == largeur * hauteur else {
            return nil
        }

        self.largeur = largeur
        self.hauteur = hauteur
        self.valeurs = valeurs
    }

    /// Redessine une image en gris huit bits et en retient les pixels.
    ///
    /// Rend nil quand le systeme refuse la matrice, cas dans lequel l appelant
    /// renonce a rogner plutot que d abimer la page.
    init?(_ image: CGImage) {
        let largeur = image.width
        let hauteur = image.height

        guard largeur > 0,
              hauteur > 0,
              let contexte = CGContext(
                  data: nil,
                  width: largeur,
                  height: hauteur,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: CGColorSpaceCreateDeviceGray(),
                  bitmapInfo: CGImageAlphaInfo.none.rawValue
              )
        else {
            return nil
        }

        contexte.draw(image, in: CGRect(x: 0, y: 0, width: largeur, height: hauteur))

        guard let base = contexte.data else {
            return nil
        }

        let octetsParLigne = contexte.bytesPerRow
        let source = base.bindMemory(to: UInt8.self, capacity: octetsParLigne * hauteur)
        var valeurs = [UInt8](repeating: 0, count: largeur * hauteur)

        for ligne in 0..<hauteur {
            let departSource = ligne * octetsParLigne
            let departMatrice = ligne * largeur

            for colonne in 0..<largeur {
                valeurs[departMatrice + colonne] = source[departSource + colonne]
            }
        }

        self.init(largeur: largeur, hauteur: hauteur, valeurs: valeurs)
    }

    /// Dimensions de la matrice.
    var taille: TailleEnPixels {
        TailleEnPixels(largeur: largeur, hauteur: hauteur)
    }

    /// Valeur d un pixel, de zero pour le noir a 255 pour le blanc.
    func valeur(colonne: Int, ligne: Int) -> UInt8 {
        valeurs[ligne * largeur + colonne]
    }

    /// Statistiques d une portion de ligne.
    func statistiques(ligne: Int, colonnes: Range<Int>) -> Statistiques {
        let depart = ligne * largeur
        var somme = 0.0
        var sommeDesCarres = 0.0

        for colonne in colonnes {
            let valeur = Double(valeurs[depart + colonne]) / 255
            somme += valeur
            sommeDesCarres += valeur * valeur
        }

        return Self.statistiques(somme: somme, sommeDesCarres: sommeDesCarres, nombre: colonnes.count)
    }

    /// Statistiques d une portion de colonne.
    func statistiques(colonne: Int, lignes: Range<Int>) -> Statistiques {
        var somme = 0.0
        var sommeDesCarres = 0.0

        for ligne in lignes {
            let valeur = Double(valeurs[ligne * largeur + colonne]) / 255
            somme += valeur
            sommeDesCarres += valeur * valeur
        }

        return Self.statistiques(somme: somme, sommeDesCarres: sommeDesCarres, nombre: lignes.count)
    }

    /// Moyenne et variance d une bande, la variance ramenee a zero si le calcul
    /// la rend legerement negative par accumulation de flottants.
    private static func statistiques(somme: Double, sommeDesCarres: Double, nombre: Int) -> Statistiques {
        guard nombre > 0 else {
            return Statistiques(moyenne: 0, variance: 0)
        }

        let compte = Double(nombre)
        let moyenne = somme / compte

        return Statistiques(
            moyenne: moyenne,
            variance: max(0, sommeDesCarres / compte - moyenne * moyenne)
        )
    }
}
