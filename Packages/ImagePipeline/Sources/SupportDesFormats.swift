import Core
import Foundation
import ImageIO

//
// SupportDesFormats
//
// Ce que cet appareil sait reellement lire, parmi les formats de la section 5.2.
//
// La liste n est pas ecrite dans le code. Elle est demandee a Image I/O au
// premier acces, puis retenue. Ecrire la liste a la main reviendrait a decider
// a la place du systeme : la prise en charge de WebP, d AVIF et de JPEG XL est
// arrivee au fil des versions de macOS et d iOS, et une liste figee refuserait
// sur un appareil recent un format qu il sait ouvrir, ou promettrait sur un
// appareil ancien un format qu il ne sait pas ouvrir.
//
// SVG est le seul format ajoute a la main, parce qu il ne vient pas
// d Image I/O : aucun systeme Apple ne declare `public.svg-image` en lecture,
// et c est `RasterisateurSvg` qui le rend, dans ce paquet.
//

/// Formats de la section 5.2 que cet appareil sait ouvrir.
public enum SupportDesFormats {
    /// Formats lisibles ici, calcules une fois.
    public static let lisibles: Set<FormatDImage> = calculer()

    /// Formats de la section 5.2 qu aucun decodeur ne prend en charge ici.
    ///
    /// Vide sur les systemes a jour. Non vide, c est la liste exacte des
    /// formats pour lesquels le lecteur affichera une page de remplacement.
    public static var absents: Set<FormatDImage> {
        Set(FormatDImage.allCases).subtracting(lisibles)
    }

    /// Indique si un format peut etre decode sur cet appareil.
    public static func estLisible(_ format: FormatDImage) -> Bool {
        lisibles.contains(format)
    }

    /// Formats declares par Image I/O, plus ceux que le paquet rend lui meme.
    private static func calculer() -> Set<FormatDImage> {
        let declares = Set((CGImageSourceCopyTypeIdentifiers() as? [String]) ?? [])

        var lisibles: Set<FormatDImage> = [.svg]

        for format in FormatDImage.allCases where declares.contains(format.identifiantDeType) {
            lisibles.insert(format)
        }

        return lisibles
    }
}
