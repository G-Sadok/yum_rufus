import CoreML
import CoreVideo
import Foundation

//
// ModeleCoreMLDeColorisation
//
// Le modele de colorisation de la section 8 tel qu il arrive reellement sur
// l appareil : un reseau converti en Core ML, charge depuis un paquet compile.
//
// Le fichier ne vit pas dans ce depot, pour la meme raison que celui de la
// surelevation, et sa licence est verifiee avant qu il ne soit ouvert, voir
// `CatalogueDesModelesIA`.
//
// Trois choses sont lues sur le modele et non supposees, et chacune corrige une
// panne differente.
//
// Le cote de tuile vient du modele. Un reseau de colorisation converti n a pas
// forcement l entree de 256 que la section 8 impose au reseau de surelevation.
// Le lire ici, puis le donner au tuilage, evite un refus a chaque tuile sur un
// modele parfaitement valide.
//
// Le facteur doit valoir un. Une colorisation qui changerait les dimensions
// casserait les etapes suivantes de la chaine de la section 6.3, qui supposent
// toutes la geometrie de la precedente. Un modele qui agrandit est donc refuse
// au chargement, la ou il produirait sinon des pages a l echelle fausse.
//
// Les deux images doivent etre en 32BGRA. C est le seul format que le pont de
// `TamponDePixels` sait traduire, et un modele converti pour une entree en
// niveaux de gris echouerait sinon a la premiere prediction, sur un message qui
// ne dirait pas pourquoi. La conversion du reseau doit donc porter le passage en
// couleurs, ce qui est de toute facon le bon endroit pour le faire.
//
// Le marqueur non verifie porte sur `MLModel`, qui n est pas declare Sendable.
// Il est sur ici pour deux raisons cumulees. Apple documente la prediction comme
// utilisable depuis plusieurs fils, et surtout l acteur de colorisation
// serialise tous les appels : une seule prediction tourne a la fois sur cet
// appareil, ce que la section 8 exige par ailleurs.
//

/// Modele de colorisation charge depuis un paquet Core ML compile.
public struct ModeleCoreMLDeColorisation: ModeleDeColorisation, @unchecked Sendable {
    public let identifiant: String
    public let coteDeTuile: Int

    /// Licence sous laquelle ce modele est installe.
    public let fiche: FicheDeModeleIA

    private let modele: MLModel
    private let nomDeLEntree: String
    private let nomDeLaSortie: String

    /// Charge un modele compile.
    ///
    /// - Parameters:
    ///   - url: dossier `mlmodelc` produit par la compilation du modele.
    ///   - identifiant: nom retenu dans les cles de cache et cle de la fiche de
    ///     licence. Il doit changer des que le fichier change, sans quoi une
    ///     mise a jour du reseau ferait ressortir du cache des pages produites
    ///     par l ancien.
    ///   - calcul: unites de calcul autorisees.
    /// - Throws: `ErreurDeTraitementIA` quand la licence n est pas documentee,
    ///   quand le fichier est illisible, ou quand le modele n a pas la forme
    ///   attendue.
    public init(
        contenuDe url: URL,
        identifiant: String,
        calcul: MLComputeUnits = .all
    ) throws {
        fiche = try CatalogueDesModelesIA.verifierLaLicence(
            identifiant: identifiant,
            traitement: .colorisation,
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
              contrainteDEntree.pixelsWide == contrainteDEntree.pixelsHigh,
              Self.estEn32BGRA(contrainteDEntree),
              Self.estEn32BGRA(contrainteDeSortie)
        else {
            throw ErreurDeTraitementIA.modeleSansImage(identifiant: identifiant)
        }

        guard contrainteDeSortie.pixelsWide == contrainteDEntree.pixelsWide,
              contrainteDeSortie.pixelsHigh == contrainteDEntree.pixelsHigh
        else {
            throw ErreurDeTraitementIA.facteurInattendu(
                identifiant: identifiant,
                facteur: contrainteDeSortie.pixelsWide / max(1, contrainteDEntree.pixelsWide)
            )
        }

        self.identifiant = identifiant
        modele = charge
        coteDeTuile = contrainteDEntree.pixelsWide
        nomDeLEntree = entree.key
        nomDeLaSortie = sortie.key
    }

    /// Colorise une tuile en la faisant passer par le reseau.
    public func coloriser(_ tuile: MatriceDePixels) throws -> MatriceDePixels {
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
    /// expose parfois une entree secondaire, par exemple un indice de style.
    /// Retenir le plus petit nom rend le choix reproductible d un lancement a
    /// l autre, ce qu un premier venu ne garantirait pas.
    private static func image(
        parmi descriptions: [String: MLFeatureDescription]
    ) -> (key: String, value: MLFeatureDescription)? {
        descriptions
            .filter { $0.value.type == .image }
            .min { $0.key < $1.key }
    }

    /// Vrai quand cette contrainte porte le seul format que le pont traduit.
    private static func estEn32BGRA(_ contrainte: MLImageConstraint) -> Bool {
        contrainte.pixelFormatType == kCVPixelFormatType_32BGRA
    }
}
