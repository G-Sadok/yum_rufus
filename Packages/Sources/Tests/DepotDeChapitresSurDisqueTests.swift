import Core
import Foundation
import Testing
@testable import Sources

//
// Couvre le depot sur disque, la ou la reprise se joue vraiment.
//
// Les tests ecrivent dans un vrai dossier temporaire. Un double en memoire
// prouverait la logique du depot mais pas ce qui compte ici : qu un fichier
// laisse a moitie ecrit par une coupure se distingue d une page complete quand
// le processus repart de zero, et que l inventaire ne le prenne pas pour elle.
//

struct DepotDeChapitresSurDisqueTests {
    /// Dossier temporaire vide, supprime a la fin du test.
    private func dossierDeTest() throws -> URL {
        let dossier = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("telechargements-\(UUID().uuidString)", isDirectory: true)

        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)

        return dossier
    }

    private func nettoyer(_ dossier: URL) {
        try? FileManager.default.removeItem(at: dossier)
    }

    // MARK: Inventaire

    @Test("Un chapitre jamais touche a un inventaire vierge")
    func inventaireDUnChapitreNeuf() async throws {
        let dossier = try dossierDeTest()

        defer { nettoyer(dossier) }

        let depot = DepotDeChapitresSurDisque(racine: dossier)

        #expect(try await depot.inventaire(du: UUID()) == .vierge)
    }

    @Test("L inventaire compte les pages scellees et le fragment de la suivante")
    func inventaireApresTroisPages() async throws {
        let dossier = try dossierDeTest()

        defer { nettoyer(dossier) }

        let depot = DepotDeChapitresSurDisque(racine: dossier)
        let chapitre = UUID()

        for page in 0..<3 {
            try await depot.ecrire(Data(repeating: 1, count: 100), page: page, du: chapitre, enPoursuivant: false)
            _ = try await depot.sceller(page: page, du: chapitre)
        }

        try await depot.ecrire(Data(repeating: 2, count: 42), page: 3, du: chapitre, enPoursuivant: false)

        let inventaire = try await depot.inventaire(du: chapitre)

        #expect(inventaire.pagesCompletes == 3)
        #expect(inventaire.octetsDuFragment == 42)
    }

    @Test("Un fragment n est jamais compte comme une page complete")
    func leFragmentNestPasUnePage() async throws {
        let dossier = try dossierDeTest()

        defer { nettoyer(dossier) }

        let depot = DepotDeChapitresSurDisque(racine: dossier)
        let chapitre = UUID()

        try await depot.ecrire(Data(repeating: 9, count: 500), page: 0, du: chapitre, enPoursuivant: false)

        let inventaire = try await depot.inventaire(du: chapitre)

        #expect(inventaire.pagesCompletes == 0, "Un fichier a moitie ecrit reste un fragment")
        #expect(inventaire.octetsDuFragment == 500)
    }

    // MARK: Ecriture et scellement

    @Test("Poursuivre un fragment ajoute les octets a la suite, sans les ecraser")
    func poursuiteDUnFragment() async throws {
        let dossier = try dossierDeTest()

        defer { nettoyer(dossier) }

        let depot = DepotDeChapitresSurDisque(racine: dossier)
        let chapitre = UUID()

        try await depot.ecrire(Data([1, 2, 3]), page: 0, du: chapitre, enPoursuivant: false)
        try await depot.ecrire(Data([4, 5]), page: 0, du: chapitre, enPoursuivant: true)

        let poids = try await depot.sceller(page: 0, du: chapitre)
        let fichier = depot.dossier(de: chapitre)
            .appendingPathComponent(DepotDeChapitresSurDisque.nomDePage(0))

        #expect(poids == 5)
        #expect(try Data(contentsOf: fichier) == Data([1, 2, 3, 4, 5]))
    }

    @Test("Ne pas poursuivre remplace le fragment, c est le cas du serveur qui ignore la tranche")
    func remplacementDUnFragment() async throws {
        let dossier = try dossierDeTest()

        defer { nettoyer(dossier) }

        let depot = DepotDeChapitresSurDisque(racine: dossier)
        let chapitre = UUID()

        try await depot.ecrire(Data([1, 2, 3]), page: 0, du: chapitre, enPoursuivant: false)
        try await depot.ecrire(Data([7]), page: 0, du: chapitre, enPoursuivant: false)

        #expect(try await depot.sceller(page: 0, du: chapitre) == 1)
    }

    @Test("Le scellement fait disparaitre le fragment")
    func leScellementConsommeLeFragment() async throws {
        let dossier = try dossierDeTest()

        defer { nettoyer(dossier) }

        let depot = DepotDeChapitresSurDisque(racine: dossier)
        let chapitre = UUID()

        try await depot.ecrire(Data([1]), page: 0, du: chapitre, enPoursuivant: false)
        _ = try await depot.sceller(page: 0, du: chapitre)

        let fragment = depot.dossier(de: chapitre)
            .appendingPathComponent(
                DepotDeChapitresSurDisque.nomDePage(0) + "." + DepotDeChapitresSurDisque.suffixeDeFragment
            )

        #expect(FileManager.default.fileExists(atPath: fragment.path) == false)
    }

    // MARK: Nommage

    @Test("Les zeros initiaux gardent l ordre du dossier aligne sur l ordre de lecture")
    func nomDePageGarni() {
        #expect(DepotDeChapitresSurDisque.nomDePage(0) == "page-0000")
        #expect(DepotDeChapitresSurDisque.nomDePage(2) == "page-0002")
        #expect(DepotDeChapitresSurDisque.nomDePage(10) == "page-0010")
        #expect(DepotDeChapitresSurDisque.nomDePage(1234) == "page-1234")

        // Le tri lexicographique du dossier suit le tri numerique, ce qui est
        // exactement le piege que le comparateur de tri naturel traite ailleurs.
        #expect(DepotDeChapitresSurDisque.nomDePage(2) < DepotDeChapitresSurDisque.nomDePage(10))
    }

    @Test("Un chapitre plus long que le garnissage garde un nom lisible")
    func nomDePageAuDelaDuGarnissage() {
        #expect(DepotDeChapitresSurDisque.nomDePage(12345) == "page-12345")
    }
}
