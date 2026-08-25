import Foundation

//
// FormatDImage
//
// Catalogue des formats image de la section 5.2 du cahier de developpement, et
// reconnaissance d un format a partir des octets.
//
// Le catalogue vit dans Core parce que trois couches en ont besoin sans se
// connaitre : Archive et Sources pour retenir les entrees affichables,
// ImagePipeline pour choisir le decodeur, et la couche vue pour nommer le
// format dans une page de remplacement.
//
// La reconnaissance porte d abord sur les octets, l extension ne servant qu en
// secours. Une archive de scans porte regulierement des pages WebP nommees
// `.jpg` par l outil qui les a produites : se fier au nom conduirait a nommer
// le mauvais format dans le message d erreur, et surtout a envoyer un SVG au
// decodeur binaire, ou l inverse.
//

/// Un des formats image que le lecteur sait ouvrir, section 5.2.
public enum FormatDImage: String, Sendable, Hashable, CaseIterable {
    case jpeg
    case png
    case apng
    case gif
    case bmp
    case tiff
    case webp
    case avif
    case heic
    case jpeg2000
    case jpegXL
    case svg

    /// Nom du format tel qu il apparait dans un message destine a l utilisateur.
    public var nomAffiche: String {
        switch self {
        case .jpeg: "JPEG"
        case .png: "PNG"
        case .apng: "APNG"
        case .gif: "GIF"
        case .bmp: "BMP"
        case .tiff: "TIFF"
        case .webp: "WebP"
        case .avif: "AVIF"
        case .heic: "HEIC"
        case .jpeg2000: "JPEG 2000"
        case .jpegXL: "JPEG XL"
        case .svg: "SVG"
        }
    }

    /// Extensions de fichier rencontrees pour ce format, toutes en minuscules.
    public var extensions: [String] {
        switch self {
        case .jpeg: ["jpg", "jpeg", "jpe", "jfif"]
        case .png: ["png"]
        case .apng: ["apng"]
        case .gif: ["gif"]
        case .bmp: ["bmp"]
        case .tiff: ["tif", "tiff"]
        case .webp: ["webp"]
        case .avif: ["avif", "avifs"]
        case .heic: ["heic", "heif", "heics"]
        case .jpeg2000: ["jp2", "j2k", "jpf", "jpx", "jpm"]
        case .jpegXL: ["jxl"]
        case .svg: ["svg"]
        }
    }

    /// Identifiant de type uniforme du format.
    ///
    /// C est la cle qui permet de confronter le catalogue a la liste des types
    /// que le systeme declare savoir lire. APNG partage l identifiant de PNG :
    /// le conteneur est le meme, seules les extensions d animation different.
    public var identifiantDeType: String {
        switch self {
        case .jpeg: "public.jpeg"
        case .png, .apng: "public.png"
        case .gif: "com.compuserve.gif"
        case .bmp: "com.microsoft.bmp"
        case .tiff: "public.tiff"
        case .webp: "org.webmproject.webp"
        case .avif: "public.avif"
        case .heic: "public.heic"
        case .jpeg2000: "public.jpeg-2000"
        case .jpegXL: "public.jpeg-xl"
        case .svg: "public.svg-image"
        }
    }

    /// Vrai quand le fichier peut porter plusieurs images.
    ///
    /// Le lecteur n affiche jamais qu une page. La premiere image du fichier est
    /// donc la seule lue, et l animation est ignoree plutot que refusee.
    public var estAnime: Bool {
        switch self {
        case .apng, .gif: true
        default: false
        }
    }

    /// Vrai quand le format decrit des formes et non une matrice de pixels.
    ///
    /// Un format vectoriel n a pas de taille propre, il se rasterise a la taille
    /// demandee. Il echappe donc au sous echantillonnage, qui n a pas de sens
    /// pour lui, sans echapper au budget memoire, qui en a un.
    public var estVectoriel: Bool {
        self == .svg
    }

    /// Toutes les extensions du catalogue, en minuscules.
    public static let toutesLesExtensions: Set<String> = Set(
        allCases.flatMap(\.extensions)
    )

    /// Format devine a partir de la seule extension d un chemin.
    ///
    /// Reponse de dernier recours : l extension est une promesse, pas une
    /// preuve. `depuis(octets:nom:)` la confronte au contenu.
    public static func depuisExtension(de chemin: String) -> FormatDImage? {
        let extensionDeFichier = extensionMinuscule(de: chemin)

        guard extensionDeFichier.isEmpty == false else { return nil }

        return allCases.first { $0.extensions.contains(extensionDeFichier) }
    }

