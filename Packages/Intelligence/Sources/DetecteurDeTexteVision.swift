import Core
import Vision

//
// DetecteurDeTexteVision
//
// La detection de texte de la section 8 telle qu elle arrive reellement sur
// l appareil : `VNRecognizeTextRequest`, le lecteur de texte du systeme.
//
// C est la seule des quatre fonctions d intelligence de la section 8 qui ne
// demande aucun fichier de modele. Le systeme porte le sien, il tourne sur
// l appareil, et il ne demande aucune connexion. Il n y a donc ni fiche de
// licence a verifier ni jeu de donnees a documenter, contrairement aux trois
// autres traitements.
//
// La reconnaissance est reglee pour une planche de manga, et chaque reglage
// repond a un defaut precis.
//
// Le niveau precis plutot que rapide, parce que le texte d une bulle est court.
// Le niveau rapide gagne du temps sur les longs paragraphes d un document
// scanne, et perd les mots isoles, qui sont precisement ce qu une bulle contient.
//
// La correction linguistique est coupee. Elle rapproche une lecture douteuse du
// mot le plus probable de la langue, ce qui est utile sur un formulaire et
// nuisible ici : les noms propres et les onomatopees d un manga ne ressemblent a
// aucun mot courant, et la correction les remplacerait par des mots faux mais
// bien orthographies.
//
// Les langues sont passees telles que l appelant les donne, sans defaut cache.
// Une planche japonaise et une planche coreenne ne se lisent pas avec le meme
// jeu, et deviner d apres le sens de lecture serait exactement l erreur 6 du
// cahier des charges, confondre une propriete de la serie avec une propriete de
// la langue.
//
// Les coordonnees changent de repere a la sortie. Vision mesure ses cadres
// depuis le bord bas de l image, `CaseDePage` depuis le bord haut, comme
// `CGImage` et comme tout le reste du projet. La conversion est faite ici, au
// seul endroit ou le repere de Vision entre dans cette fonctionnalite.
//

/// Detection de texte appuyee sur le lecteur du systeme.
public struct DetecteurDeTexteVision: DetecteurDeTexte {
    /// Nom par defaut, qui entre dans les cles de cache.
    ///
    /// Il nomme le lecteur et sa revision. La revision fait partie du nom parce
    /// qu elle change les lectures rendues : deux revisions differentes ne
    /// doivent jamais se partager une entree de cache.
    public static let identifiantParDefaut = "vision.texte.r3"

    public let identifiant: String

    /// Langues cherchees dans la planche, dans l ordre de preference.
    public let langues: [String]

    /// Prepare une detection.
    ///
    /// - Parameters:
    ///   - langues: codes de langue cherches, dans l ordre de preference. Vide
    ///     laisse le systeme choisir, ce qui convient a une planche dont la
    ///     langue n est pas connue.
    ///   - identifiant: nom retenu dans les cles de cache.
    public init(
        langues: [String] = [],
        identifiant: String = identifiantParDefaut
    ) {
        self.langues = langues
        self.identifiant = identifiant
    }

    public func bulles(_ planche: MatriceDePixels) throws -> [BulleDeTexte] {
        guard let tampon = TamponDePixels.creer(planche) else {
            throw ErreurDeTraduction.plancheIllisible
        }

        let requete = VNRecognizeTextRequest()
        requete.recognitionLevel = .accurate
        requete.usesLanguageCorrection = false

        if langues.isEmpty == false {
            requete.recognitionLanguages = langues
        }

        let executant = VNImageRequestHandler(cvPixelBuffer: tampon, options: [:])

        do {
            try executant.perform([requete])
        } catch {
            throw ErreurDeTraduction.moteurEnEchec(identifiant: identifiant)
        }

        guard let observations = requete.results else {
            throw ErreurDeTraduction.moteurEnEchec(identifiant: identifiant)
        }

        return observations.compactMap(Self.bulle)
    }

    /// Bulle portee par une observation, dans le repere du projet.
    ///
    /// Rend nil quand le cadre ne tient pas dans la planche ou quand la lecture
    /// est vide. Une observation perdue n est pas une raison de refuser les
    /// autres : la bulle suivante est peut etre parfaitement lisible.
    private static func bulle(_ observation: VNRecognizedTextObservation) -> BulleDeTexte? {
        guard let lecture = observation.topCandidates(1).first else { return nil }

        let cadre = observation.boundingBox

        guard let rectangle = CaseDePage(
            abscisse: cadre.origin.x,
            ordonnee: 1 - cadre.origin.y - cadre.height,
            largeur: cadre.width,
            hauteur: cadre.height,
            confiance: Double(lecture.confidence)
        ) else {
            return nil
        }

        return BulleDeTexte(cadre: rectangle, texte: lecture.string)
    }
}
