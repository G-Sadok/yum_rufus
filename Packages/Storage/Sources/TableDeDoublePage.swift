import Core
import GRDB

//
// TableDeDoublePage
//
// Persistance du decalage de couverture : une table d une seule ligne pour le
// reglage global, une colonne sur la serie pour la surcharge.
//

/// Cree la table du reglage global de decalage de couverture et y depose sa
/// ligne.
///
/// La ligne est ecrite des la migration, comme celle du sens de lecture. Le
/// decalage existe donc toujours en base, meme sur une installation neuve, et
/// aucune couche n a jamais a le deviner faute de valeur.
func creerLaTableDeDoublePage(_ base: Database) throws {
    try base.create(table: "reglageDeDoublePage") { table in
        // Reglage global, donc une seule ligne. La contrainte l impose a la
        // base plutot qu a la discipline de l appelant.
        table.primaryKey("id", .integer)
        table.check(sql: "id = \(ReglageDeDoublePage.identifiantDeLaLigneUnique)")

        table.column("decalageGlobal", .integer).notNull()
            .defaults(to: DecalageDeCouverture.parDefaut.rawValue)

        // La composition n a que deux formes, la periode des paires etant de
        // deux. Une troisieme valeur en base produirait une pagination que
        // personne ne sait relire, la base la refuse donc elle meme.
        table.check(sql: "decalageGlobal IN (0, 1)")
    }

    try ReglageDeDoublePage().insert(base)
}

/// Ajoute a la serie la surcharge de decalage de couverture.
///
/// La colonne est nullable et sans valeur par defaut : une serie qui n a jamais
/// ete reglee suit le reglage global, et rien ne distingue cet etat d une
/// surcharge posee puis retiree.
func ajouterLaSurchargeDeDecalage(_ base: Database) throws {
    try base.alter(table: "manga") { table in
        table.add(column: "decalageDeCouvertureForce", .integer)
    }
}
