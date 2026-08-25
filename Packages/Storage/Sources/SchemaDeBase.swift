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

    /// Identifiants de toutes les migrations, dans leur ordre d application.
    public static let migrationsAttendues = [
        creationDuSchema,
        reglageDeSensDeLecture,
        totalDeChapitres,
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

        return migrateur
    }
}
