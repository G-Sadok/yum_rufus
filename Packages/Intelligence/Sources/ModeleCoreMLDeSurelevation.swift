import CoreML
import Foundation

//
// ModeleCoreMLDeSurelevation
//
// Le modele de la section 8 tel qu il arrive reellement sur l appareil : un
// reseau Real ESRGAN converti en Core ML, variante anime, charge depuis un
// paquet compile.
//
// Le fichier ne vit pas dans ce depot. Un reseau converti pese plusieurs
// dizaines de megaoctets, il se livre avec l application et non avec le code, et
// sa licence se verifie avant integration comme le rappelle la section 8 pour le
// detecteur de cases. Ce type ne fait donc que le charger et le questionner.
//
// La licence est verifiee avant le fichier, et non apres. Un modele absent du
// catalogue du depot, ou livre sans son avis de licence, ne se charge pas :
// voir `CatalogueDesModelesIA`. L ordre compte, il evite qu un reseau non
// documente soit charge en memoire le temps qu on s en apercoive.
//
// La geometrie n est pas supposee, elle est lue. Le modele annonce lui meme la
// taille de son entree et de sa sortie, et le facteur en est deduit par
// division. Un modele qui quadruplerait au lieu de doubler serait donc utilise
// correctement au lieu de produire une page a l echelle fausse, et un modele qui
// n annonce pas d image est refuse au chargement plutot qu a la premiere page.
//
// Le marqueur non verifie porte sur `MLModel`, qui n est pas declare Sendable.
// Il est sur ici pour deux raisons cumulees. Apple documente la prediction comme
// utilisable depuis plusieurs fils, et surtout l acteur d amelioration serialise
// tous les appels : une seule prediction tourne a la fois sur cet appareil, ce
// que la section 8 exige par ailleurs.
//

/// Modele de surelevation charge depuis un paquet Core ML compile.
public struct ModeleCoreMLDeSurelevation: ModeleDeSurelevation, @unchecked Sendable {
    public let identifiant: String
    public let facteur: Int
    public let coteDeTuile: Int

    private let modele: MLModel
    private let nomDeLEntree: String
    private let nomDeLaSortie: String

    /// Charge un modele compile.
    ///
    /// - Parameters:
    ///   - url: dossier `mlmodelc` produit par la compilation du modele.
    ///   - identifiant: nom retenu dans les cles de cache. Il doit changer des
    ///     que le fichier change, sans quoi une mise a jour du reseau ferait
    ///     ressortir du cache des pages produites par l ancien.
    ///   - calcul: unites de calcul autorisees.
    /// - Throws: `ErreurDeTraitementIA` quand la licence n est pas documentee,
    ///   quand le fichier est illisible, ou quand le modele n a pas la forme
    ///   attendue.
    public init(
        contenuDe url: URL,
        identifiant: String,
        calcul: MLComputeUnits = .all
    ) throws {
        try CatalogueDesModelesIA.verifierLaLicence(
            identifiant: identifiant,
            traitement: .amelioration,
            modele: url
        )

        let configuration = MLModelConfiguration()
        configuration.computeUnits = calcul

        guard let charge = try? MLModel(contentsOf: url, configuration: configuration) else {
            throw ErreurDeTraitementIA.modeleIllisible(chemin: url.path)
        }

        let description = charge.modelDescription

        guard let entree = Self.image(parmi: description.inputDescriptionsByName),
              let sortie = Self.image(parmi: description.outputDescriptionsByName),
              let contrainteDEntree = entree.value.imageConstraint,
              let contrainteDeSortie = sortie.value.imageConstraint,
              contrainteDEntree.pixelsWide > 0,
              contrainteDEntree.pixelsWide == contrainteDEntree.pixelsHigh
        else {
            throw ErreurDeTraitementIA.modeleSansImage(identifiant: identifiant)
        }

        let facteur = contrainteDeSortie.pixelsWide / contrainteDEntree.pixelsWide

        guard facteur >= 1,
              contrainteDeSortie.pixelsWide == contrainteDEntree.pixelsWide * facteur,
              contrainteDeSortie.pixelsHigh == contrainteDEntree.pixelsHigh * facteur
        else {
            throw ErreurDeTraitementIA.facteurInattendu(identifiant: identifiant, facteur: facteur)
        }

        self.identifiant = identifiant
        self.facteur = facteur
        modele = charge
        coteDeTuile = contrainteDEntree.pixelsWide
        nomDeLEntree = entree.key
        nomDeLaSortie = sortie.key
    }

    /// Agrandit une tuile en la faisant passer par le reseau.
    public func surelever(_ tuile: MatriceDePixels) throws -> MatriceDePixels {
        guard let entree = TamponDePixels.creer(tuile) else {
            throw ErreurDeTraitementIA.pageIllisible
        }

        let valeurs = [nomDeLEntree: MLFeatureValue(pixelBuffer: entree)]

        guard let fournisseur = try? MLDictionaryFeatureProvider(dictionary: valeurs),
              let resultat = try? modele.prediction(from: fournisseur),
              let produit = resultat.featureValue(for: nomDeLaSortie)?.imageBufferValue,
              let matrice = TamponDePixels.matrice(de: produit)
        else {
            throw ErreurDeTraitementIA.modeleEnEchec(identifiant: identifiant)
        }

        return matrice
    }

    /// Entree ou sortie de type image dont le nom vient en premier.
    ///
    /// Le dictionnaire des descriptions n a pas d ordre, et un modele converti
    /// expose parfois une entree secondaire, par exemple une echelle. Retenir le
    /// plus petit nom rend le choix reproductible d un lancement a l autre, ce
    /// qu un premier venu ne garantirait pas.
    private static func image(
        parmi descriptions: [String: MLFeatureDescription]
    ) -> (key: String, value: MLFeatureDescription)? {
        descriptions
            .filter { $0.value.type == .image }
            .min { $0.key < $1.key }
    }
}
