import Core
import CoreGraphics
import Foundation
import ImageIO

//
// DecodeurDePage
//
// Decodage sous echantillonne d une page, via Image I/O.
//
// Le decodeur lit d abord les seules proprietes du fichier, qui donnent les
// dimensions sans rien decoder, puis demande une image bornee au cote utile.
// A aucun moment la page n existe en pleine resolution en memoire.
//
// La fonctionnalite F010 posera par dessus le budget memoire mesure, le cache
// et la pleine resolution du zoom actif. Ce fichier ne porte que le decodage
// lui meme, dont le lecteur en page simple a besoin des maintenant.
//

/// Echec du decodage d une page.
public enum ErreurDeDecodage: Error, Sendable, Equatable {
    /// Les octets ne forment aucune image que le systeme sache lire.
    case formatInconnu(nom: String)

    /// L image existe mais n annonce pas ses dimensions.
    case dimensionsIllisibles(nom: String)

    /// Les dimensions sont lisibles mais le decodage lui meme a echoue.
    case decodageImpossible(nom: String)

    /// Message destine a l utilisateur.
    ///
    /// Il nomme la page en cause. La sortie proposee appartient a l ecran, qui
    /// sait seul si un chapitre suivant existe.
    public var messageUtilisateur: String {
        switch self {
        case let .formatInconnu(nom):
            "Le fichier \(nom) n est pas une image que Yum sache ouvrir."
        case let .dimensionsIllisibles(nom):
            "Le fichier \(nom) n annonce pas ses dimensions."
        case let .decodageImpossible(nom):
            "Le fichier \(nom) est une image, mais son contenu est illisible."
        }
    }
}

/// Une page decodee, prete a etre posee dans une vue.
///
/// `CGImage` est immuable une fois construite, et le decodeur ne garde aucune
/// reference sur elle. La franchir d un domaine de concurrence a l autre est
/// donc sur, ce que le marqueur non verifie declare.
public struct ImageDePage: @unchecked Sendable {
    /// Image decodee.
    public let image: CGImage

    /// Dimensions annoncees par le fichier, avant sous echantillonnage.
    public let tailleDOrigine: TailleEnPixels

    /// Dimensions reellement decodees.
    public let tailleDecodee: TailleEnPixels

    public init(image: CGImage, tailleDOrigine: TailleEnPixels, tailleDecodee: TailleEnPixels) {
        self.image = image
        self.tailleDOrigine = tailleDOrigine
        self.tailleDecodee = tailleDecodee
    }

    /// Octets occupes par l image decodee, en RGBA.
    public var octetsEnMemoire: Int {
        tailleDecodee.octetsUneFoisDecodee
    }
}

/// Decodeur d une page vers la taille a laquelle elle sera affichee.
public struct DecodeurDePage: Sendable {
    public init() {}

    /// Decode une page, bornee a ce que la zone d affichage peut montrer.
    ///
    /// - Parameters:
    ///   - donnees: octets bruts de la page, dans le format du fichier.
    ///   - nom: nom de l entree, repris dans les erreurs.
    ///   - zone: zone d affichage en pixels reels.
    /// - Throws: `ErreurDeDecodage` quand le fichier n est pas une image
    ///   lisible.
    public func decoder(_ donnees: Data, nom: String, dans zone: TailleEnPixels) throws -> ImageDePage {
        guard let source = CGImageSourceCreateWithData(donnees as CFData, nil),
              CGImageSourceGetCount(source) > 0
        else {
            throw ErreurDeDecodage.formatInconnu(nom: nom)
        }

        let tailleDOrigine = try Self.dimensions(de: source, nom: nom)
        let cote = AjustementDePage.coteMaximalADecoder(page: tailleDOrigine, dans: zone)

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: cote,
        ]

        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw ErreurDeDecodage.decodageImpossible(nom: nom)
        }

        return ImageDePage(
            image: image,
            tailleDOrigine: tailleDOrigine,
            tailleDecodee: TailleEnPixels(largeur: image.width, hauteur: image.height)
        )
    }

    /// Dimensions annoncees par l en tete du fichier, sans decodage.
    private static func dimensions(de source: CGImageSource, nom: String) throws -> TailleEnPixels {
        guard let proprietes = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let largeur = proprietes[kCGImagePropertyPixelWidth] as? Int,
              let hauteur = proprietes[kCGImagePropertyPixelHeight] as? Int,
              largeur > 0,
              hauteur > 0
        else {
            throw ErreurDeDecodage.dimensionsIllisibles(nom: nom)
        }

        return TailleEnPixels(largeur: largeur, hauteur: hauteur)
    }
}
