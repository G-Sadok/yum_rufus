/// Marqueur du paquet DesignSystem.
///
/// DesignSystem est le seul paquet autorise a importer SwiftUI. Les jetons
/// issus de DESIGN-SPEC.md arrivent avec la fonctionnalite F002.
public enum DomaineDesignSystem {
    /// Nom du domaine, utilise par les diagnostics et par les tests de frontiere.
    public static let nom = "DesignSystem"
}
