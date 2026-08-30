import Core
import CoreML
import Foundation
import Vision

//
// ModeleCoreMLDeDetectionDeCases
//
// Le detecteur de cases de la section 8 tel qu il arrive reellement sur
// l appareil : un reseau de detection d objets converti en Core ML, charge
// depuis un paquet compile.
//
// Le fichier ne vit pas dans ce depot, pour la meme raison que les deux autres,
// et sa licence est verifiee avant qu il ne soit ouvert. La verification porte
// ici sur une condition de plus, et c est la fonctionnalite entiere qui en
// depend : la section 8 exige la provenance du jeu de donnees d entrainement du
// detecteur. `CatalogueDesModelesIA` refuse donc un detecteur dont le jeu de
// donnees n est pas documente, ou dont la licence de jeu de donnees ne permet
// pas de distribuer les poids qui en sont tires.
//
// Le passage par Vision et non par `MLModel` en direct est un choix, et il tient
// a l entree. Les deux autres traitements decoupent la page en tuiles au cote
// exact du reseau, ils n ont donc jamais a redimensionner. Un detecteur voit la
// planche entiere et son entree est fixe, il faut donc mettre la planche a
// l echelle de l entree, puis ramener les cadres rendus a l echelle de la
// planche. Vision fait les deux, et le refaire a la main reviendrait a
// reimplementer un redimensionnement de plus, avec sa propre facon de se
// tromper d un demi pixel.
//
// Les coordonnees changent de repere a la sortie. Vision mesure ses cadres
// depuis le bord bas de l image, `CaseDePage` depuis le bord haut, comme
// `CGImage` et comme tout le reste du projet. La conversion est faite ici, une
// fois, au seul endroit ou le repere de Vision entre dans le projet.
//
// Le marqueur non verifie porte sur `VNCoreMLModel`, qui n est pas declare
// Sendable. Il est sur pour les memes deux raisons que pour les autres modeles :
// Apple documente la prediction comme utilisable depuis plusieurs fils, et
// l acteur de detection serialise tous les appels.
//

/// Detecteur de cases charge depuis un paquet Core ML compile.
public struct ModeleCoreMLDeDetectionDeCases: ModeleDeDetectionDeCases, @unchecked Sendable {
    public let identifiant: String

    /// Licence et jeu de donnees sous lesquels ce modele est installe.
    public let fiche: FicheDeModeleIA

    private let modele: VNCoreMLModel

    /// Charge un detecteur compile.
    ///
    /// - Parameters:
    ///   - url: dossier `mlmodelc` produit par la compilation du modele.
    ///   - identifiant: nom retenu dans les cles de cache et cle de la fiche de
    ///     licence. Il doit changer des que le fichier change, sans quoi une
    ///     mise a jour du reseau ferait ressortir du cache les cases trouvees
    ///     par l ancien.
    ///   - calcul: unites de calcul autorisees.
    /// - Throws: `ErreurDeTraitementIA` quand la licence ou le jeu de donnees ne
    ///   sont pas documentes, quand le fichier est illisible, ou quand le modele
    ///   n est pas un detecteur d objets.
    public init(
        contenuDe url: URL,
        identifiant: String,
        calcul: MLComputeUnits = .all
    ) throws {
        fiche = try CatalogueDesModelesIA.verifierLaLicence(
            identifiant: identifiant,
            traitement: .detectionDeCases,
            modele: url
        )

        let configuration = MLModelConfiguration()
        configuration.computeUnits = calcul

        guard let charge = try? MLModel(contentsOf: url, configuration: configuration) else {
            throw ErreurDeTraitementIA.modeleIllisible(chemin: url.path)
        }

        guard charge.modelDescription.inputDescriptionsByName.values.contains(where: {
            $0.type == .image
        }) else {
            throw ErreurDeTraitementIA.modeleSansImage(identifiant: identifiant)
        }

        guard let vision = try? VNCoreMLModel(for: charge) else {
            throw ErreurDeTraitementIA.modeleSansImage(identifiant: identifiant)
        }

        self.identifiant = identifiant
        modele = vision
    }

    /// Detecte les cases d une planche en la faisant passer par le reseau.
    ///
    /// L image est etiree a l entree du reseau plutot que rognee. Une planche
    /// rognee perdrait ses cases de bord, qui sont precisement celles ou le
    /// decoupage compte, et la deformation d une detection de cadre se corrige
    /// exactement au retour puisque les coordonnees sont des fractions.
    public func detecter(_ planche: MatriceDePixels) throws -> [CaseDePage] {
        guard let tampon = TamponDePixels.creer(planche) else {
            throw ErreurDeTraitementIA.pageIllisible
        }

        let requete = VNCoreMLRequest(model: modele)
        requete.imageCropAndScaleOption = .scaleFill

        let executant = VNImageRequestHandler(cvPixelBuffer: tampon, options: [:])

        do {
            try executant.perform([requete])
        } catch {
            throw ErreurDeTraitementIA.modeleEnEchec(identifiant: identifiant)
        }

        guard let observations = requete.results as? [VNRecognizedObjectObservation] else {
            throw ErreurDeTraitementIA.modeleEnEchec(identifiant: identifiant)
        }

        return observations.compactMap(Self.caseDePage)
    }

    /// Case portee par une observation de Vision, dans le repere du projet.
    ///
    /// Rend nil quand le cadre ne tient pas dans la planche. Un cadre hors
    /// planche est une detection perdue, pas une raison de refuser les autres :
    /// la case suivante est peut etre parfaitement lisible.
    private static func caseDePage(_ observation: VNRecognizedObjectObservation) -> CaseDePage? {
        let cadre = observation.boundingBox

        return CaseDePage(
            abscisse: cadre.origin.x,
            ordonnee: 1 - cadre.origin.y - cadre.height,
            largeur: cadre.width,
            hauteur: cadre.height,
            confiance: Double(observation.confidence)
        )
    }
}
