import GRDB

//
// TotalDeChapitres
//
// Second compteur denormalise de la table manga.
//
// Le filet de progression de la section 3 de DESIGN-SPEC.md est proportionnel a
// la part de chapitres lus. Il lui faut donc un total en plus du nombre de non
// lus deja tenu par les declencheurs de IndexEtDeclencheurs.swift. Compter les
// chapitres d une serie pendant le defilement de la grille est exactement
// l erreur que la section 17 du cahier de developpement place en cinquieme
// position, et elle couterait ici une agregation par vignette.
//

/// Ajoute `manga.chapitresTotal` et le renseigne pour les series deja en base.
///
/// L unique COUNT du fichier tourne ici, une fois, pendant la migration. La
/// grille, elle, ne compte jamais.
func ajouterLeTotalDeChapitres(_ base: Database) throws {
    try base.alter(table: "manga") { table in
        table.add(column: "chapitresTotal", .integer).notNull().defaults(to: 0)
    }

    try base.execute(sql: """
    UPDATE manga SET chapitresTotal = (
        SELECT COUNT(*) FROM chapitre WHERE chapitre.mangaId = manga.id
    );
    """)
}

/// Installe les declencheurs qui tiennent `manga.chapitresTotal` a jour.
///
/// Trois evenements font bouger un total, la ou cinq font bouger le nombre de
/// non lus : un chapitre arrive, un chapitre part, un chapitre change de serie.
/// L etat de lecture ne le touche pas, ce qui evite ici la garde que les
/// declencheurs de non lus doivent porter.
func creerLesDeclencheursDeTotal(_ base: Database) throws {
    try base.execute(sql: """
    CREATE TRIGGER trg_total_insertion
    AFTER INSERT ON chapitre
    BEGIN
        UPDATE manga SET chapitresTotal = chapitresTotal + 1
        WHERE id = NEW.mangaId;
    END;

    CREATE TRIGGER trg_total_suppression
    AFTER DELETE ON chapitre
    BEGIN
        UPDATE manga SET chapitresTotal = chapitresTotal - 1
        WHERE id = OLD.mangaId;
    END;

    CREATE TRIGGER trg_total_changement_de_serie
    AFTER UPDATE OF mangaId ON chapitre
    WHEN OLD.mangaId <> NEW.mangaId
    BEGIN
        UPDATE manga SET chapitresTotal = chapitresTotal - 1
        WHERE id = OLD.mangaId;

        UPDATE manga SET chapitresTotal = chapitresTotal + 1
        WHERE id = NEW.mangaId;
    END;
    """)
}
