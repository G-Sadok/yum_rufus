import Foundation

//
// EntitesDeBibliotheque
//
// Categorie et OrdreDeLecture, avec leurs tables de liaison, d apres la
// section 3.1 du cahier de developpement.
//

/// Categorie de la bibliotheque, telle qu elle apparait en onglet dans la
/// grille. Une serie peut appartenir a plusieurs categories.
public struct Categorie: Sendable, Codable, Identifiable, Hashable {
    public var id: UUID
    public var nom: String

    /// Rang de l onglet dans la barre de categories.
    public var ordre: Int

    public init(id: UUID = UUID(), nom: String, ordre: Int = 0) {
        self.id = id
        self.nom = nom
        self.ordre = ordre
    }
}

/// Liaison entre une serie et une categorie.
public struct MangaCategorie: Sendable, Codable, Hashable {
    public var mangaId: UUID
    public var categorieId: UUID

    public init(mangaId: UUID, categorieId: UUID) {
        self.mangaId = mangaId
        self.categorieId = categorieId
    }
}

/// Sequence de lecture composee a la main, capable de traverser plusieurs
/// series. C est ce qui permet de lire un univers dans l ordre chronologique
/// plutot que serie par serie.
public struct OrdreDeLecture: Sendable, Codable, Identifiable, Hashable {
    public var id: UUID
    public var nom: String
    public var descriptif: String?

    public init(id: UUID = UUID(), nom: String, descriptif: String? = nil) {
        self.id = id
        self.nom = nom
        self.descriptif = descriptif
    }
}

/// Position d un chapitre dans un ordre de lecture.
public struct OrdreDeLectureChapitre: Sendable, Codable, Hashable {
    public var ordreDeLectureId: UUID
    public var chapitreId: UUID

    /// Rang du chapitre dans la sequence, indexe a partir de zero.
    public var position: Int

    public init(ordreDeLectureId: UUID, chapitreId: UUID, position: Int) {
        self.ordreDeLectureId = ordreDeLectureId
        self.chapitreId = chapitreId
        self.position = position
    }
}
