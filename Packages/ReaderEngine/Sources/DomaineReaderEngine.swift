/// Marqueur du paquet ReaderEngine.
///
/// ReaderEngine porte la pagination, le tuilage et la precharge. Il ignore
/// tout de SwiftUI, la couche vue s abonne a ses etats.
public enum DomaineReaderEngine {
    /// Nom du domaine, utilise par les diagnostics et par les tests de frontiere.
    public static let nom = "ReaderEngine"
}
