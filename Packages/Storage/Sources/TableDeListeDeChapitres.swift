import Core
import Foundation
import GRDB

//
// TableDeListeDeChapitres
//
// Persistance du filtre et du tri de la liste des chapitres, section 5.6 de
// DESIGN-SPEC.md.
//
// Une ligne par serie, et aucune ligne tant que l utilisateur n a rien change.
// L absence de ligne vaut donc `ReglageDeListeDeChapitres.defaut`, ce qui evite
// d ecrire 5000 lignes identiques a la premiere ouverture de la bibliotheque.
//
// La cle primaire est la serie elle meme, ce qui interdit deux reglages
// concurrents pour une meme fiche et fait disparaitre le reglage avec la serie.
//

/// Cree la table du filtre et du tri par serie.
func creerLaTableDeListeDeChapitres(_ base: Database) throws {
    try base.create(table: "reglageDeListeDeChapitres") { table in
        table.primaryKey("mangaId", .blob)
            .references("manga", onDelete: .cascade)

        table.column("filtre", .text).notNull()
            .defaults(to: ReglageDeListeDeChapitres.defaut.filtre.rawValue)

        table.column("critereDeTri", .text).notNull()
            .defaults(to: ReglageDeListeDeChapitres.defaut.critere.rawValue)

        table.column("ordreDeTri", .text).notNull()
            .defaults(to: ReglageDeListeDeChapitres.defaut.ordre.rawValue)
    }
}

/// Ligne de la table, forme plate du reglage.
///
/// Le type de Core reste un objet de domaine a trois champs. C est ici, et
/// seulement ici, qu il apprend a quelle serie il se rattache et sous quels
/// noms de colonnes il s ecrit.
struct LigneDeReglageDeListe: Codable, Sendable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "reglageDeListeDeChapitres"

    var mangaId: UUID
    var filtre: FiltreDeChapitres
    var critereDeTri: CritereDeTriDeChapitres
    var ordreDeTri: OrdreDeTri

    init(mangaId: UUID, reglage: ReglageDeListeDeChapitres) {
        self.mangaId = mangaId
        filtre = reglage.filtre
        critereDeTri = reglage.critere
        ordreDeTri = reglage.ordre
    }

    /// Reglage de domaine porte par la ligne.
    var reglage: ReglageDeListeDeChapitres {
        ReglageDeListeDeChapitres(filtre: filtre, critere: critereDeTri, ordre: ordreDeTri)
    }
}
