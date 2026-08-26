import Core
import CoreGraphics
import Foundation
import ImageIO

//
// DecodageEnTuiles
//
// Entree de la chaine d images pour le mode webtoon, section 7.3.
//
// Le decodage ordinaire de la section 6.1 borne le plus grand cote de la page.
// Applique a une bande de webtoon, il borne donc sa hauteur, et comme le ratio
// est conserve, il ecrase la largeur du meme coup : une bande de 800 par 20000
// ramenee au budget d une page ordinaire ne fait plus que trois cent pixels de
// large, ce qui rend le texte illisible. La bande demande l inverse, garder la
// largeur de la colonne et accepter la hauteur qui va avec.
//
// Ce que le decodage garantit ici tient en trois points.
//
// La largeur demandee est bornee par la limite de texture. La bande produite
// peut donc toujours etre coupee en tuiles affichables, sans avoir a couper
// aussi en largeur.
//
// Le decodage n agrandit jamais. Une bande plus etroite que la colonne est
// decodee a sa taille, et c est la vue qui l etire. Demander plus de pixels que
// le fichier n en porte couterait de la memoire pour zero detail.
//
// La bande n est jamais decodee en pleine resolution pour etre reduite ensuite.
// Image I/O produit directement la version sous echantillonnee, comme pour une
// page ordinaire.
//
// La bande decodee reste en memoire tant que ses tuiles servent. C est assume :
// elle vit en memoire centrale, pas en texture, et une seule bande a la fois est
// tenue par le lecteur. Ce que la carte graphique recoit, ce sont les tuiles, et
// leur nombre est plafonne par le budget du moteur.
//

extension BudgetDeDecodage {
    /// Plafond memoire d une bande de webtoon decodee.
    ///
    /// Soixante douze millions d octets, choisis pour laisser passer intacte la
    /// bande du critere de la section 7.3, vingt mille pixels de haut sur une
    /// colonne de huit cents, qui pese soixante six millions d octets une fois
    /// alignee. En dessous, le cas que la fonctionnalite existe pour traiter
    /// serait reduit avant meme d etre tuile.
    ///
    /// Le plafond reste un plafond : une bande plus lourde est sous
    /// echantillonnee, ce qui la rend plus douce mais jamais illisible.
    public static let bandeDeWebtoon = BudgetDeDecodage(octetsParPage: 72_000_000)
}

/// Bande longue decodee, prete a etre servie tuile par tuile.
///
/// `CGImage` est immuable et le decodeur ne garde aucune reference sur elle, la
/// franchir d un domaine de concurrence a l autre est donc sur, ce que le
/// marqueur non verifie declare. Meme raison que pour `ImageDePage`.
public struct BandeTuilee: @unchecked Sendable {
    /// Dimensions annoncees par le fichier, avant sous echantillonnage.
    public let tailleDOrigine: TailleEnPixels

    /// Dimensions de la bande reellement decodee.
    public let tailleDecodee: TailleEnPixels

    /// Decoupes des tuiles, du haut vers le bas.
    public let decoupes: [DecoupeDeTuile]

    private let bande: ImageDePage
    private let tuilage: TuilageDImageLongue

    init(bande: ImageDePage, tuilage: TuilageDImageLongue) {
        self.bande = bande
        self.tuilage = tuilage
        tailleDOrigine = bande.tailleDOrigine
        tailleDecodee = bande.tailleDecodee
        decoupes = tuilage.decoupes(de: bande.tailleDecodee)
    }

    /// Nombre de tuiles que cette bande porte.
    public var nombreDeTuiles: Int {
        decoupes.count
    }

    /// Octets occupes par la bande decodee, tuiles non comprises.
    public var octetsDeLaBande: Int {
        bande.octetsEnMemoire
    }

    /// Vrai quand chaque tuile de la bande tient dans une texture.
    ///
    /// Toujours vrai apres un decodage de ce fichier, et verifie par la suite de
    /// tests plutot que suppose.
    public var tuilesAffichables: Bool {
        decoupes.allSatisfy { TuilageDImageLongue.tientDansUneTexture($0.taille) }
    }

