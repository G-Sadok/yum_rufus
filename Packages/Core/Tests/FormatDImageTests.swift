import Core
import Foundation
import Testing

//
// Couvre la reconnaissance des formats de la section 5.2 et le lien entre le
// catalogue et le filtrage des entrees d une archive.
//
// Le point qui compte est la primaute des octets sur le nom. Les archives de
// scans reelles portent des pages dont l extension ment, et une reconnaissance
// fondee sur le nom enverrait un document SVG au decodeur binaire ou nommerait
// le mauvais format dans un message d erreur.
//

struct FormatDImageTests {
    // MARK: Signatures

    @Test("Chaque signature designe son format")
    func signatures() {
        #expect(FormatDImage.depuis(octets: Self.jpeg) == .jpeg)
        #expect(FormatDImage.depuis(octets: Self.png) == .png)
        #expect(FormatDImage.depuis(octets: Self.gif) == .gif)
        #expect(FormatDImage.depuis(octets: Self.bmp) == .bmp)
        #expect(FormatDImage.depuis(octets: Self.tiffPetitBout) == .tiff)
        #expect(FormatDImage.depuis(octets: Self.tiffGrosBout) == .tiff)
        #expect(FormatDImage.depuis(octets: Self.webp) == .webp)
        #expect(FormatDImage.depuis(octets: Self.avif) == .avif)
        #expect(FormatDImage.depuis(octets: Self.heic) == .heic)
    }

    @Test("Les deux formes de JPEG XL et de JPEG 2000 se distinguent")
    func conteneursEtFluxNus() {
        // Les deux conteneurs commencent par les memes quatre octets. Seule la
        // marque qui suit les separe, et les confondre enverrait un JPEG XL au
        // decodeur JPEG 2000.
        #expect(FormatDImage.depuis(octets: Self.jpegXLNu) == .jpegXL)
        #expect(FormatDImage.depuis(octets: Self.jpegXLConteneur) == .jpegXL)
        #expect(FormatDImage.depuis(octets: Self.jpeg2000Nu) == .jpeg2000)
        #expect(FormatDImage.depuis(octets: Self.jpeg2000Conteneur) == .jpeg2000)
    }

    @Test("Un PNG porteur d un bloc d animation est annonce APNG")
    func apngDistingueDuPng() {
        #expect(FormatDImage.depuis(octets: Self.png) == .png)
        #expect(FormatDImage.depuis(octets: Self.apng) == .apng)
    }

    @Test("Les quatre lettres acTL dans les pixels ne font pas un APNG")
    func acTlDansLesPixels() {
        // Le balayage suit la chaine des blocs et s arrete au premier IDAT. Une
        // recherche naive des quatre lettres n importe ou dans le fichier
        // annoncerait ici une animation qui n existe pas.
        #expect(FormatDImage.depuis(octets: Self.pngAvecAcTlDansLesDonnees) == .png)
    }

    @Test("Un document SVG est reconnu, avec ou sans declaration XML")
    func documentsSvg() {
        #expect(FormatDImage.depuis(octets: Self.octets("<svg xmlns=\"x\"><rect/></svg>")) == .svg)
        #expect(FormatDImage.depuis(octets: Self.octets("<?xml version=\"1.0\"?><svg/>")) == .svg)
        #expect(FormatDImage.depuis(octets: Self.octets("<!-- note --><svg/>")) == .svg)
    }

    @Test("Un document qui n est pas du SVG a la racine est refuse")
    func svgImbrique() {
        #expect(FormatDImage.depuis(octets: Self.octets("<html><body><svg/></body></html>")) == nil)
    }

    @Test("Des octets vides ou quelconques ne designent aucun format")
    func aucunFormat() {
        #expect(FormatDImage.depuis(octets: Data()) == nil)
        #expect(FormatDImage.depuis(octets: Self.octets("ceci est du texte ordinaire")) == nil)
    }

    // MARK: Octets contre extension

    @Test("Les octets priment sur une extension qui ment")
    func octetsAvantExtension() {
        #expect(FormatDImage.depuis(octets: Self.webp, nom: "page.jpg") == .webp)
    }

    @Test("L extension ne sert que lorsque les octets ne disent rien")
    func extensionEnSecours() {
        let inconnus = Self.octets("des octets sans signature")

        #expect(FormatDImage.depuis(octets: inconnus, nom: "page.heic") == .heic)
        #expect(FormatDImage.depuis(octets: inconnus, nom: "page.inconnu") == nil)
    }

    @Test("Chaque extension du catalogue designe un format, sans doublon")
    func extensionsSansDoublon() {
        var vues: Set<String> = []

        for format in FormatDImage.allCases {
            for extensionDeFichier in format.extensions {
                #expect(vues.contains(extensionDeFichier) == false, "extension en double : \(extensionDeFichier)")
                vues.insert(extensionDeFichier)
                #expect(FormatDImage.depuisExtension(de: "page." + extensionDeFichier) == format)
            }
        }

        #expect(vues == FormatDImage.toutesLesExtensions)
    }

