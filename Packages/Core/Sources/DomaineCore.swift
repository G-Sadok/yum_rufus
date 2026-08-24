/// Marqueur du paquet Core.
///
/// Core porte les modeles et les protocoles partages. Il ne depend d aucun
/// autre paquet, et aucun paquet ne peut se compiler sans lui.
public enum DomaineCore {
    /// Nom du domaine, utilise par les diagnostics et par les tests de frontiere.
    public static let nom = "Core"
}