    /// Tuile de rang donne, decoupee a la demande.
    ///
    /// - Returns: nil quand le rang sort de la bande ou que le systeme refuse la
    ///   matrice.
    public func tuile(_ index: Int) -> ImageDePage? {
        tuilage.tuile(index, de: bande)
    }
}

extension DecodeurDePage {
    /// Decode une bande de webtoon a la largeur de la colonne, prete a tuiler.
    ///
    /// - Parameters:
    ///   - donnees: octets bruts de la page.
    ///   - nom: nom de l entree, repris dans les erreurs.
    ///   - largeurDeColonne: largeur de la colonne du lecteur, en pixels reels.
    ///   - tuilage: decoupe appliquee a la bande decodee.
    ///   - budget: plafond memoire de la bande.
    /// - Throws: `ErreurDeDecodage` quand le fichier n est pas une image
    ///   lisible.
    public func decoderEnTuiles(
        _ donnees: Data,
        nom: String,
        largeurDeColonne: Int,
        tuilage: TuilageDImageLongue = .parDefaut,
        budget: BudgetDeDecodage = .bandeDeWebtoon
    ) throws -> BandeTuilee {
        let colonne = Self.colonneRetenue(largeurDeColonne)

        if FormatDImage.depuis(octets: donnees, nom: nom)?.estVectoriel == true {
            let dimensions = try RasterisateurSvg.dimensions(donnees, nom: nom)
            let bande = try RasterisateurSvg.rasteriser(
                donnees,
                nom: nom,
                dans: Self.zone(pour: dimensions, colonne: colonne),
                budget: budget
            )

            return BandeTuilee(bande: bande, tuilage: tuilage)
        }

        let source = try Self.source(de: donnees, nom: nom)
        let tailleDOrigine = try Self.dimensions(de: source, nom: nom)
        let cote = Self.coteADecoder(pour: tailleDOrigine, colonne: colonne, budget: budget)

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

        return BandeTuilee(
            bande: ImageDePage(
                image: image,
                tailleDOrigine: tailleDOrigine,
                tailleDecodee: TailleEnPixels(largeur: image.width, hauteur: image.height),
                niveau: .affichage
            ),
            tuilage: tuilage
        )
    }

    /// Largeur de colonne reellement demandee au decodeur.
    ///
    /// Bornee par la limite de texture, ce qui garantit qu aucune tuile ne
    /// depassera cette limite en largeur, et par un pixel au minimum, pour
    /// qu une fenetre pas encore mesuree ne fasse pas demander une image nulle.
    static func colonneRetenue(_ largeurDeColonne: Int) -> Int {
        min(max(1, largeurDeColonne), TuilageDImageLongue.limiteDeTexture)
    }

    /// Plus grand cote a demander pour poser cette bande sur cette colonne.
    ///
    /// Le facteur est plafonne a un : le decodage ne fabrique jamais de pixels
    /// que le fichier ne porte pas.
    static func coteADecoder(pour taille: TailleEnPixels, colonne: Int, budget: BudgetDeDecodage) -> Int {
        guard taille.estVide == false else { return max(1, colonne) }

        let facteur = min(1, Double(colonne) / Double(taille.largeur))
        let voulu = max(1, Int((Double(taille.plusGrandCote) * facteur).rounded()))

        return budget.coteMaximal(pour: taille, sansDepasser: voulu)
    }

    /// Zone de rasterisation d une bande vectorielle posee sur cette colonne.
    ///
    /// La hauteur est celle du ratio, pas celle de la fenetre : l ajustement
    /// retient le plus contraignant des deux cotes, et une hauteur de fenetre
    /// ecraserait la bande au lieu de la laisser filer.
    private static func zone(pour taille: TailleEnPixels, colonne: Int) -> TailleEnPixels {
        guard taille.estVide == false else {
            return TailleEnPixels(largeur: colonne, hauteur: colonne)
        }

        let hauteur = Double(taille.hauteur) * Double(colonne) / Double(taille.largeur)

        return TailleEnPixels(largeur: colonne, hauteur: max(1, Int(hauteur.rounded())))
    }
}
