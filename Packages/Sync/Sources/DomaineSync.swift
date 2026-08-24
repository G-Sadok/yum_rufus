/// Marqueur du paquet Sync.
///
/// Sync porte la couche CloudKit et le journal de changements. La
/// synchronisation est explicite, jamais un miroir automatique.
public enum DomaineSync {
    /// Nom du domaine, utilise par les diagnostics et par les tests de frontiere.
    public static let nom = "Sync"
}
