import GRDB

/// Schema de la base et suite des migrations versionnees.
///
/// Chaque migration porte un identifiant date, comme l impose la section 3.3
/// du cahier de developpement. L ordre d enregistrement fait foi : une
/// migration deja publiee ne se renomme pas, ne se reordonne pas et ne se
/// modifie pas. Pour corriger une erreur, on en ajoute une nouvelle.
///
/// Aucune migration destructive n est enregistree ici sans sauvegarde
/// prealable automatique. Les migrations existantes se contentent de creer.
public enum SchemaDeBase {
    /// Identifiant de la migration qui cree le schema de la section 3.
    public static let creationDuSchema = "2026-08-24-01-creation-du-schema"

    /// Identifiant de la migration qui installe le reglage global de sens de
    /// lecture.
    ///
    /// La creation du schema etant deja publiee, elle n est pas modifiee : le
    /// reglage arrive par une migration supplementaire, purement additive.
    public static let reglageDeSensDeLecture = "2026-08-25-01-reglage-de-sens-de-lecture"

    /// Identifiant de la migration qui ajoute le total de chapitres par serie.
    ///
    /// Le filet de progression de la grille a besoin d une part, donc d un
    /// denominateur. Comme le nombre de non lus, il est denormalise et maintenu
    /// par declencheur, jamais calcule pendant le defilement.
    public static let totalDeChapitres = "2026-08-25-02-total-de-chapitres"

    /// Identifiant de la migration qui installe le filtre et le tri de la liste
    /// des chapitres, une ligne par serie.
    ///
    /// La fiche de serie de la section 5.6 de DESIGN-SPEC.md porte deux actions
    /// Filtrer et Trier dont le choix doit survivre a la fermeture de l ecran.
    /// Comme les precedentes, la migration est purement additive.
    public static let reglageDeListeDeChapitres = "2026-08-25-03-reglage-de-liste-de-chapitres"

    /// Identifiant de la migration qui ajoute le decalage de defilement a la
    /// position de reprise.
    ///
    /// La section 7.5 decrit une position en trois parties : le chapitre, la
    /// page, et le decalage de defilement des modes verticaux. Les deux
    /// premieres existent depuis la creation du schema, la troisieme arrive
    /// ici, sans rien detruire.
    public static let decalageDeDefilement = "2026-08-25-04-decalage-de-defilement"

    /// Identifiants de toutes les migrations, dans leur ordre d application.
    public static let migrationsAttendues = [
        creationDuSchema,
        reglageDeSensDeLecture,
        totalDeChapitres,
        reglageDeListeDeChapitres,
        decalageDeDefilement,
    ]

    /// Migrateur pret a appliquer, de la base vide a la version courante.
    public static func migrateur() -> DatabaseMigrator {
        var migrateur = DatabaseMigrator()

        migrateur.registerMigration(creationDuSchema) { base in
            try creerLesTablesDuCatalogue(base)
            try creerLesTablesDeBibliotheque(base)
            try creerLesTablesDeLecture(base)
            try creerLesIndexObligatoires(base)
            try creerLesDeclencheursDeNonLus(base)
        }

        migrateur.registerMigration(reglageDeSensDeLecture) { base in
            try creerLaTableDeReglageDeLecture(base)
        }

        migrateur.registerMigration(totalDeChapitres) { base in
            try ajouterLeTotalDeChapitres(base)
            try creerLesDeclencheursDeTotal(base)
        }

        migrateur.registerMigration(reglageDeListeDeChapitres) { base in
            try creerLaTableDeListeDeChapitres(base)
        }

        migrateur.registerMigration(decalageDeDefilement) { base in
            try ajouterLeDecalageDeDefilement(base)
        }

        return migrateur
    }
}
