import Foundation

//
// MigrationDeSauvegarde
//
// Mise a niveau d un fichier de sauvegarde ecrit par une version anterieure de
// l application, avant tout decodage.
//
// La migration travaille sur l arbre JSON brut et non sur le type Swift, pour
// la meme raison qu une migration de base travaille en SQL et non sur les
// enregistrements. Un decodeur Swift ignore en silence ce qu il ne connait pas
// et invente les absents : brancher la compatibilite ascendante sur des champs
// optionnels rendrait indiscernables `la sauvegarde ne portait pas ce champ` et
// `la sauvegarde le portait mais il etait absent`. Ici, chaque etape dit
// explicitement ce qu elle ajoute, et le fichier remis a la version courante se
// decode ensuite par le chemin normal, sans aucun cas particulier.
//
// Les etapes sont ordonnees et cumulatives, comme les migrations de
// `SchemaDeBase`. Une etape publiee ne se modifie pas, on en ajoute une.
//
// La migration ne tourne que lorsque le fichier n est pas deja a la version
// courante. Un aller retour par `JSONSerialization` reecrit les nombres, et les
// dates de ce format sont des nombres : le chemin normal ne le prend pas.
//

/// Amene un fichier de sauvegarde a la version courante du format.
public enum MigrationDeSauvegarde {
    /// Premiere version du format que cette application sait encore relire.
    ///
    /// Une sauvegarde plus ancienne est refusee en le disant, jamais lue de
    /// travers.
    public static let premiereVersionLisible = 1

    /// Version annoncee par un fichier de sauvegarde.
    ///
    /// - Throws: `ErreurDeSauvegarde.fichierIllisible` quand les octets ne
    ///   decrivent pas un objet JSON portant une cle `version` entiere.
    public static func version(de donnees: Data) throws -> Int {
        guard let version = try racine(de: donnees)["version"] as? Int else {
            throw ErreurDeSauvegarde.fichierIllisible
        }

        return version
    }

    /// Rend le fichier remis a la version courante du format.
    ///
    /// - Throws: `ErreurDeSauvegarde.formatInconnu` quand la version est trop
    ///   ancienne pour etre encore migree, ou plus recente que celle que cette
    ///   application ecrit.
    public static func migrer(_ donnees: Data) throws -> Data {
        var document = try racine(de: donnees)
        var version = try Self.version(de: donnees)

        guard version >= premiereVersionLisible,
              version <= DocumentDeSauvegarde.versionCourante
        else {
            throw ErreurDeSauvegarde.formatInconnu(version: version)
        }

        while version < DocumentDeSauvegarde.versionCourante {
            document = etape(depuis: version, sur: document)
            version += 1
            document["version"] = version
        }

        guard let migre = try? JSONSerialization.data(
            withJSONObject: document,
            options: [.sortedKeys]
        ) else {
            throw ErreurDeSauvegarde.fichierIllisible
        }

        return migre
    }

    // MARK: Etapes

    /// Applique l etape qui mene de `version` a la suivante.
    private static func etape(depuis version: Int, sur document: [String: Any]) -> [String: Any] {
        switch version {
        case 1: deLaUnALaDeux(document)
        default: document
        }
    }

    /// Version 1 vers version 2 : arrivee de la bibliotheque, des categories et
    /// de la progression.
    ///
    /// La version 1 ne portait que les trois parts ecrites avant cette
    /// fonctionnalite, sources, signets et prereglages. Les trois parts qui
    /// arrivent sont donc installees vides : un fichier de version 1 ne dit rien
    /// des series, et supposer autre chose reviendrait a inventer des donnees
    /// que l utilisateur n a jamais sauvegardees.
    private static func deLaUnALaDeux(_ document: [String: Any]) -> [String: Any] {
        var migre = document

        migre["bibliotheque"] = [
            "version": SauvegardeDeLaBibliotheque.versionCourante,
            "series": [],
            "chapitres": [],
        ] as [String: Any]

        migre["categories"] = [
            "version": SauvegardeDesCategories.versionCourante,
            "categories": [],
            "appartenances": [],
        ] as [String: Any]

        migre["progression"] = [
            "version": SauvegardeDeLaProgression.versionCourante,
            "series": [],
            "chapitres": [],
        ] as [String: Any]

        return migre
    }

    // MARK: Lecture brute

    /// Relit l arbre JSON du fichier sans le decoder vers un type.
    private static func racine(de donnees: Data) throws -> [String: Any] {
        guard donnees.isEmpty == false,
              let objet = try? JSONSerialization.jsonObject(with: donnees),
              let racine = objet as? [String: Any]
        else {
            throw ErreurDeSauvegarde.fichierIllisible
        }

        return racine
    }
}
