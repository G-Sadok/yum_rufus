import Foundation
import GRDB

/// Erreurs que l ouverture de la base peut remonter jusqu a l interface.
///
/// Chaque cas nomme la cause et indique la sortie, comme l exige la regle de
/// gestion d erreur du projet.
public enum ErreurDeBaseDeDonnees: Error, Sendable, Equatable {
    /// Le dossier qui doit accueillir le fichier de base n a pas pu etre cree.
    case dossierInaccessible(chemin: String)

    /// La sauvegarde prealable a une migration a echoue, la migration n a donc
    /// pas ete tentee et la base est restee dans son etat d origine.
    case sauvegardeImpossible(chemin: String)
}

/// Acces a la base de donnees, deja migree a la version courante.
///
/// L ouverture applique toujours la suite complete des migrations de
/// `SchemaDeBase`. Une base ouverte est donc toujours a jour, aucun appelant
/// n a a s en soucier.
public struct BaseDeDonnees: Sendable {
    /// Acces concurrent a la base. C est le seul point d entree des requetes.
    public let ecrivain: any DatabaseWriter

    /// Ouvre une base deja construite et la migre.
    ///
    /// - Parameters:
    ///   - ecrivain: file ou reservoir de connexions deja configure.
    ///   - sauvegarde: destination de la sauvegarde prealable. Quand elle est
    ///     fournie et que des migrations restent a appliquer, la base est
    ///     copiee la avant toute ecriture de schema.
    public init(ecrivain: any DatabaseWriter, sauvegardeAvantMigration sauvegarde: URL? = nil) throws {
        self.ecrivain = ecrivain

        let migrateur = SchemaDeBase.migrateur()

        if let sauvegarde, try Self.desMigrationsRestent(migrateur, sur: ecrivain) {
            try Self.sauvegarder(ecrivain, vers: sauvegarde)
        }

        try migrateur.migrate(ecrivain)
    }

    /// Ouvre une base en memoire, jetee a la fin du processus.
    ///
    /// Reservee aux tests et aux apercus. Rien de ce qui y est ecrit ne
    /// survit.
    public static func enMemoire() throws -> BaseDeDonnees {
        try BaseDeDonnees(ecrivain: DatabaseQueue())
    }

    /// Ouvre la base rangee a l emplacement indique, en creant le dossier
    /// parent au besoin.
    ///
    /// Une sauvegarde est deposee a cote du fichier avant toute migration
    /// restant a appliquer, comme l impose la section 3.3.
    public static func surDisque(a url: URL) throws -> BaseDeDonnees {
        let dossier = url.deletingLastPathComponent()

        do {
            try FileManager.default.createDirectory(
                at: dossier,
                withIntermediateDirectories: true
            )
        } catch {
            throw ErreurDeBaseDeDonnees.dossierInaccessible(chemin: dossier.path)
        }

        let reservoir = try DatabasePool(path: url.path)
        let sauvegarde = dossier.appendingPathComponent(
            url.deletingPathExtension().lastPathComponent + "-sauvegarde.sqlite"
        )

        return try BaseDeDonnees(ecrivain: reservoir, sauvegardeAvantMigration: sauvegarde)
    }

    /// Vrai quand au moins une migration enregistree n a pas encore ete
    /// appliquee a cette base.
    private static func desMigrationsRestent(
        _ migrateur: DatabaseMigrator,
        sur ecrivain: any DatabaseWriter
    ) throws -> Bool {
        try ecrivain.read { base in
            try migrateur.hasCompletedMigrations(base) == false
        }
    }

    /// Copie la base vers la destination indiquee avant de toucher au schema.
    ///
    /// Une sauvegarde precedente est remplacee : ce qui compte est de pouvoir
    /// revenir a l etat d avant la derniere migration, pas de conserver un
    /// historique.
    private static func sauvegarder(_ ecrivain: any DatabaseWriter, vers url: URL) throws {
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }

            let destination = try DatabaseQueue(path: url.path)
            try ecrivain.backup(to: destination)
        } catch {
            throw ErreurDeBaseDeDonnees.sauvegardeImpossible(chemin: url.path)
        }
    }
}
