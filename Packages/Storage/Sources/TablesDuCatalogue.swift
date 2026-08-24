import GRDB

//
// TablesDuCatalogue
//
// Les quatre tables de tete de la section 3.1 : source, manga, chapitre, page.
// Une fonction par table, pour que le diff d une migration future reste lisible.
//

/// Cree source, manga, chapitre et page, dans cet ordre pour que chaque cle
/// etrangere pointe vers une table deja existante.
func creerLesTablesDuCatalogue(_ base: Database) throws {
    try creerLaTableSource(base)
    try creerLaTableManga(base)
    try creerLaTableChapitre(base)
    try creerLaTablePage(base)
}

private func creerLaTableSource(_ base: Database) throws {
    try base.create(table: "source") { table in
        table.primaryKey("id", .blob)
        table.column("type", .text).notNull()
        table.column("nom", .text).notNull()

        // Configuration de la source, chiffree, sans aucun identifiant de
        // connexion. Les mots de passe et les jetons vivent dans le trousseau.
        table.column("configurationChiffree", .blob)

        table.column("versionExtension", .text)
        table.column("langue", .text)
        table.column("ordreAffichage", .integer).notNull().defaults(to: 0)
        table.column("estActive", .boolean).notNull().defaults(to: true)
        table.column("dateDerniereVerification", .datetime)
        table.column("etatConnexion", .text).notNull().defaults(to: "nonVerifie")
    }
}

private func creerLaTableManga(_ base: Database) throws {
    try base.create(table: "manga") { table in
        table.primaryKey("id", .blob)
        table.column("sourceId", .blob).notNull()
            .indexed()
            .references("source", onDelete: .cascade)
        table.column("identifiantDistant", .text).notNull()
        table.column("titre", .text).notNull()

        // Listes encodees en JSON. Les sortir en tables de liaison couterait
        // quatre jointures sur le parcours le plus chaud de l application,
        // le defilement de la grille, pour des valeurs jamais interrogees
        // autrement que par serie.
        table.column("titresAlternatifs", .text).notNull().defaults(to: "[]")
        table.column("auteurs", .text).notNull().defaults(to: "[]")
        table.column("dessinateurs", .text).notNull().defaults(to: "[]")
        table.column("genres", .text).notNull().defaults(to: "[]")

        table.column("resume", .text)
        table.column("statut", .text).notNull().defaults(to: "inconnu")
        table.column("langue", .text)
        table.column("urlCouverture", .text)
        table.column("cheminCouvertureLocale", .text)

        // Sens de lecture impose a cette serie. Nul quand la serie suit le
        // reglage global. Jamais deduit a la lecture.
        table.column("sensLectureForce", .text)

        table.column("estDansBibliotheque", .boolean).notNull().defaults(to: false)
        table.column("dateAjout", .datetime).notNull()
        table.column("dateDerniereMiseAJour", .datetime)
        table.column("dateDerniereLecture", .datetime)

        // Compteur denormalise, maintenu par les declencheurs de
        // DeclencheursDeNonLus.swift. Aucun code applicatif ne l ecrit, et la
        // grille ne compte jamais les chapitres a la volee pendant le
        // defilement.
        table.column("chapitresNonLus", .integer).notNull().defaults(to: 0)

        table.uniqueKey(["sourceId", "identifiantDistant"])
    }
}

private func creerLaTableChapitre(_ base: Database) throws {
    try base.create(table: "chapitre") { table in
        table.primaryKey("id", .blob)
        table.column("mangaId", .blob).notNull()
            .references("manga", onDelete: .cascade)
        table.column("identifiantDistant", .text).notNull()

        // Numero decimal, les chapitres bonus portent des numeros comme 10.5.
        table.column("numero", .double).notNull()

        table.column("titre", .text)
        table.column("groupeTraduction", .text)
        table.column("langue", .text)
        table.column("datePublication", .datetime)
        table.column("nombrePages", .integer).notNull().defaults(to: 0)
        table.column("estLu", .boolean).notNull().defaults(to: false)
        table.column("pageAtteinte", .integer).notNull().defaults(to: 0)
        table.column("dateLecture", .datetime)

        // Rang reel dans la serie, distinct de numero, qui peut etre absent,
        // duplique ou incoherent selon la source.
        table.column("ordreDansSerie", .integer).notNull()

        table.uniqueKey(["mangaId", "identifiantDistant"])
    }
}

private func creerLaTablePage(_ base: Database) throws {
    try base.create(table: "page") { table in
        table.primaryKey("id", .blob)
        table.column("chapitreId", .blob).notNull()
            .references("chapitre", onDelete: .cascade)

        // index est un mot reserve de SQLite. GRDB entoure systematiquement
        // les identifiants de guillemets, le nom de la section 3.1 est donc
        // conserve tel quel.
        table.column("index", .integer).notNull()

        table.column("urlDistante", .text)
        table.column("cheminLocal", .text)
        table.column("largeur", .integer)
        table.column("hauteur", .integer)
        table.column("octets", .integer)

        table.uniqueKey(["chapitreId", "index"])
    }
}
