import Core
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

//
// ChaineDeFiltres
//
// Les filtres du panneau de la section 5.7, appliques sur le GPU par Core Image.
//
// Une seule passe de rendu, quelle que soit le nombre de filtres armes. Core
// Image ne dessine rien tant qu on empile des `CIImage` : chaque etape decrit un
// calcul, et le contexte les concatene en un seul programme au moment du rendu.
// Materialiser une image entre deux etapes couterait une matrice de plus par
// etape, et c est exactement ce que le budget memoire de la fonctionnalite
// interdit. C est aussi ce qui rend le direct tenable : bouger un curseur
// refait une passe, pas six.
//
// L ordre d empilement est celui de la section 6.3, et il vient de
// `ReglagesDeFiltres.etapesDemandees`, jamais d une liste ecrite ici. La chaine
// se contente de retirer les etapes qu elle ne sait pas encore appliquer.
//
// Une divergence assumee, et elle est la seule. La section 6.3 range la
// reduction du bruit parmi les etapes couteuses mises en cache sur disque, alors
// que la fiche de la fonctionnalite la demande sur le GPU avec les cinq autres.
// Les deux se rejoignent ici : la reduction du bruit est un filtre Core Image,
// elle s empile a son rang, le troisieme, et elle ne se materialise pas plus que
// les autres. Il n y a donc aucun resultat intermediaire a mettre en cache. Son
// rang dans la chaine, lui, est respecte a la lettre : elle passe avant les deux
// traitements par IA, qui restent a livrer, et avant la nettete.
//
// Quand le systeme refuse le rendu, la page revient telle quelle. Les filtres
// sont un confort de lecture : quand ils echouent, la planche s affiche sans
// eux, elle ne manque pas.
//

/// Filtres du panneau de la section 5.7, appliques dans l ordre de la 6.3.
public struct ChaineDeFiltres: Sendable {
    /// Etat du panneau que cette chaine applique.
    public let reglages: ReglagesDeFiltres

    public init(reglages: ReglagesDeFiltres = .parDefaut) {
        self.reglages = reglages
    }

    /// Les six etapes de la section 6.3 que Core Image sait appliquer ici.
    ///
    /// Les etapes 4 et 5, amelioration et colorisation par IA, appartiennent a
    /// l etape 9 de la livraison. Elles gardent leur rang dans la chaine et
    /// leur interrupteur dans le panneau, mais rien ne les applique encore.
    public static let etapesPrisesEnCharge: [EtapeDeTraitement] = [
        .reductionDuBruit,
        .nettete,
        .contraste,
        .gamma,
        .luminosite,
        .chaleur,
    ]

    /// Etapes reellement appliquees, dans l ordre de la section 6.3.
    public var etapes: [EtapeDeTraitement] {
        reglages.etapesDemandees.filter(Self.etapesPrisesEnCharge.contains)
    }

    /// Vrai quand la chaine ne changerait rien a la page.
    public var estInerte: Bool {
        etapes.isEmpty
    }

    /// Page filtree, ou la page elle meme quand rien n est a appliquer.
    ///
    /// Une chaine inerte rend la page recue sans allouer quoi que ce soit. Le
    /// cas est celui d une installation neuve, et c est aussi celui du panneau
    /// remis a zero : la lecture ne doit alors rien payer.
    public func appliquer(a page: ImageDePage) -> ImageDePage {
        let demandees = etapes

        guard demandees.isEmpty == false else {
            return page
        }

        let entree = CIImage(cgImage: page.image)
        let cadre = entree.extent
        let empilee = demandees.reduce(entree) { image, etape in
            appliquer(etape, a: image)
        }

        guard let rendue = ContexteDeFiltres.partage.rendre(empilee, dans: cadre) else {
            return page
        }

        return ImageDePage(
            image: rendue,
            tailleDOrigine: page.tailleDOrigine,
            tailleDecodee: TailleEnPixels(largeur: rendue.width, hauteur: rendue.height),
            niveau: page.niveau
        )
    }

    /// Empile une etape sur l image, sans rien dessiner.
    ///
    /// Une etape que Core Image refuse est sautee plutot que fatale : les autres
    /// filtres du panneau restent appliques.
    func appliquer(_ etape: EtapeDeTraitement, a image: CIImage) -> CIImage {
        switch etape {
        case .reductionDuBruit: reduireLeBruit(image)
        case .nettete: accentuer(image)
        case .contraste: contraster(image)
        case .gamma: corrigerLeGamma(image)
        case .luminosite: eclairer(image)
        case .chaleur: rechauffer(image)
        case .rognageAutomatique, .divisionDesImagesLarges, .ameliorationIA, .colorisationIA:
            image
        }
    }

    // MARK: Etapes

    /// Etape 3, avec les reglages par defaut du filtre du systeme.
    ///
    /// L interrupteur du panneau n a pas de graduation : il n y a rien a
    /// calculer, seulement a armer ou desarmer.
    private func reduireLeBruit(_ image: CIImage) -> CIImage {
        let filtre = CIFilter.noiseReduction()
        filtre.inputImage = image.clampedToExtent()

        return filtre.outputImage ?? image
    }

