import GRDB

//
// TableDesReglagesDeLApplication
//
// Table cle valeur des reglages de la section 5.5 de DESIGN-SPEC.md.
//
// Une table generique plutot qu une colonne par reglage, pour une raison
// precise : la section 5.5 compte cinquante deux lignes et le produit en
// gagnera d autres. Une colonne par ligne imposerait une migration par reglage
// ajoute, sur une table qui ne porte jamais plus d une cinquantaine de lignes
// et n est jamais jointe. Le cout du schema depasserait de loin son benefice.
//
// La table ne recoit aucune valeur a la migration. Le catalogue de `Core` porte
// les defauts, et une cle absente veut dire que la ligne n a jamais ete
// touchee. Semer les defauts ici les figerait au jour de la migration et
// laisserait les installations existantes sans les lignes ajoutees ensuite.
//

/// Cree la table cle valeur des reglages de l application.
func creerLaTableDesReglagesDeLApplication(_ base: Database) throws {
    try base.create(table: ReglagePersiste.databaseTableName) { table in
        table.primaryKey("cle", .text)
        table.column("valeur", .text).notNull()
    }
}

/// Une ligne de la table des reglages.
struct ReglagePersiste: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "reglageDeLApplication"

    /// Representation textuelle de l identifiant de reglage.
    var cle: String

    /// Forme persistee de la valeur, telle que `ValeurDeReglage` l ecrit.
    var valeur: String
}