    @Test("L extension se lit sans se laisser prendre par un dossier")
    func extensionDUnChemin() {
        #expect(FormatDImage.depuisExtension(de: "dossier.png/page.webp") == .webp)
        #expect(FormatDImage.depuisExtension(de: "PAGE.WEBP") == .webp)
        #expect(FormatDImage.depuisExtension(de: "page") == nil)
        #expect(FormatDImage.depuisExtension(de: ".webp") == nil)
    }

    // MARK: Catalogue

    @Test("Le filtrage des entrees d archive suit le catalogue des formats")
    func filtrageAligneSurLeCatalogue() {
        // Deux listes d extensions finiraient par diverger, et une page d un
        // format ajoute au catalogue serait alors ecartee sans bruit.
        #expect(EntreesDArchive.extensionsImage == FormatDImage.toutesLesExtensions)

        for format in FormatDImage.allCases {
            for extensionDeFichier in format.extensions {
                #expect(EntreesDArchive.estImage("page." + extensionDeFichier))
            }
        }
    }

    @Test("Chaque format porte un nom affichable et un identifiant de type")
    func nomsEtIdentifiants() {
        for format in FormatDImage.allCases {
            #expect(format.nomAffiche.isEmpty == false)
            #expect(format.identifiantDeType.isEmpty == false)
            #expect(format.extensions.isEmpty == false)
        }

        #expect(FormatDImage.jpegXL.nomAffiche == "JPEG XL")
        #expect(FormatDImage.webp.nomAffiche == "WebP")
        // APNG voyage dans un conteneur PNG, les deux partagent donc leur type.
        #expect(FormatDImage.apng.identifiantDeType == FormatDImage.png.identifiantDeType)
    }

    @Test("SVG est le seul format vectoriel du catalogue")
    func seulFormatVectoriel() {
        #expect(FormatDImage.allCases.filter(\.estVectoriel) == [.svg])
    }

    // MARK: Octets de reference

    private static func octets(_ texte: String) -> Data {
        Data(texte.utf8)
    }

    private static func octets(_ valeurs: [UInt8]) -> Data {
        Data(valeurs)
    }

    private static let jpeg = octets([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10])
    private static let gif = octets(Array("GIF89a".utf8))
    private static let bmp = octets(Array("BM".utf8) + [0x00, 0x00, 0x00, 0x00])
    private static let tiffPetitBout = octets([0x49, 0x49, 0x2A, 0x00])
    private static let tiffGrosBout = octets([0x4D, 0x4D, 0x00, 0x2A])
    private static let webp = octets(Array("RIFF".utf8) + [0x24, 0, 0, 0] + Array("WEBPVP8 ".utf8))
    private static let avif = octets([0, 0, 0, 0x20] + Array("ftypavif".utf8))
    private static let heic = octets([0, 0, 0, 0x18] + Array("ftypheic".utf8))
    private static let jpegXLNu = octets([0xFF, 0x0A, 0x00, 0x00])
    private static let jpegXLConteneur = octets(
        [0x00, 0x00, 0x00, 0x0C] + Array("JXL ".utf8) + [0x0D, 0x0A, 0x87, 0x0A]
    )
    private static let jpeg2000Nu = octets([0xFF, 0x4F, 0xFF, 0x51])
    private static let jpeg2000Conteneur = octets(
        [0x00, 0x00, 0x00, 0x0C] + Array("jP  ".utf8) + [0x0D, 0x0A, 0x87, 0x0A]
    )

    private static let signaturePng: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

    /// Bloc PNG complet : longueur, type, contenu, somme de controle.
    ///
    /// La somme n est pas calculee, la reconnaissance ne la lit pas. Ce sont les
    /// longueurs qui comptent, parce que c est elles qui font avancer le
    /// balayage d un bloc au suivant.
    private static func blocPng(_ type: String, _ contenu: [UInt8]) -> [UInt8] {
        let longueur = UInt32(contenu.count)
        let entete: [UInt8] = [
            UInt8((longueur >> 24) & 0xFF),
            UInt8((longueur >> 16) & 0xFF),
            UInt8((longueur >> 8) & 0xFF),
            UInt8(longueur & 0xFF),
        ]

        return entete + Array(type.utf8) + contenu + [0, 0, 0, 0]
    }

    private static let png = octets(
        signaturePng + blocPng("IHDR", Array(repeating: 0, count: 13)) + blocPng("IDAT", [0x78, 0x9C])
    )

    private static let apng = octets(
        signaturePng
            + blocPng("IHDR", Array(repeating: 0, count: 13))
            + blocPng("acTL", Array(repeating: 0, count: 8))
            + blocPng("IDAT", [0x78, 0x9C])
    )

    private static let pngAvecAcTlDansLesDonnees = octets(
        signaturePng
            + blocPng("IHDR", Array(repeating: 0, count: 13))
            + blocPng("IDAT", Array("acTL".utf8))
    )
}
