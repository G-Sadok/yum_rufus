import Core
import GRDB

//
// TableDesReglages
//
// Reglages persistes qui ne se rattachent a aucune entite de la section 3.1.
// Pour l instant, le seul est le sens de lecture global.
//

/// Cree la table du reglage global de sens de lecture et y depose sa ligne.
///
/// La ligne est ecrite des la migration. Le sens de lecture global existe donc
/// toujours en base, meme sur une installation neuve, et aucune couche n a
/// jamais a le deviner faute de valeur.
func creerLaTableDeReglageDeLecture(_ base: Database) throws {
    try base.create(table: "reglageDeSensDeLecture") { table in
        // Reglage global, donc une seule ligne. La contrainte l impose a la
        // base plutot qu a la discipline de l appelant.
        table.primaryKey("id", .integer)
        table.check(sql: "id = \(ReglageDeSensDeLecture.identifiantDeLaLigneUnique)")

        table.column("sensGlobal", .text).notNull()
            .defaults(to: SensDeLecture.parDefaut.rawValue)
    }

    try ReglageDeSensDeLecture().insert(base)
}