    /// Format reconnu aux octets d en tete, sans rien decoder.
    ///
    /// Rend nil quand aucune signature connue ne colle, ce qui inclut le cas
    /// d un fichier vide et celui d un fichier de texte.
    public static func depuis(octets: Data) -> FormatDImage? {
        Signature.reconnaitre(octets)
    }

    /// Format d une entree, les octets primant sur son nom.
    ///
    /// L extension ne tranche que ce que les octets ne distinguent pas, et le
    /// seul cas est APNG, dont le conteneur est un PNG ordinaire. Un fichier
    /// nomme `.png` qui porte un bloc d animation reste donc annonce APNG,
    /// parce que c est le contenu qui compte.
    public static func depuis(octets: Data, nom: String) -> FormatDImage? {
        guard let auContenu = depuis(octets: octets) else {
            return depuisExtension(de: nom)
        }

        return auContenu
    }

    /// Extension d un chemin, en minuscules, vide quand il n en porte pas.
    private static func extensionMinuscule(de chemin: String) -> String {
        let nom = chemin
            .split(whereSeparator: { $0 == "/" || $0 == "\\" })
            .last
            .map(String.init) ?? chemin

        guard let point = nom.lastIndex(of: "."), point != nom.startIndex else {
            return ""
        }

        return String(nom[nom.index(after: point)...]).lowercased()
    }
}

///
/// Signatures
///
/// Chaque format se reconnait a une suite d octets placee en tete, sauf trois
/// cas qui demandent un peu plus de lecture.
///
/// AVIF et HEIC partagent le conteneur ISO base media : le type se lit dans la
/// marque de la boite `ftyp`, quatre octets plus loin.
///
/// APNG est un PNG qui porte un bloc `acTL` avant son premier bloc `IDAT`. Le
/// distinguer coute donc un balayage des blocs, borne au debut du fichier.
///
/// SVG est du texte. Aucune signature ne le designe, on cherche la balise
/// racine dans les premiers octets, en sautant la declaration XML, la
/// declaration de type et les commentaires.
///
private enum Signature {
    static func reconnaitre(_ octets: Data) -> FormatDImage? {
        historiques(octets) ?? recents(octets) ?? conteneurs(octets)
    }

    /// Les cinq formats que tout decodeur lit depuis toujours.
    private static func historiques(_ octets: Data) -> FormatDImage? {
        if commence(octets, par: [0xFF, 0xD8, 0xFF]) {
            return .jpeg
        }
        if commence(octets, par: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) {
            return porteUnBlocDAnimation(octets) ? .apng : .png
        }
        if commence(octets, par: Array("GIF8".utf8)) {
            return .gif
        }
        if commence(octets, par: Array("BM".utf8)) {
            return .bmp
        }
        if commence(octets, par: [0x49, 0x49, 0x2A, 0x00]) {
            return .tiff
        }
        if commence(octets, par: [0x4D, 0x4D, 0x00, 0x2A]) {
            return .tiff
        }

        return nil
    }

    /// WebP, JPEG XL et JPEG 2000, chacun sous ses deux formes.
    ///
    /// JPEG XL et JPEG 2000 existent en flux nu et en conteneur, et les deux
    /// conteneurs partagent les quatre premiers octets. Seule la marque qui
    /// suit les distingue.
    private static func recents(_ octets: Data) -> FormatDImage? {
        if commence(octets, par: Array("RIFF".utf8)), bloc(octets, a: 8) == "WEBP" {
            return .webp
        }
        if commence(octets, par: [0xFF, 0x0A]) {
            return .jpegXL
        }
        if commence(octets, par: [0xFF, 0x4F, 0xFF, 0x51]) {
            return .jpeg2000
        }

        guard commence(octets, par: [0x00, 0x00, 0x00, 0x0C]) else { return nil }

        switch bloc(octets, a: 4) {
        case "JXL ": return .jpegXL
        case "jP  ": return .jpeg2000
        default: return nil
        }
    }

    /// Conteneur ISO base media, et document texte.
    private static func conteneurs(_ octets: Data) -> FormatDImage? {
        if bloc(octets, a: 4) == "ftyp", let marque = bloc(octets, a: 8) {
            if marquesAvif.contains(marque) {
                return .avif
            }
            if marquesHeic.contains(marque) {
                return .heic
            }
        }

        return ressembleADuSvg(octets) ? .svg : nil
    }

