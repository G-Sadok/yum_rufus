import Core
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

//
// VignetteDeSignet
//
// Fabrique la vignette qu un signet conserve de la page marquee, section 3.1 du
// cahier de developpement, colonne `vignetteLocale`.
//
// La vignette passe par le decodeur sous echantillonne, comme toute image du
// produit. Poser un signet sur une page de 3000 par 4500 ne doit pas couter les
// 54 Mo de l erreur numero trois du cahier : le decodage est borne au cote de la
// vignette, soit deux cent millieme de cette matrice.
//
// Le fichier produit est nomme d apres l identifiant du signet, et la base ne
// retient que ce nom. Un chemin absolu serait perdu a la premiere reinstallation
// sur iOS, ou le dossier de l application change d emplacement.
//

/// Echec de la fabrication ou de la relecture d une vignette de signet.
public enum ErreurDeVignette: Error, Sendable, Equatable {
    /// Le dossier des vignettes n existe pas et ne peut pas etre cree.
    case dossierInaccessible(chemin: String)

    /// L image est decodee mais le systeme refuse de l encoder.
    case encodageImpossible(signet: String)

    /// Le fichier de vignette ne peut pas etre ecrit.
    case ecritureImpossible(nom: String)

    /// Message destine a l utilisateur, qui nomme la cause et indique la sortie.
    public var messageUtilisateur: String {
        switch self {
        case .dossierInaccessible:
            "Le dossier des vignettes n est pas accessible. Verifiez l espace disque disponible."
        case .encodageImpossible:
            "La vignette de cette page n a pas pu etre produite. Le signet est pose sans vignette."
        case .ecritureImpossible:
            "La vignette n a pas pu etre enregistree. Verifiez l espace disque disponible."
        }
    }

    /// Identifiant stable pour le journal, sans aucune donnee personnelle.
    public var codeDeJournal: String {
        switch self {
        case .dossierInaccessible: "vignette.dossierInaccessible"
        case .encodageImpossible: "vignette.encodageImpossible"
        case .ecritureImpossible: "vignette.ecritureImpossible"
        }
    }
}

/// Produit et range les vignettes des signets.
public struct FabriqueDeVignettesDeSignet: Sendable {
    /// Plus grand cote d une vignette de signet, en pixels.
    ///
    /// La vignette s affiche sur 44 par 66 points, la taille que la section 5.2
    /// donne deja a la vignette d une entree d historique. Trois fois cette
    /// hauteur couvre la densite la plus elevee du parc, et rien au dela : une
    /// vignette decodee plus grande que son affichage serait exactement
    /// l erreur que le sous echantillonnage existe pour eviter.
    public static let coteMaximalEnPixels = 198

    /// Qualite de compression du fichier produit.
    ///
    /// Une vignette de 132 par 198 pese quelques kilooctets a cette qualite, et
    /// les artefacts de compression restent invisibles a cette taille.
    static let qualite = 0.8

    /// Extension du fichier produit.
    static let extensionDeFichier = "jpg"

    /// Dossier ou vivent les vignettes.
    public let dossier: URL

    /// Plus grand cote demande au decodeur.
    public let coteMaximal: Int

    private let decodeur = DecodeurDePage()

    /// Construit la fabrique.
    ///
    /// - Parameters:
    ///   - dossier: dossier des vignettes, cree a la premiere ecriture.
    ///   - coteMaximal: plus grand cote de la vignette produite.
    public init(dossier: URL, coteMaximal: Int = FabriqueDeVignettesDeSignet.coteMaximalEnPixels) {
        self.dossier = dossier
        self.coteMaximal = max(1, coteMaximal)
    }

    /// Produit la vignette d une page et rend le nom de son fichier.
    ///
    /// - Parameters:
    ///   - donnees: octets bruts de la page marquee, dans le format du fichier.
    ///   - nom: nom de l entree, repris dans les erreurs de decodage.
    ///   - signet: identifiant du signet, qui nomme le fichier produit.
    /// - Returns: le nom du fichier, a ranger dans la colonne `vignetteLocale`.
    /// - Throws: `ErreurDeDecodage` quand la page n est pas lisible,
    ///   `ErreurDeVignette` quand le disque refuse le fichier.
    @discardableResult
    public func produire(_ donnees: Data, nom: String, pour signet: UUID) throws -> String {
        let zone = TailleEnPixels(largeur: coteMaximal, hauteur: coteMaximal)
        let page = try decodeur.decoder(donnees, nom: nom, dans: zone)
        let nomDuFichier = Self.nomDeFichier(pour: signet)

        guard let encodee = Self.encoder(page.image) else {
            throw ErreurDeVignette.encodageImpossible(signet: signet.uuidString)
        }

        try creerLeDossier()

        do {
            try encodee.write(to: dossier.appending(path: nomDuFichier), options: .atomic)
        } catch {
            throw ErreurDeVignette.ecritureImpossible(nom: nomDuFichier)
        }

        return nomDuFichier
    }

    /// Emplacement d une vignette deja produite.
    ///
    /// - Returns: nil quand le nom n est pas un simple nom de fichier. Un nom
    ///   relu dans une sauvegarde vient d un fichier que nous n avons pas ecrit :
    ///   accepter un nom qui remonte l arborescence ferait lire, et surtout
    ///   supprimer, un fichier hors du dossier des vignettes.
    public func url(de nom: String) -> URL? {
        guard Self.estUnNomDeFichier(nom) else {
            return nil
        }

        return dossier.appending(path: nom)
    }

    /// Supprime la vignette d un signet retire.
    ///
    /// L absence du fichier n est pas une erreur : un signet restaure depuis une
    /// sauvegarde n a jamais eu de vignette sur cet appareil, et le supprimer ne
    /// doit pas faire echouer la suppression du signet lui meme.
    public func supprimer(_ nom: String) {
        guard let url = url(de: nom) else {
            return
        }

        try? FileManager.default.removeItem(at: url)
    }

    /// Nom du fichier de vignette d un signet.
    static func nomDeFichier(pour signet: UUID) -> String {
        "\(signet.uuidString.lowercased()).\(extensionDeFichier)"
    }

    /// Vrai quand la chaine est un simple nom de fichier, sans chemin.
    static func estUnNomDeFichier(_ nom: String) -> Bool {
        nom.isEmpty == false
            && nom.contains("/") == false
            && nom.hasPrefix(".") == false
    }

    private func creerLeDossier() throws {
        do {
            try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        } catch {
            throw ErreurDeVignette.dossierInaccessible(chemin: dossier.path)
        }
    }

    /// Encode la vignette en JPEG.
    private static func encoder(_ image: CGImage) -> Data? {
        let tampon = NSMutableData()

        guard let destination = CGImageDestinationCreateWithData(
            tampon as CFMutableData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }

        let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: qualite]
        CGImageDestinationAddImage(destination, image, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        return tampon as Data
    }
}