    /// Etape 6.
    private func accentuer(_ image: CIImage) -> CIImage {
        let filtre = CIFilter.sharpenLuminance()
        filtre.inputImage = image.clampedToExtent()
        filtre.sharpness = Float(ParametresDeFiltres.nettete(reglages.valeur(.nettete)))

        return filtre.outputImage ?? image
    }

    /// Etape 7.
    ///
    /// `CIColorControls` porte la luminosite, le contraste et la saturation dans
    /// un seul filtre. Il en faut pourtant deux instances distinctes ici, l une
    /// pour le contraste et l autre pour la luminosite : la section 6.3 place le
    /// gamma entre les deux, et les reunir sauterait ce rang.
    private func contraster(_ image: CIImage) -> CIImage {
        let filtre = CIFilter.colorControls()
        filtre.inputImage = image
        filtre.contrast = Float(ParametresDeFiltres.contraste(reglages.valeur(.contraste)))

        return filtre.outputImage ?? image
    }

    /// Etape 8.
    private func corrigerLeGamma(_ image: CIImage) -> CIImage {
        let filtre = CIFilter.gammaAdjust()
        filtre.inputImage = image
        filtre.power = Float(ParametresDeFiltres.gamma(reglages.valeur(.gamma)))

        return filtre.outputImage ?? image
    }

    /// Etape 9.
    private func eclairer(_ image: CIImage) -> CIImage {
        let filtre = CIFilter.colorControls()
        filtre.inputImage = image
        filtre.brightness = Float(ParametresDeFiltres.luminosite(reglages.valeur(.luminosite)))

        return filtre.outputImage ?? image
    }

    /// Etape 10.
    private func rechauffer(_ image: CIImage) -> CIImage {
        let filtre = CIFilter.temperatureAndTint()
        filtre.inputImage = image
        filtre.neutral = CIVector(
            x: ParametresDeFiltres.temperature(reglages.valeur(.chaleur)),
            y: 0
        )
        filtre.targetNeutral = CIVector(x: ParametresDeFiltres.temperatureNeutre, y: 0)

        return filtre.outputImage ?? image
    }
}

/// Contexte Core Image partage par toutes les chaines de filtres.
///
/// Un contexte compile ses programmes au premier rendu. En creer un par page
/// paierait cette compilation a chaque tourne, et le direct promis par la
/// section 5.7 tomberait des le premier deplacement de curseur.
///
/// `CIContext` est declare sur en acces concurrent par son auteur, et cette
/// classe ne fait que le detenir : aucun etat mutable n est ajoute autour. C est
/// ce qui justifie le marqueur non verifie.
final class ContexteDeFiltres: @unchecked Sendable {
    /// Contexte unique du processus.
    static let partage = ContexteDeFiltres()

    private let contexte: CIContext
    private let espace: CGColorSpace

    private init() {
        // L espace de travail est le sRGB et non un espace lineaire. Les
        // curseurs du panneau agissent alors sur les valeurs telles que l oeil
        // les lit, ce qui est la seule facon qu une course de curseur paraisse
        // reguliere d un bout a l autre.
        let espace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

        self.espace = espace
        contexte = CIContext(options: [
            .workingColorSpace: espace,
            .outputColorSpace: espace,
            // Les intermediaires ne servent qu a un rendu repete de la meme
            // image. Ici chaque rendu suit un deplacement de curseur, donc une
            // image differente : les garder ne ferait que gonfler l empreinte.
            .cacheIntermediates: false,
        ])
    }

    /// Dessine l image empilee dans une matrice a nous.
    ///
    /// Le cadre est celui de l image d origine. Les filtres de convolution
    /// travaillent sur une image prolongee au dela de ses bords, sans quoi les
    /// pixels du bord seraient calcules contre du vide et la planche prendrait
    /// un lisere. Le cadre les ramene a la taille exacte de la page.
    func rendre(_ image: CIImage, dans cadre: CGRect) -> CGImage? {
        guard cadre.isEmpty == false, cadre.isInfinite == false else {
            return nil
        }

        return contexte.createCGImage(
            image,
            from: cadre,
            format: .RGBA8,
            colorSpace: espace
        )
    }

    /// Compile les programmes du contexte sur une image minuscule.
    ///
    /// A appeler a l ouverture du lecteur. Sans cela, le premier deplacement de
    /// curseur paie la compilation, et c est le seul a coup que la section 5.7
    /// ne pardonne pas : celui que l utilisateur voit en decouvrant le panneau.
    func prechauffer() {
        let cadre = CGRect(x: 0, y: 0, width: 8, height: 8)
        let unie = CIImage(color: .gray).cropped(to: cadre)
        let chaine = ChaineDeFiltres(reglages: Self.reglagesDePrechauffage)

        let empilee = ChaineDeFiltres.etapesPrisesEnCharge.reduce(unie) { image, etape in
            chaine.appliquer(etape, a: image)
        }

        _ = rendre(empilee, dans: cadre)
    }

    /// Reglages qui arment les six etapes, pour que le prechauffage compile
    /// chaque programme au moins une fois.
    private static var reglagesDePrechauffage: ReglagesDeFiltres {
        var reglages = ReglagesDeFiltres.parDefaut

        for filtre in FiltreDImage.allCases {
            reglages.regler(filtre, a: filtre.valeurParDefaut == 0 ? 50 : 0)
        }

        reglages.basculer(.reductionDuBruit, true)

        return reglages
    }
}
