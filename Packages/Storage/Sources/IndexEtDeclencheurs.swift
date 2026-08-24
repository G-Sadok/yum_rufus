import GRDB

//
// IndexEtDeclencheurs
//
// Les quatre index obligatoires de la section 3.2, et les declencheurs qui
// maintiennent le compteur de chapitres non lus.
//

/// Cree les quatre index de la section 3.2, mot pour mot.
///
/// Ils sont ecrits en SQL et non avec le constructeur de GRDB pour deux
/// raisons. Le troisieme index porte un ordre descendant, et le second est un
/// index partiel : les exprimer en SQL garde le schema identique au cahier des
/// charges, donc verifiable a la lecture.
func creerLesIndexObligatoires(_ base: Database) throws {
    try base.execute(sql: """
    CREATE INDEX idx_chapitre_manga_ordre ON chapitre(mangaId, ordreDansSerie);
    CREATE INDEX idx_chapitre_non_lu ON chapitre(mangaId) WHERE estLu = 0;
    CREATE INDEX idx_manga_bibliotheque ON manga(estDansBibliotheque, dateDerniereLecture);
    CREATE INDEX idx_historique_date ON entreeHistorique(dateLecture DESC);
    """)
}

/// Installe les declencheurs qui tiennent `manga.chapitresNonLus` a jour.
///
/// Le compteur affiche sur chaque couverture ne doit jamais provenir d un
/// comptage a la volee pendant le defilement de la grille. Il est donc
/// denormalise dans `manga` et corrige ici a chaque ecriture sur `chapitre`.
///
/// Cinq declencheurs, parce que cinq evenements font bouger le compte : un
/// chapitre arrive, un chapitre part, un chapitre est marque lu, un chapitre
/// est remis non lu, un chapitre change de serie.
///
/// Les deux declencheurs sur `estLu` exigent que la serie n ait pas change
/// dans la meme instruction. Sans cette garde, un UPDATE qui touche a la fois
/// `estLu` et `mangaId` declencherait deux corrections pour un seul chapitre
/// et le compteur deriverait. Le cas est pris en charge par le dernier
/// declencheur, qui lit lui meme les deux anciennes et nouvelles valeurs.
func creerLesDeclencheursDeNonLus(_ base: Database) throws {
    try base.execute(sql: """
    CREATE TRIGGER trg_non_lus_insertion
    AFTER INSERT ON chapitre
    WHEN NEW.estLu = 0
    BEGIN
        UPDATE manga SET chapitresNonLus = chapitresNonLus + 1
        WHERE id = NEW.mangaId;
    END;

    CREATE TRIGGER trg_non_lus_suppression
    AFTER DELETE ON chapitre
    WHEN OLD.estLu = 0
    BEGIN
        UPDATE manga SET chapitresNonLus = chapitresNonLus - 1
        WHERE id = OLD.mangaId;
    END;

    CREATE TRIGGER trg_non_lus_marque_lu
    AFTER UPDATE OF estLu ON chapitre
    WHEN OLD.estLu = 0 AND NEW.estLu = 1 AND OLD.mangaId = NEW.mangaId
    BEGIN
        UPDATE manga SET chapitresNonLus = chapitresNonLus - 1
        WHERE id = NEW.mangaId;
    END;

    CREATE TRIGGER trg_non_lus_marque_non_lu
    AFTER UPDATE OF estLu ON chapitre
    WHEN OLD.estLu = 1 AND NEW.estLu = 0 AND OLD.mangaId = NEW.mangaId
    BEGIN
        UPDATE manga SET chapitresNonLus = chapitresNonLus + 1
        WHERE id = NEW.mangaId;
    END;

    CREATE TRIGGER trg_non_lus_changement_de_serie
    AFTER UPDATE OF mangaId ON chapitre
    WHEN OLD.mangaId <> NEW.mangaId
    BEGIN
        UPDATE manga
        SET chapitresNonLus = chapitresNonLus - (CASE WHEN OLD.estLu = 0 THEN 1 ELSE 0 END)
        WHERE id = OLD.mangaId;

        UPDATE manga
        SET chapitresNonLus = chapitresNonLus + (CASE WHEN NEW.estLu = 0 THEN 1 ELSE 0 END)
        WHERE id = NEW.mangaId;
    END;
    """)
}
