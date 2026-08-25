import Core
import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers

//
// DocumentPdf
//
// Implementation de `DocumentLocal` pour les fichiers PDF, section 5.2.
//
// Ce lecteur vit dans ImagePipeline et non dans Archive, contrairement au ZIP et
// au TAR, parce qu une page de PDF n est pas un fichier image range dans un
// conteneur : c est une description a executer, et la seule facon d en tirer des
// pixels est de la rasteriser. Le conteneur et le decodeur sont donc le meme
// objet. Le ranger dans Archive obligerait soit a y dupliquer le calcul de
// taille cible et de budget memoire, soit a faire dependre Archive de la chaine
// d images, ce que la frontiere entre paquets interdit.
//
// PDFKit ouvre le document, compte ses pages et traite le mot de passe. Le rendu
// passe par la page Core Graphics sous jacente : `getDrawingTransform` place la
// page dans la matrice demandee en tenant compte de l origine de la boite media
// et de la rotation `/Rotate`, deux choses qu un placement fait a la main rate
// une fois sur deux, et toujours sur les fichiers produits par un scanner.
//
// La regle memoire de la section 6.1 vaut ici comme pour une page JPEG. Une page
// A4 rasterisee a 600 points par pouce pese 140 Mo. La taille de rendu est donc
// bornee deux fois : d abord par la zone d affichage, ensuite par le budget par
// page. Aucun appelant ne peut demander une pleine resolution par ce chemin.
//
// PDFDocument est une classe qui n est pas sure en acces concurrent. Elle est
// donc gardee par un verrou, et le marqueur `@unchecked Sendable` ne couvre que
// cela : toutes les lectures du document passent par ce verrou, aucune reference
// vers lui ne sort de ce fichier.
//

/// Un fichier PDF ouvert en lecture, chaque page rendue a la taille demandee.
public final class DocumentPdf: DocumentLocal, @unchecked Sendable {
    /// Extensions de fichier que ce lecteur prend en charge.
    public static let extensions: Set<String> = ["pdf"]

    /// Zone de rendu retenue quand l appelant n en impose pas.
    ///
    /// C est la taille en pixels reels d une page affichee plein ecran sur un
    /// ecran dense, celle que la suite de mesure de la chaine d images utilise
    /// deja comme reference. Ce n est pas une valeur de mise en page : elle ne
    /// decide d aucune apparence, seulement de la quantite de pixels produite.
    public static let zoneParDefaut = TailleEnPixels(largeur: 1600, hauteur: 2400)

    public let nombrePages: Int

    /// Vrai quand le fichier est protege, meme une fois le mot de passe accepte.
    public let estChiffre: Bool

    private let document: PDFDocument
    private let verrou = NSLock()
    private let chemin: String
    private let zoneDeRendu: TailleEnPixels
    private let budgetParDefaut: BudgetDeDecodage

