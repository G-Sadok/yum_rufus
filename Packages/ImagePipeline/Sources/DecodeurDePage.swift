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
// Ce cote est le plus petit de deux valeurs : celui de la page ajustee a la
// zone d affichage, et celui que le budget memoire autorise.
//
// La pleine resolution existe, mais elle n est pas publique. Elle passe par
// ReserveDeZoom, seule detentrice autorisee, qui la libere a la fin du geste.
// Aucun autre paquet ne peut donc decoder une page entiere par megarde.
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

/// Niveau de detail auquel une page a ete decodee.
public enum NiveauDeDetail: Sendable, Hashable {
    /// Page bornee a la zone d affichage et au budget memoire.
    case affichage

    /// Page decodee telle que le fichier la porte, reservee au zoom actif.
    case pleineResolution
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

    /// Niveau auquel cette image a ete produite.
    public let niveau: NiveauDeDetail

    public init(
        image: CGImage,
        tailleDOrigine: TailleEnPixels,
        tailleDecodee: TailleEnPixels,
        niveau: NiveauDeDetail
    ) {
        self.image = image
        self.tailleDOrigine = tailleDOrigine
        self.tailleDecodee = tailleDecodee
        self.niveau = niveau
    }

    /// Octets reellement occupes par la matrice de pixels.
    ///
    /// Mesure prise sur l image produite, alignement des lignes compris, et non
    /// estimee a partir des dimensions. C est ce nombre que les budgets
    /// memoire du projet plafonnent.
    public var octetsEnMemoire: Int {
        image.bytesPerRow * image.height
    }

    /// Vrai quand l image porte moins de pixels que le fichier d origine.
    public var estSousEchantillonnee: Bool {
        tailleDecodee.plusGrandCote < tailleDOrigine.plusGrandCote
    }
}

/// Decodeur d une page vers la taille a laquelle elle sera affichee.
public struct DecodeurDePage: Sendable {
    public init() {}

    /// Decode une page, bornee par la zone d affichage et par le budget memoire.
    ///
    /// - Parameters:
    ///   - donnees: octets bruts de la page, dans le format du fichier.
    ///   - nom: nom de l entree, repris dans les erreurs.
    ///   - zone: zone d affichage en pixels reels.
    ///   - budget: plafond memoire de la page decodee.
    /// - Throws: `ErreurDeDecodage` quand le fichier n est pas une image
    ///   lisible.
    public func decoder(
        _ donnees: Data,
        nom: String,
        dans zone: TailleEnPixels,
        budget: BudgetDeDecodage = .parDefaut
    ) throws -> ImageDePage {
        if FormatDImage.depuis(octets: donnees, nom: nom)?.estVectoriel == true {
            return try RasterisateurSvg.rasteriser(donnees, nom: nom, dans: zone, budget: budget)
        }

        let source = try Self.source(de: donnees, nom: nom)
        let tailleDOrigine = try Self.dimensions(de: source, nom: nom)
        let coteAjuste = AjustementDePage.coteMaximalADecoder(page: tailleDOrigine, dans: zone)
        let cote = budget.coteMaximal(pour: tailleDOrigine, sansDepasser: coteAjuste)

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: cote,
        ]

        guard let reduite = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw ErreurDeDecodage.decodageImpossible(nom: nom)
        }

        let image = try Self.materialiser(reduite, nom: nom)

        return ImageDePage(
            image: image,
            tailleDOrigine: tailleDOrigine,
            tailleDecodee: TailleEnPixels(largeur: image.width, hauteur: image.height),
            niveau: .affichage
        )
    }

    /// Dimensions annoncees par le fichier, sans rien decoder.
    ///
    /// Sert a la precharge et au tuilage, qui ont besoin du format de la page
    /// avant de decider quoi decoder.
    public func dimensions(_ donnees: Data, nom: String) throws -> TailleEnPixels {
        if FormatDImage.depuis(octets: donnees, nom: nom)?.estVectoriel == true {
            return try RasterisateurSvg.dimensions(donnees, nom: nom)
        }

        return try Self.dimensions(de: Self.source(de: donnees, nom: nom), nom: nom)
    }

    /// Decode la page entiere, sans borne.
    ///
    /// Volontairement interne au paquet. Une page de 3000 par 4500 coute ici
    /// 54 Mo, ce qui n est acceptable que pendant un geste de zoom et sous la
    /// garde de `ReserveDeZoom`, qui la libere a la fin du geste.
    func decoderEnPleineResolution(_ donnees: Data, nom: String) throws -> ImageDePage {
        let source = try Self.source(de: donnees, nom: nom)
        let tailleDOrigine = try Self.dimensions(de: source, nom: nom)

        let options: [CFString: Any] = [
            kCGImageSourceShouldCacheImmediately: true,
        ]

        guard let entiere = CGImageSourceCreateImageAtIndex(source, 0, options as CFDictionary) else {
            throw ErreurDeDecodage.decodageImpossible(nom: nom)
        }

        let image = try Self.materialiser(entiere, nom: nom)

        return ImageDePage(
            image: image,
            tailleDOrigine: tailleDOrigine,
            tailleDecodee: TailleEnPixels(largeur: image.width, hauteur: image.height),
            niveau: .pleineResolution
        )
    }

    /// Redessine l image dans une matrice que nous possedons.
    ///
    /// Image I/O rend une image paresseuse : les pixels n existent qu au premier
    /// dessin. Deux consequences inacceptables ici. La memoire d une page ne
    /// serait ni mesurable ni plafonnee au moment ou on croit l avoir decodee,
    /// et le decodage reel tomberait sur le fil qui dessine, pendant la tourne
    /// de page ou pendant le geste de zoom, precisement la ou la section 12
    /// laisse 80 ms.
    ///
    /// Le passage par un contexte force le decodage tout de suite, sur le fil
    /// qui appelle, et rend une matrice a nous, de format connu et de taille
    /// connue. Le double tampon transitoire dure le temps du dessin.
    static func materialiser(_ image: CGImage, nom: String) throws -> CGImage {
        guard let materialisee = materialiser(image) else {
            throw ErreurDeDecodage.decodageImpossible(nom: nom)
        }

        return materialisee
    }

    /// Meme redessin, rendu nil plutot que leve.
    ///
    /// Le rognage l emprunte pour poser sa page coupee dans une matrice a elle.
    /// Il n a pas d erreur nommee a remonter : quand le systeme refuse la
    /// matrice, la page s affiche non rognee, ce qui n a rien d un echec pour
    /// l utilisateur.
    static func materialiser(_ image: CGImage) -> CGImage? {
        let format = CGImageAlphaInfo.noneSkipLast.rawValue | CGBitmapInfo.byteOrder32Little.rawValue

        guard image.width > 0,
              image.height > 0,
              let contexte = CGContext(
                  data: nil,
                  width: image.width,
                  height: image.height,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: format
              )
        else {
            return nil
        }

        contexte.draw(
            image,
            in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
        )

        return contexte.makeImage()
    }

    /// Source Image I/O adossee aux octets, sans copie ni decodage.
    static func source(de donnees: Data, nom: String) throws -> CGImageSource {
        guard let source = CGImageSourceCreateWithData(donnees as CFData, nil),
              CGImageSourceGetCount(source) > 0
        else {
            throw ErreurDeDecodage.formatInconnu(nom: nom)
        }

        return source
    }

    /// Dimensions annoncees par l en tete du fichier, sans decodage.
    static func dimensions(de source: CGImageSource, nom: String) throws -> TailleEnPixels {
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
