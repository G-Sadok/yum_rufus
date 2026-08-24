import Foundation
import GRDB

/// Ligne de la grille de bibliotheque, compteur de non lus compris.
///
/// Ce type existe pour une seule raison : la pastille de chapitres non lus
/// affichee sur chaque couverture se lit ici, dans une colonne deja calculee
/// par declencheur. Aucun COUNT ne tourne pendant le defilement.
///
/// La selection est volontairement etroite. Le resume, les genres et les
/// titres alternatifs sont du JSON qui ne sert pas a la grille, les charger
/// couterait un decodage par vignette.
public struct MangaDeGrille: Sendable, Codable, Hashable, Identifiable {
    public var id: UUID
    public var titre: String
    public var cheminCouvertureLocale: String?
    public var urlCouverture: String?
    public var dateDerniereLecture: Date?

    /// Nombre de chapitres non lus, denormalise dans la table `manga`.
    public var chapitresNonLus: Int

    public init(
        id: UUID,
        titre: String,
        cheminCouvertureLocale: String? = nil,
        urlCouverture: String? = nil,
        dateDerniereLecture: Date? = nil,
        chapitresNonLus: Int = 0
    ) {
        self.id = id
        self.titre = titre
        self.cheminCouvertureLocale = cheminCouvertureLocale
        self.urlCouverture = urlCouverture
        self.dateDerniereLecture = dateDerniereLecture
        self.chapitresNonLus = chapitresNonLus
    }
}

extension MangaDeGrille: TableRecord, FetchableRecord {
    public static let databaseTableName = "manga"

    /// Propriete calculee et non stockee : SQLSelectable n est pas Sendable,
    /// une constante statique deviendrait un etat global mutable partage que
    /// le mode strict de Swift 6 refuse, a juste titre.
    public static var databaseSelection: [any SQLSelectable] {
        [
            Column("id"),
            Column("titre"),
            Column("cheminCouvertureLocale"),
            Column("urlCouverture"),
            Column("dateDerniereLecture"),
            Column("chapitresNonLus"),
        ]
    }

    /// Series presentes dans la bibliotheque, la plus recemment lue en tete.
    ///
    /// Le tri et le filtre reposent tous deux sur `idx_manga_bibliotheque`.
    public static func enBibliotheque() -> QueryInterfaceRequest<MangaDeGrille> {
        MangaDeGrille
            .filter(Column("estDansBibliotheque") == true)
            .order(Column("dateDerniereLecture").desc)
    }
}
