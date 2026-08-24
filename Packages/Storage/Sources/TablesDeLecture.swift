import GRDB

//
// TablesDeLecture
//
// Historique, signets, telechargements, prereglages et liaisons de suivi.
//

/// Cree les tables liees a l acte de lire et a sa restitution.
func creerLesTablesDeLecture(_ base: Database) throws {
    try creerLaTableEntreeHistorique(base)
    try creerLaTableSignet(base)
    try creerLaTableTelechargement(base)
    try creerLaTablePrereglageLecture(base)
    try creerLaTableLiaisonSuivi(base)
}

private func creerLaTableEntreeHistorique(_ base: Database) throws {
    try base.create(table: "entreeHistorique") { table in
        table.primaryKey("id", .blob)
        table.column("chapitreId", .blob).notNull()
            .indexed()
            .references("chapitre", onDelete: .cascade)
        table.column("dateLecture", .datetime).notNull()
        table.column("dureeSeconde", .integer).notNull().defaults(to: 0)
        table.column("pageAtteinte", .integer).notNull().defaults(to: 0)
    }
}

private func creerLaTableSignet(_ base: Database) throws {
    try base.create(table: "signet") { table in
        table.primaryKey("id", .blob)
        table.column("chapitreId", .blob).notNull()
            .references("chapitre", onDelete: .cascade)
        table.column("pageIndex", .integer).notNull()
        table.column("note", .text)
        table.column("dateCreation", .datetime).notNull()
        table.column("vignetteLocale", .text)

        // Un seul signet par page, un second appui retire le precedent.
        table.uniqueKey(["chapitreId", "pageIndex"])
    }
}

private func creerLaTableTelechargement(_ base: Database) throws {
    try base.create(table: "telechargement") { table in
        table.primaryKey("id", .blob)

        // Un chapitre n a qu une entree dans la file, sinon deux taches
        // ecriraient le meme dossier en parallele.
        table.column("chapitreId", .blob).notNull().unique()
            .references("chapitre", onDelete: .cascade)

        table.column("etat", .text).notNull().defaults(to: "enAttente")
        table.column("progression", .double).notNull().defaults(to: 0)
        table.column("octetsTotal", .integer)
        table.column("dateAjout", .datetime).notNull()
        table.column("messageErreur", .text)
    }
}

private func creerLaTablePrereglageLecture(_ base: Database) throws {
    try base.create(table: "prereglageLecture") { table in
        table.primaryKey("id", .blob)
        table.column("nom", .text).notNull().unique()

        // Reglages du lecteur encodes en JSON. Le format reste opaque a la
        // base pour que l ajout d un reglage n impose pas une migration.
        table.column("donneesReglages", .blob).notNull()
    }
}

private func creerLaTableLiaisonSuivi(_ base: Database) throws {
    try base.create(table: "liaisonSuivi") { table in
        table.primaryKey("id", .blob)
        table.column("mangaId", .blob).notNull()
            .references("manga", onDelete: .cascade)
        table.column("service", .text).notNull()
        table.column("identifiantDistant", .text).notNull()
        table.column("statut", .text).notNull().defaults(to: "enLecture")
        table.column("chapitreVu", .double).notNull().defaults(to: 0)
        table.column("note", .double)
        table.column("dateSynchronisation", .datetime)

        // Une serie ne se lie qu une fois a un service donne.
        table.uniqueKey(["mangaId", "service"])
    }
}
