import Core
import GRDB

//
// TableDeFileDeTelechargements
//
// Ce que la file de la section 4.11 de DESIGN-SPEC.md ajoute a la table
// `telechargement` de la section 3.1.
//
// La table existe depuis la creation du schema, avec les sept colonnes du
// cahier. Elles disent qu une tache avance, elles ne disent pas ou elle reprend
// ni dans quel ordre elle passe. La migration est purement additive, comme
// toutes celles qui l ont precedee : quatre colonnes avec une valeur par defaut,
// donc lisibles sur les lignes deja ecrites, et un index sur ce que le
// planificateur interroge.
//

/// Ajoute a la file la priorite et le point de reprise.
func ajouterLaRepriseEtLaPriorite(_ base: Database) throws {
    try base.alter(table: "telechargement") { table in
        table.add(column: "priorite", .text).notNull()
            .defaults(to: PrioriteDeTelechargement.parDefaut.rawValue)

        // Point de reprise du chapitre. Une tache interrompue relit ce compte
        // plutot que le dossier : le disque dit ce qui a ete ecrit, la base dit
        // ce qui a ete scelle, et seul le second est sur.
        table.add(column: "pagesTerminees", .integer).notNull().defaults(to: 0)

        // Longueur du chapitre. Zero tant que la source ne l a pas annoncee, ce
        // qui est l etat d une tache mise en file hors ligne.
        table.add(column: "nombreDePages", .integer).notNull().defaults(to: 0)

        table.add(column: "octetsRecus", .integer).notNull().defaults(to: 0)
    }
}

/// Cree l index dont le planificateur se sert a chaque tour de file.
///
/// Le planificateur lit la file entiere a chaque decision, filtre sur l etat
/// puis trie sur la priorite et la date. Sans index, ce tri est un balayage
/// complet, et il se produit a chaque page terminee de chaque tache.
func creerLIndexDeFileDeTelechargements(_ base: Database) throws {
    try base.create(
        index: "idx_telechargement_file",
        on: "telechargement",
        columns: ["etat", "priorite", "dateAjout"]
    )
}