    /// Ouvre le PDF range a l emplacement indique.
    ///
    /// - Parameters:
    ///   - url: emplacement du fichier.
    ///   - motDePasse: mot de passe saisi par l utilisateur, quand il en a saisi
    ///     un. Laisse a `nil` a la premiere tentative.
    ///   - zoneDeRendu: zone servant aux rendus qui n en precisent pas.
    ///   - budget: plafond memoire d une page rendue.
    /// - Throws: `ErreurDeDocument.fichierIntrouvable` si le fichier n existe
    ///   pas, `.conteneurIllisible` si ce n est pas un PDF, `.conteneurChiffre`
    ///   s il est protege et qu aucun mot de passe n est fourni,
    ///   `.motDePasseIncorrect` si celui fourni est refuse, `.aucunePage` si le
    ///   document ne porte aucune page.
    public convenience init(
        contenuDe url: URL,
        motDePasse: String? = nil,
        zoneDeRendu: TailleEnPixels = DocumentPdf.zoneParDefaut,
        budget: BudgetDeDecodage = .parDefaut
    ) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ErreurDeDocument.fichierIntrouvable(chemin: url.path)
        }

        guard let document = PDFDocument(url: url) else {
            throw ErreurDeDocument.conteneurIllisible(chemin: url.path)
        }

        try self.init(
            document: document,
            chemin: url.path,
            motDePasse: motDePasse,
            zoneDeRendu: zoneDeRendu,
            budget: budget
        )
    }

    /// Ouvre un PDF deja charge en memoire.
    public convenience init(
        donnees: Data,
        nom: String,
        motDePasse: String? = nil,
        zoneDeRendu: TailleEnPixels = DocumentPdf.zoneParDefaut,
        budget: BudgetDeDecodage = .parDefaut
    ) throws {
        guard let document = PDFDocument(data: donnees) else {
            throw ErreurDeDocument.conteneurIllisible(chemin: nom)
        }

        try self.init(
            document: document,
            chemin: nom,
            motDePasse: motDePasse,
            zoneDeRendu: zoneDeRendu,
            budget: budget
        )
    }

    private init(
        document: PDFDocument,
        chemin: String,
        motDePasse: String?,
        zoneDeRendu: TailleEnPixels,
        budget: BudgetDeDecodage
    ) throws {
        if document.isLocked {
            guard let motDePasse else {
                throw ErreurDeDocument.conteneurChiffre(chemin: chemin)
            }
            guard document.unlock(withPassword: motDePasse) else {
                throw ErreurDeDocument.motDePasseIncorrect(chemin: chemin)
            }
        }

        guard document.pageCount > 0 else {
            throw ErreurDeDocument.aucunePage(chemin: chemin)
        }

        self.document = document
        self.chemin = chemin
        self.zoneDeRendu = zoneDeRendu.estVide ? Self.zoneParDefaut : zoneDeRendu
        budgetParDefaut = budget
        nombrePages = document.pageCount
        estChiffre = document.isEncrypted
    }

    public func referencePage(_ index: Int) throws -> ReferencePage {
        guard index >= 0, index < nombrePages else {
            throw ErreurDeDocument.indexHorsBornes(demande: index, nombrePages: nombrePages)
        }

        return try ReferencePage(
            index: index,
            nom: Self.nom(dePage: index),
            tailleOctets: BudgetDeDecodage.octetsOccupes(par: tailleDeRendu(a: index))
        )
    }

    /// Rend la page dans le format PNG.
    ///
    /// Le PNG est un intermediaire, pas le chemin rapide. Il existe pour que les
    /// appelants qui traitent tous les conteneurs de la meme facon continuent de
    /// fonctionner sur un PDF. Le moteur de lecture, lui, appelle `rendre` et
    /// recoit la matrice directement, sans encoder puis redecoder.
    ///
    /// Le rendu reste borne par la zone et le budget du document, un PDF ne peut
    /// donc pas produire ici une image plus lourde qu une page d archive.
    public func donneesPage(_ reference: ReferencePage) throws -> Data {
        let rendue = try rendre(reference, dans: zoneDeRendu)

        guard let octets = Self.encoderEnPng(rendue.image) else {
            throw ErreurDeDocument.entreeCorrompue(nom: reference.nom)
        }

        return octets
    }

    /// Un PDF ne porte pas de `ComicInfo.xml`.
    ///
    /// Le format a bien un dictionnaire de metadonnees a lui, mais il ne dit ni
    /// la serie, ni le numero de chapitre, ni le sens de lecture. Le lire
    /// appartient a la fonctionnalite de metadonnees, qui saura quoi en tirer.
    public func donneesDeMetadonnees() throws -> Data? {
        nil
    }

    /// Rasterise une page a la taille imposee par la zone et par le budget.
    ///
    /// - Parameters:
    ///   - reference: page a rendre, obtenue de ce document.
    ///   - zone: zone d affichage en pixels reels. Une zone vide, celle d une
    ///     vue pas encore mesuree, retombe sur la zone du document plutot que de
    ///     produire une page d un pixel.
    ///   - budget: plafond memoire, celui du document par defaut.
    /// - Throws: `ErreurDeDocument.entreeIntrouvable` si la reference vient d un
    ///   autre document, `.entreeCorrompue` si la page refuse de se rendre.
    public func rendre(
        _ reference: ReferencePage,
        dans zone: TailleEnPixels,
        budget: BudgetDeDecodage? = nil
    ) throws -> ImageDePage {
        let rang = try rangValide(de: reference)

        verrou.lock()
        defer { verrou.unlock() }

        let page = try pageCoreGraphics(a: rang, nom: reference.nom)
        let origine = Self.tailleEnPoints(de: page)
        let cible = Self.tailleCible(
            pour: origine,
            dans: zone.estVide ? zoneDeRendu : zone,
            budget: budget ?? budgetParDefaut
        )

        guard let image = Self.rasteriser(page, vers: cible) else {
            throw ErreurDeDocument.entreeCorrompue(nom: reference.nom)
        }

        return ImageDePage(
            image: image,
            tailleDOrigine: origine,
            tailleDecodee: TailleEnPixels(largeur: image.width, hauteur: image.height),
            niveau: .affichage
        )
    }

    /// Nom stable d une page, ordonne naturellement et sans doublon.
    static func nom(dePage index: Int) -> String {
        String(format: "page-%04d", index + 1)
    }

    /// Taille que le rendu par defaut donnerait a cette page.
    private func tailleDeRendu(a rang: Int) throws -> TailleEnPixels {
        verrou.lock()
        defer { verrou.unlock() }

        let page = try pageCoreGraphics(a: rang, nom: Self.nom(dePage: rang))

        return Self.tailleCible(
            pour: Self.tailleEnPoints(de: page),
            dans: zoneDeRendu,
            budget: budgetParDefaut
        )
    }

    /// Verifie que la reference vient bien de ce document, et rend son rang.
    private func rangValide(de reference: ReferencePage) throws -> Int {
        guard reference.index >= 0,
              reference.index < nombrePages,
              reference.nom == Self.nom(dePage: reference.index)
        else {
            throw ErreurDeDocument.entreeIntrouvable(nom: reference.nom)
        }

        return reference.index
    }

    /// Page Core Graphics sous jacente. A appeler verrou tenu.
    private func pageCoreGraphics(a rang: Int, nom: String) throws -> CGPDFPage {
        guard let page = document.page(at: rang)?.pageRef else {
            throw ErreurDeDocument.entreeCorrompue(nom: nom)
        }

        return page
    }

    /// Dimensions de la page en points, rotation appliquee.
    private static func tailleEnPoints(de page: CGPDFPage) -> TailleEnPixels {
        let boite = page.getBoxRect(.mediaBox)
        let angle = ((page.rotationAngle % 360) + 360) % 360
        let surLeCote = angle % 180 == 90

        return TailleEnPixels(
            largeur: Int((surLeCote ? boite.height : boite.width).rounded()),
            hauteur: Int((surLeCote ? boite.width : boite.height).rounded())
        )
    }

    /// Taille a rasteriser : la page ajustee a la zone, puis bornee au budget.
    private static func tailleCible(
        pour page: TailleEnPixels,
        dans zone: TailleEnPixels,
        budget: BudgetDeDecodage
    ) -> TailleEnPixels {
        let ajuste = AjustementDePage.coteMaximalADecoder(page: page, dans: zone)
        let cote = budget.coteMaximal(pour: page, sansDepasser: ajuste)

        return BudgetDeDecodage.reduction(de: page, vers: cote)
    }

    /// Dessine la page dans une matrice de la taille demandee.
    private static func rasteriser(_ page: CGPDFPage, vers cible: TailleEnPixels) -> CGImage? {
        let format = CGImageAlphaInfo.noneSkipLast.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        let matrice = CGRect(x: 0, y: 0, width: cible.largeur, height: cible.hauteur)

        guard cible.estVide == false,
              let contexte = CGContext(
                  data: nil,
                  width: cible.largeur,
                  height: cible.hauteur,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: format
              )
        else {
            return nil
        }

        // Un PDF ne porte aucun fond. Sans ce remplissage, les marges d une page
        // scannee sortiraient noires la ou le papier est blanc.
        contexte.setFillColor(gray: 1, alpha: 1)
        contexte.fill(matrice)

        contexte.concatenate(
            page.getDrawingTransform(.mediaBox, rect: matrice, rotate: 0, preserveAspectRatio: true)
        )
        contexte.drawPDFPage(page)

        return contexte.makeImage()
    }

    /// Encode la matrice en PNG, sans perte.
    private static func encoderEnPng(_ image: CGImage) -> Data? {
        let sortie = NSMutableData()

        guard let destination = CGImageDestinationCreateWithData(
            sortie,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }

        CGImageDestinationAddImage(destination, image, nil)

        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        return sortie as Data
    }
}
