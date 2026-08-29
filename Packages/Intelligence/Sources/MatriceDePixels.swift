import Core
import CoreGraphics
import Foundation

//
// MatriceDePixels
//
// Matrice de pixels en clair, sur laquelle la surelevation decoupe ses tuiles
// et recompose son resultat.
//
// La chaine d images travaille en `CGImage`, qui est le bon type pour afficher
// et pour decoder, et le mauvais pour lire un pixel. Une tuile de 256 doit etre
// extraite, passee au modele, puis fondue dans la sortie avec un poids par
// pixel. Faire cela en `CGImage` imposerait un contexte par operation, sans
// jamais donner acces aux valeurs. La matrice existe pour cette traversee, et
// pour elle seule : elle entre par une image et ressort en image.
//
// Quatre octets par pixel, lignes jointives, ligne zero en haut, comme dans le
// repere de `CGImage`. Le quatrieme octet n est jamais interprete : le contexte
// de lecture ignore la couche alpha, ce qui evite d avoir a demultiplier au
// retour et rend l aller retour exact. Une page transparente devient donc noire
// et opaque, comme pour la matrice de gris du rognage.
//
// Les octets sont copies, jamais partages. Une matrice est une valeur, deux
// tuiles extraites de la meme page ne peuvent pas se marcher dessus, et le
// modele ne recoit jamais de vue sur la page entiere.
//

/// Matrice de pixels RGBX huit bits, lignes jointives, ligne zero en haut.
public struct MatriceDePixels: Sendable, Equatable {
    /// Octets occupes par un pixel.
    public static let octetsParPixel = 4

    /// Nombre de colonnes.
    public let largeur: Int

    /// Nombre de lignes.
    public let hauteur: Int

    /// Pixels, ligne par ligne du haut vers le bas.
    public let octets: [UInt8]

    /// Construit une matrice a partir d octets deja en RGBX.
    ///
    /// Rend nil quand les dimensions sont vides ou ne collent pas au compte,
    /// plutot que de laisser une matrice mentir sur sa propre taille.
    public init?(largeur: Int, hauteur: Int, octets: [UInt8]) {
        guard largeur > 0,
              hauteur > 0,
              octets.count == largeur * hauteur * Self.octetsParPixel
        else {
            return nil
        }

        self.largeur = largeur
        self.hauteur = hauteur
        self.octets = octets
    }

    /// Redessine une image dans une matrice a elle.
    ///
    /// Rend nil quand le systeme refuse le contexte, cas dans lequel l appelant
    /// renonce a ameliorer plutot que d abimer la page.
    public init?(_ image: CGImage) {
        let largeur = image.width
        let hauteur = image.height

        guard largeur > 0,
              hauteur > 0,
              let contexte = CGContext(
                  data: nil,
                  width: largeur,
                  height: hauteur,
                  bitsPerComponent: 8,
                  bytesPerRow: largeur * Self.octetsParPixel,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              ),
              let base = contexte.data
        else {
            return nil
        }

        contexte.draw(image, in: CGRect(x: 0, y: 0, width: largeur, height: hauteur))

        let compte = largeur * hauteur * Self.octetsParPixel
        let source = base.bindMemory(to: UInt8.self, capacity: compte)

        self.init(
            largeur: largeur,
            hauteur: hauteur,
            octets: Array(UnsafeBufferPointer(start: source, count: compte))
        )
    }

    /// Dimensions de la matrice.
    public var taille: TailleEnPixels {
        TailleEnPixels(largeur: largeur, hauteur: hauteur)
    }

    /// Octets reellement occupes par les pixels.
    public var octetsEnMemoire: Int {
        octets.count
    }

    /// Image posable dans une vue, nil quand le systeme refuse la matrice.
    public var image: CGImage? {
        guard let fournisseur = CGDataProvider(data: Data(octets) as CFData) else {
            return nil
        }

        return CGImage(
            width: largeur,
            height: hauteur,
            bitsPerComponent: 8,
            bitsPerPixel: 8 * Self.octetsParPixel,
            bytesPerRow: largeur * Self.octetsParPixel,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            provider: fournisseur,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    /// Valeur d un canal en un point, de zero a 255.
    ///
    /// Les canaux sont ranges rouge, vert, bleu, puis l octet ignore.
    public func canal(_ canal: Int, colonne: Int, ligne: Int) -> UInt8 {
        octets[(ligne * largeur + colonne) * Self.octetsParPixel + canal]
    }

    /// Portion rectangulaire de la matrice, copiee dans une matrice a elle.
    ///
    /// - Returns: nil des que la portion demandee sort de la matrice. Une tuile
    ///   tronquee en silence donnerait une sortie decalee sans rien signaler.
    public func extraire(origineX: Int, origineY: Int, taille: TailleEnPixels) -> MatriceDePixels? {
        guard taille.estVide == false,
              origineX >= 0,
              origineY >= 0,
              origineX + taille.largeur <= largeur,
              origineY + taille.hauteur <= hauteur
        else {
            return nil
        }

        let parPixel = Self.octetsParPixel
        var extraits = [UInt8](repeating: 0, count: taille.largeur * taille.hauteur * parPixel)

        for ligne in 0..<taille.hauteur {
            let depart = ((origineY + ligne) * largeur + origineX) * parPixel
            let arrivee = ligne * taille.largeur * parPixel

            for octet in 0..<(taille.largeur * parPixel) {
                extraits[arrivee + octet] = octets[depart + octet]
            }
        }

        return MatriceDePixels(largeur: taille.largeur, hauteur: taille.hauteur, octets: extraits)
    }

    /// Matrice agrandie jusqu a ce cote minimal, par recopie du bord.
    ///
    /// Une page plus etroite qu une tuile ne peut pas etre tuilee : le modele
    /// attend une entree de taille fixe, et une entree plus petite le ferait
    /// echouer sur une planche parfaitement lisible. Le bord est donc repete
    /// jusqu au cote demande, la sortie est rognee ensuite, et le remplissage
    /// n apparait jamais dans le resultat.
    ///
    /// Repeter le bord plutot que remplir de noir : un bord noir ajoute au
    /// modele un contraste que la page ne porte pas, et ce faux contraste
    /// remonterait dans les pixels voisins que la sortie conserve.
    public func remplie(jusqua cote: Int) -> MatriceDePixels {
        let voulue = TailleEnPixels(largeur: max(largeur, cote), hauteur: max(hauteur, cote))

        guard voulue.largeur > largeur || voulue.hauteur > hauteur else {
            return self
        }

        let parPixel = Self.octetsParPixel
        var remplis = [UInt8](repeating: 0, count: voulue.largeur * voulue.hauteur * parPixel)

        for ligne in 0..<voulue.hauteur {
            let source = min(ligne, hauteur - 1)

            for colonne in 0..<voulue.largeur {
                let depart = (source * largeur + min(colonne, largeur - 1)) * parPixel
                let arrivee = (ligne * voulue.largeur + colonne) * parPixel

                for octet in 0..<parPixel {
                    remplis[arrivee + octet] = octets[depart + octet]
                }
            }
        }

        return MatriceDePixels(largeur: voulue.largeur, hauteur: voulue.hauteur, octets: remplis)
            ?? self
    }

    /// Coin superieur gauche de la matrice, aux dimensions demandees.
    ///
    /// Rend la matrice telle quelle quand elle est deja a la bonne taille, et
    /// nil quand les dimensions demandees la depassent.
    public func rognee(a taille: TailleEnPixels) -> MatriceDePixels? {
        guard taille != self.taille else { return self }

        return extraire(origineX: 0, origineY: 0, taille: taille)
    }
}
