import Core
import Foundation
@testable import ImagePipeline

//
// FichiersDeFormats
//
// Acces au jeu de fichiers de test des formats, section 5.2.
//
// Les fichiers sont suivis par git, pas fabriques par la suite. Deux d entre
// eux, WebP et JPEG XL, ne peuvent pas l etre : Image I/O les lit sans savoir
// les ecrire, sur toutes les versions de macOS et d iOS. Une suite qui
// encoderait ses propres fichiers ne couvrirait donc jamais ces deux formats,
// et le trou ne se verrait pas.
//
// `scripts/fabriquer-fichiers-de-formats.sh` les refabrique tous.
//
// Tous les fichiers de page portent la meme image : une rampe diagonale de 160
// par 240, noire en haut a gauche et blanche en bas a droite. Les quatre coins
// different assez pour qu un retournement ou une transposition fassent echouer
// le test, ce qu une mire symetrique ne ferait pas.
//

enum FichiersDeFormats {
    /// Largeur commune a tous les fichiers de page.
    static let largeur = 160

    /// Hauteur commune a tous les fichiers de page.
    static let hauteur = 240

    /// Taille commune a tous les fichiers de page.
    static var taille: TailleEnPixels {
        TailleEnPixels(largeur: largeur, hauteur: hauteur)
    }

    /// Un fichier de page par format de la section 5.2.
    static let pages: [(nom: String, format: FormatDImage)] = [
        ("page.jpg", .jpeg),
        ("page.png", .png),
        ("page.apng", .apng),
        ("page.gif", .gif),
        ("page.bmp", .bmp),
        ("page.tif", .tiff),
        ("page.webp", .webp),
        ("page.avif", .avif),
        ("page.heic", .heic),
        ("page.jp2", .jpeg2000),
        ("page.jxl", .jpegXL),
        ("page.svg", .svg),
    ]

    /// Octets d un fichier du jeu, nil quand il manque.
    static func octets(_ nom: String) -> Data? {
        guard let dossier = Bundle.module.resourceURL else { return nil }

        return try? Data(contentsOf: dossier.appending(path: "Fichiers").appending(path: nom))
    }
}
