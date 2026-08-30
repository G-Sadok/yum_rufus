import Foundation

/// Lecture du catalogue de chaines de l application depuis le disque.
///
/// Le catalogue vit dans la cible `App/Yum`, qui n est pas compilee par Swift
/// Package Manager. Le lire ici est le seul moyen de verifier, dans la suite qui
/// tourne a chaque commit, que les libelles affiches sont bien ceux du tableau
/// 6.1 de DESIGN-SPEC.md, et dans le bon ordre.
///
/// Le fichier n est lu et decode qu une seule fois pour toute la campagne. Ce
/// n est pas une optimisation de confort : une trentaine de tests demandent le
/// catalogue, et depuis qu il porte quatre langues chaque decodage fabrique
/// plusieurs milliers de chaines courtes. L allocateur ne rend pas ces regions
/// au systeme, et l empreinte du processus de test montait assez pour faire
/// echouer le plafond de lecture de la section 12 mesure par
/// `MemoireDeDecodageTests`, qui compte la memoire du processus entier.
enum CatalogueDeChaines {
    /// Chemin du catalogue, resolu depuis l emplacement de ce fichier.
    static var chemin: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // DesignSystem
            .deletingLastPathComponent() // Packages
            .deletingLastPathComponent() // racine du depot
            .appendingPathComponent("App/Yum/Ressources/Localizable.xcstrings")
    }

    /// Valeurs de la langue source, indexees par cle.
    static func charger() throws -> [String: String] {
        let catalogue = try chargerLeFichier()
        let langue = catalogue.sourceLanguage

        return catalogue.strings.compactMapValues { entree in
            entree.localizations?[langue]?.stringUnit.value
        }
    }

    /// Code de la langue dans laquelle les libelles sont rediges d abord.
    static func langueSource() throws -> String {
        try chargerLeFichier().sourceLanguage
    }

    /// Toutes les traductions, indexees par cle puis par code de langue.
    ///
    /// Une cle sans aucune traduction figure avec un dictionnaire vide plutot
    /// que d etre absente : c est ce qui permet au controle de completude de
    /// nommer la cle fautive au lieu de rendre un compte qui ne tombe pas juste.
    static func chargerToutesLesLangues() throws -> [String: [String: UniteDeChaine]] {
        try chargerLeFichier().strings.mapValues { entree in
            (entree.localizations ?? [:]).mapValues(\.stringUnit)
        }
    }

    /// Catalogue decode, ou l echec de lecture qui l a empeche.
    ///
    /// La valeur passe par un `static let`, dont Swift garantit l initialisation
    /// unique et sure meme si plusieurs suites la demandent en parallele.
    /// L erreur est retenue plutot que jetee ici, pour que le test qui demande
    /// le catalogue echoue avec la cause, et non sur une valeur absente.
    private static let lecture: Result<CatalogueXCStrings, EchecDeLectureDuCatalogue> = {
        do {
            let donnees = try Data(contentsOf: chemin)
            let catalogue = try JSONDecoder().decode(CatalogueXCStrings.self, from: donnees)

            return .success(catalogue)
        } catch {
            return .failure(EchecDeLectureDuCatalogue(chemin: chemin, cause: "\(error)"))
        }
    }()

    private static func chargerLeFichier() throws -> CatalogueXCStrings {
        try lecture.get()
    }
}

/// Le catalogue de l application n a pas pu etre lu ni decode.
struct EchecDeLectureDuCatalogue: Error, Sendable {
    let chemin: URL
    let cause: String
}

/// Une valeur traduite du catalogue, avec l etat que Xcode lui donne.
struct UniteDeChaine: Decodable, Sendable {
    let state: String
    let value: String
}

private struct CatalogueXCStrings: Decodable, Sendable {
    let sourceLanguage: String
    let strings: [String: EntreeDeCatalogue]
}

private struct EntreeDeCatalogue: Decodable, Sendable {
    let localizations: [String: LocalisationDeCatalogue]?
}

private struct LocalisationDeCatalogue: Decodable, Sendable {
    let stringUnit: UniteDeChaine
}
