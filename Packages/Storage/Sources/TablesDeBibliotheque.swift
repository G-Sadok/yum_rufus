import GRDB

//
// TablesDeBibliotheque
//
// Categorie et ordreDeLecture, avec leurs tables de liaison.
//

/// Cree les tables de classement de la bibliotheque.
func creerLesTablesDeBibliotheque(_ base: Database) throws {
    try creerLaTableCategorie(base)
    try creerLaTableMangaCategorie(base)
    try creerLaTableOrdreDeLecture(base)
    try creerLaTableOrdreDeLectureChapitre(base)
}

private func creerLaTableCategorie(_ base: Database) throws {
    try base.create(table: "categorie") { table in
        table.primaryKey("id", .blob)
        table.column("nom", .text).notNull().unique()
        table.column("ordre", .integer).notNull().defaults(to: 0)
    }
}

private func creerLaTableMangaCategorie(_ base: Database) throws {
    try base.create(table: "mangaCategorie") { table in
        table.column("mangaId", .blob).notNull()
            .references("manga", onDelete: .cascade)
        table.column("categorieId", .blob).notNull()
            .indexed()
            .references("categorie", onDelete: .cascade)

        table.primaryKey(["mangaId", "categorieId"])
    }
}

private func creerLaTableOrdreDeLecture(_ base: Database) throws {
    try base.create(table: "ordreDeLecture") { table in
        table.primaryKey("id", .blob)
        table.column("nom", .text).notNull()

        // La section 3.1 nomme ce champ description. Le nom est ecarte cote
        // Swift parce que description appartient deja a tout type, et le
        // schema suit le modele pour qu une seule cle de codage suffise.
        table.column("descriptif", .text)
    }
}

private func creerLaTableOrdreDeLectureChapitre(_ base: Database) throws {
    try base.create(table: "ordreDeLectureChapitre") { table in
        table.column("ordreDeLectureId", .blob).notNull()
            .references("ordreDeLecture", onDelete: .cascade)
        table.column("chapitreId", .blob).notNull()
            .indexed()
            .references("chapitre", onDelete: .cascade)

        // La sequence est ordonnee, et deux chapitres ne partagent jamais le
        // meme rang dans un meme ordre de lecture.
        table.column("position", .integer).notNull()

        table.primaryKey(["ordreDeLectureId", "chapitreId"])
        table.uniqueKey(["ordreDeLectureId", "position"])
    }
}
