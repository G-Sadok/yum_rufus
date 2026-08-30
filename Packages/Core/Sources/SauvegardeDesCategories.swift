import Foundation

//
// SauvegardeDesCategories
//
// La part categories du fichier JSON versionne de la section 10 du cahier de
// developpement.
//
// Elle porte les onglets de la barre de la section 5.1 de DESIGN-SPEC.md et
// l appartenance des series a ces onglets. L onglet Tout n y figure pas : il n a
// pas de ligne en base, il ne peut donc ni s exporter ni se restaurer, et c est
// ce qui garantit qu un import ne le duplique jamais.
//

/// Une categorie telle qu elle figure dans une sauvegarde.
public struct CategorieExportee: Sendable, Codable, Hashable {
    public let id: UUID
    public let nom: String
    public let ordre: Int

    /// Projette une categorie vers sa forme exportable.
    public init(_ categorie: Categorie) {
        id = categorie.id
        nom = categorie.nom
        ordre = categorie.ordre
    }

    /// Reconstruit la categorie a partir de sa forme exportee.
    public func categorie() -> Categorie {
        Categorie(id: id, nom: nom, ordre: ordre)
    }
}

/// L appartenance d une serie a une categorie, telle qu elle figure dans une
/// sauvegarde.
public struct AppartenanceExportee: Sendable, Codable, Hashable {
    public let mangaId: UUID
    public let categorieId: UUID

    /// Projette une liaison vers sa forme exportable.
    public init(_ liaison: MangaCategorie) {
        mangaId = liaison.mangaId
        categorieId = liaison.categorieId
    }

    /// Reconstruit la liaison a partir de sa forme exportee.
    public func liaison() -> MangaCategorie {
        MangaCategorie(mangaId: mangaId, categorieId: categorieId)
    }
}

/// La part categories d une sauvegarde, versionnee.
public struct SauvegardeDesCategories: Sendable, Codable, Hashable {
    /// Version du format de la part categories.
    public static let versionCourante = 1

    public let version: Int
    public let categories: [CategorieExportee]
    public let appartenances: [AppartenanceExportee]

    public init(
        version: Int = SauvegardeDesCategories.versionCourante,
        categories: [CategorieExportee],
        appartenances: [AppartenanceExportee]
    ) {
        self.version = version
        self.categories = categories
        self.appartenances = appartenances
    }

    /// Construit la part categories a partir des entites persistees.
    public init(categories: [Categorie], appartenances: [MangaCategorie]) {
        self.init(
            categories: categories.map(CategorieExportee.init),
            appartenances: appartenances.map(AppartenanceExportee.init)
        )
    }

    /// Categories reconstruites, dans l ordre de la liste.
    public func categoriesRestaurees() -> [Categorie] {
        categories.map { $0.categorie() }
    }

    /// Liaisons reconstruites, dans l ordre de la liste.
    public func appartenancesRestaurees() -> [MangaCategorie] {
        appartenances.map { $0.liaison() }
    }

    /// Part vide, celle que la migration d une sauvegarde anterieure installe.
    public static let vide = SauvegardeDesCategories(categories: [], appartenances: [])
}
