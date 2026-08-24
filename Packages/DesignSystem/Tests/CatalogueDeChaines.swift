import Foundation

/// Lecture du catalogue de chaines de l application depuis le disque.
///
/// Le catalogue vit dans la cible `App/Yum`, qui n est pas compilee par Swift
/// Package Manager. Le lire ici est le seul moyen de verifier, dans la suite qui
/// tourne a chaque commit, que les libelles affiches sont bien ceux du tableau
/// 6.1 de DESIGN-SPEC.md, et dans le bon ordre.
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
        let donnees = try Data(contentsOf: chemin)
        let catalogue = try JSONDecoder().decode(CatalogueXCStrings.self, from: donnees)
        let langue = catalogue.sourceLanguage

        return catalogue.strings.compactMapValues { entree in
            entree.localizations?[langue]?.stringUnit.value
        }
    }
}

private struct CatalogueXCStrings: Decodable {
    let sourceLanguage: String
    let strings: [String: EntreeDeCatalogue]
}

private struct EntreeDeCatalogue: Decodable {
    let localizations: [String: LocalisationDeCatalogue]?
}

private struct LocalisationDeCatalogue: Decodable {
    let stringUnit: UniteDeChaine
}

private struct UniteDeChaine: Decodable {
    let value: String
}
