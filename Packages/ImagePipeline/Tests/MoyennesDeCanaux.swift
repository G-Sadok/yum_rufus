import CoreGraphics

//
// MoyennesDeCanaux
//
// Moyenne de chaque canal d une image decodee, en valeurs normalisees.
//
// La matrice de gris du rognage ne suffit pas ici. La chaleur deplace le rouge
// et le bleu en sens contraire, et un gris moyen ne bougerait presque pas :
// mesure sur le seul gris, le curseur de chaleur paraitrait inerte alors qu il
// teinte toute la planche.
//

struct MoyennesDeCanaux {
    let rouge: Double
    let vert: Double
    let bleu: Double

    /// Moyenne par canal, ou nil quand le systeme refuse la matrice.
    init?(_ image: CGImage) {
        let largeur = image.width
        let hauteur = image.height
        let format = CGImageAlphaInfo.noneSkipLast.rawValue

        guard largeur > 0,
              hauteur > 0,
              let contexte = CGContext(
                  data: nil,
                  width: largeur,
                  height: hauteur,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: format
              )
        else {
            return nil
        }

        contexte.draw(image, in: CGRect(x: 0, y: 0, width: largeur, height: hauteur))

        guard let base = contexte.data else {
            return nil
        }

        let octetsParLigne = contexte.bytesPerRow
        let pixels = base.bindMemory(to: UInt8.self, capacity: octetsParLigne * hauteur)
        var sommes = (rouge: 0.0, vert: 0.0, bleu: 0.0)

        for ligne in 0..<hauteur {
            let depart = ligne * octetsParLigne

            for colonne in 0..<largeur {
                let pixel = depart + colonne * 4
                sommes.rouge += Double(pixels[pixel])
                sommes.vert += Double(pixels[pixel + 1])
                sommes.bleu += Double(pixels[pixel + 2])
            }
        }

        let nombre = Double(largeur * hauteur) * 255

        rouge = sommes.rouge / nombre
        vert = sommes.vert / nombre
        bleu = sommes.bleu / nombre
    }

    /// Moyenne des trois canaux, la luminosite percue en premiere approche.
    var moyenne: Double {
        (rouge + vert + bleu) / 3
    }
}
