/// Marqueur du paquet Storage.
///
/// Storage porte GRDB, le schema, les migrations versionnees et les requetes.
/// Le schema complet arrive avec la fonctionnalite F003.
public enum DomaineStorage {
    /// Nom du domaine, utilise par les diagnostics et par les tests de frontiere.
    public static let nom = "Storage"
}