    private static let marquesAvif: Set<String> = ["avif", "avis", "av01"]
    private static let marquesHeic: Set<String> = [
        "heic", "heix", "heim", "heis", "hevc", "hevx", "mif1", "msf1",
    ]

    /// Nombre d octets lus au plus pour trouver la racine d un document SVG.
    ///
    /// Assez pour franchir une declaration XML, une declaration de type et un
    /// commentaire d editeur, trop peu pour que le cout compte sur une page qui
    /// n est pas du texte.
    private static let fenetreDeTexte = 1024

    static func commence(_ octets: Data, par signature: [UInt8]) -> Bool {
        guard octets.count >= signature.count else { return false }

        for (rang, attendu) in signature.enumerated() where octets[octets.startIndex + rang] != attendu {
            return false
        }

        return true
    }

    /// Quatre octets lus comme du texte a une position donnee.
    static func bloc(_ octets: Data, a position: Int) -> String? {
        guard octets.count >= position + 4 else { return nil }

        let depart = octets.index(octets.startIndex, offsetBy: position)
        let fin = octets.index(depart, offsetBy: 4)

        return String(bytes: octets[depart..<fin], encoding: .ascii)
    }

    /// Vrai quand un PNG porte un bloc `acTL`, donc quand c est un APNG.
    ///
    /// Le balayage suit la chaine des blocs plutot que de chercher les quatre
    /// lettres n importe ou : une image ordinaire peut tres bien contenir cette
    /// suite d octets dans ses pixels compresses. Il s arrete au premier `IDAT`,
    /// la specification imposant que `acTL` le precede.
    static func porteUnBlocDAnimation(_ octets: Data) -> Bool {
        var position = 8

        while position + 8 <= octets.count {
            guard let type = bloc(octets, a: position + 4) else { return false }

            if type == "acTL" {
                return true
            }
            if type == "IDAT" {
                return false
            }

            let depart = octets.index(octets.startIndex, offsetBy: position)
            var longueur = 0
            for decalage in 0..<4 {
                longueur = longueur << 8 | Int(octets[octets.index(depart, offsetBy: decalage)])
            }

            guard longueur >= 0, longueur < octets.count else { return false }

            position += longueur + 12
        }

        return false
    }

    /// Vrai quand les premiers octets forment un document SVG.
    static func ressembleADuSvg(_ octets: Data) -> Bool {
        let fin = octets.index(
            octets.startIndex,
            offsetBy: min(fenetreDeTexte, octets.count)
        )
        // La fenetre coupe au nombre d octets, pas au caractere. Un point de
        // code multioctet tranche en deux rendrait la conversion nulle, et un
        // document dont l en tete porte un accent cesserait d etre reconnu.
        // La lecture en Latin 1 ne peut pas echouer et suffit ici : la balise
        // cherchee est en ASCII pur.
        guard let tete = String(data: octets[octets.startIndex..<fin], encoding: .isoLatin1),
              tete.contains("<svg")
        else {
            return false
        }

        // Un document HTML peut porter un `<svg` en plein corps, et il n est pas
        // un fichier SVG pour autant. Seule la balise racine tranche, donc on
        // franchit ce qui peut legalement la preceder, puis on regarde ce qui
        // vient. Chercher la balise n importe ou reconnaitrait une page web.
        return premiereBalise(de: tete)?.hasPrefix("<svg") == true
    }

    /// Premiere vraie balise du document, declarations et commentaires franchis.
    static func premiereBalise(de tete: String) -> Substring? {
        var reste = Substring(tete).drop(while: \.isWhitespace)

        while reste.hasPrefix("<") {
            guard let terminateur = terminateurDePreambule(reste) else {
                return reste
            }
            guard let fin = reste.range(of: terminateur) else {
                return nil
            }

            reste = reste[fin.upperBound...].drop(while: \.isWhitespace)
        }

        return reste.isEmpty ? nil : reste
    }

    /// Fin de la construction qui ouvre `reste`, nil quand c est deja une balise.
    private static func terminateurDePreambule(_ reste: Substring) -> String? {
        if reste.hasPrefix("<?") {
            return "?>"
        }
        if reste.hasPrefix("<!--") {
            return "-->"
        }
        if reste.hasPrefix("<!") {
            return ">"
        }

        return nil
    }
}
