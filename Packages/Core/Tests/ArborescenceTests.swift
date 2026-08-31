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

    /// Outillage qui vit sous `Packages/` sans etre un module de la section 2.3.
    ///
    /// La regle de la section 2.3 porte sur les modules de l application : neuf,
    /// pas dix. `Performance` n en est pas un. Il porte les sept budgets de la
    /// section 12, le generateur du corpus de 5000 series et la campagne qui les
    /// mesure, et il vit ici parce que la campagne doit compiler contre le code
    /// reel de Storage, d Archive et du moteur de lecture, ce qu un paquet pose
    /// ailleurs ne saurait pas faire sans dupliquer le manifeste.
    ///
    /// La tolerance n est pas une parole donnee. Deux tests l encadrent :
    /// `outilHorsSection23NonExporte` verifie qu aucun produit de bibliotheque
    /// ne l expose, donc qu aucun code applicatif ne peut l importer, et
    /// `aucuneFuiteDInterface` le traite comme les neuf autres.
    static let outilsHorsSection23 = ["Performance"]

    /// Cible de l outillage de mesure, telle que le manifeste la nomme.
    static let cibleDeMesure = "BudgetsDePerformance"

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

        let inattendus = Set(entrees)
            .subtracting(Self.modulesAttendus)
            .subtracting(Self.outilsHorsSection23)

        #expect(inattendus.isEmpty, "Entrees inattendues sous Packages : \(inattendus.sorted())")
    }

    @Test("L outillage hors section 2.3 n est expose par aucun produit")
    func outilHorsSection23NonExporte() throws {
        let manifeste = try String(
            contentsOf: Self.racineDesPaquets.appendingPathComponent("Package.swift"),
            encoding: .utf8
        )

        let produitsFautifs = manifeste
            .split(separator: "\n")
            .filter { $0.contains(".library(") && $0.contains(Self.cibleDeMesure) }
            .map(String.init)

        #expect(produitsFautifs.isEmpty, "L outillage de mesure est expose en bibliotheque : \(produitsFautifs)")

        // Le garde ne vaut que si la cible existe encore sous ce nom. Sans cette
        // verification, un renommage rendrait le test vert en ne cherchant plus
        // rien.
        #expect(manifeste.contains("name: \"\(Self.cibleDeMesure)\""))
    }

    @Test("Seul DesignSystem importe le framework d interface")
    func aucuneFuiteDInterface() throws {
        // Le marqueur est assemble a l execution pour que ce fichier ne se
        // signale pas lui meme, ni ici ni au controle 7 de verifications.sh.
        let marqueur = "import" + " SwiftUI"

        let fautifs = try (Self.modulesAttendus + Self.outilsHorsSection23)
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
