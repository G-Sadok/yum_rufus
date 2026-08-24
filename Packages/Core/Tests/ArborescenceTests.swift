import Foundation
import Testing

/// Verifie que l organisation en paquets reste celle de la section 2.3 du
/// cahier de developpement, et que la frontiere d interface tient.
///
/// Ces tests lisent le disque plutot que le code compile, parce que la regle
/// porte sur l arborescence elle meme. Un module ajoute, renomme ou deplace
/// en douce fait virer la suite au rouge.
struct ArborescenceTests {
    /// Modules attendus sous `Packages/`, dans l ordre de la section 2.3.
    static let modulesAttendus = [
        "Core",
        "Storage",
        "Sources",
        "Archive",
        "ImagePipeline",
        "ReaderEngine",
        "Intelligence",
        "Sync",
        "DesignSystem",
    ]

    /// Entrees tolerees a la racine de `Packages/` en dehors des modules.
    static let entreesHorsModules = ["Package.swift", "Package.resolved"]

    static var racineDesPaquets: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // Core
            .deletingLastPathComponent() // Packages
    }

    @Test("Chaque module de la section 2.3 existe et porte des sources")
    func chaqueModuleExiste() throws {
        for module in Self.modulesAttendus {
            let sources = Self.racineDesPaquets
                .appendingPathComponent(module)
                .appendingPathComponent("Sources")

            var estUnDossier: ObjCBool = false
            let existe = FileManager.default.fileExists(
                atPath: sources.path,
                isDirectory: &estUnDossier
            )

            #expect(existe && estUnDossier.boolValue, "Dossier absent : \(module)/Sources")

            let fichiers = try FileManager.default
                .contentsOfDirectory(atPath: sources.path)
                .filter { $0.hasSuffix(".swift") }

            #expect(fichiers.isEmpty == false, "Aucune source Swift dans \(module)/Sources")
        }
    }

    @Test("Aucun module n est ajoute hors de la section 2.3")
    func aucunModuleInattendu() throws {
        let entrees = try FileManager.default.contentsOfDirectory(
            at: Self.racineDesPaquets,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        .map(\.lastPathComponent)
        .filter { Self.entreesHorsModules.contains($0) == false }

        let inattendus = Set(entrees).subtracting(Self.modulesAttendus)

        #expect(inattendus.isEmpty, "Entrees inattendues sous Packages : \(inattendus.sorted())")
    }

    @Test("Seul DesignSystem importe le framework d interface")
    func aucuneFuiteDInterface() throws {
        // Le marqueur est assemble a l execution pour que ce fichier ne se
        // signale pas lui meme, ni ici ni au controle 7 de verifications.sh.
        let marqueur = "import" + " SwiftUI"

        let fautifs = try Self.modulesAttendus
            .filter { $0 != "DesignSystem" }
            .flatMap { module -> [String] in
                try Self.sourcesSwift(dansLeModule: module)
                    .filter { try String(contentsOf: $0, encoding: .utf8).contains(marqueur) }
                    .map(\.path)
            }

        #expect(fautifs.isEmpty, "Fuite d interface dans un paquet metier : \(fautifs)")
    }

    /// Liste les fichiers Swift places sous `Sources` d un module.
    static func sourcesSwift(dansLeModule module: String) throws -> [URL] {
        let racine = racineDesPaquets
            .appendingPathComponent(module)
            .appendingPathComponent("Sources")

        guard let parcours = FileManager.default.enumerator(
            at: racine,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return parcours
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
    }
}
