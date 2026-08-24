import Core
import Foundation
import Testing
@testable import Sources

/// Couvre le deuxieme critere de la fonctionnalite : l analyse du dossier
/// detecte les series et les chapitres.
struct AnalyseDeDossierTests {
    // MARK: Series

    @Test("Les series sont detectees et triees selon l ordre naturel")
    func seriesDetectees() throws {
        let analyse = try analyserLaBibliotheque()

        #expect(analyse.series.map(\.titre) == ["Serie A", "Serie B", "Serie C", "Tome unique"])
    }

    @Test("Un dossier sans chapitre lisible n est pas une serie")
    func dossierVideIgnore() throws {
        let analyse = try analyserLaBibliotheque()

        #expect(analyse.serie("Dossier vide") == nil)
        #expect(analyse.series.contains { $0.titre == "notes" } == false)
    }

    @Test("L identifiant d une serie est son chemin relatif a la racine")
    func identifiantRelatif() throws {
        let analyse = try analyserLaBibliotheque()

        #expect(analyse.series.map(\.identifiant) == ["Serie A", "Serie B", "Serie C", "Tome unique.cbz"])
    }

    // MARK: Chapitres

    @Test("Les chapitres en archive sont detectes dans l ordre naturel")
    func chapitresEnArchive() throws {
        let serie = try #require(analyserLaBibliotheque().serie("Serie A"))

        #expect(serie.chapitres.map(\.titre) == ["Chapitre 1", "Chapitre 2", "Chapitre 10"])
        #expect(serie.chapitres.map(\.numero) == [1, 2, 10])
        #expect(serie.chapitres.map(\.ordre) == [0, 1, 2])
        #expect(serie.chapitres.allSatisfy { $0.forme == .archive(format: "cbz") })
    }

    @Test("Le nombre de pages d une archive n est pas connu de l analyse")
    func nombreDePagesInconnuEnArchive() throws {
        let serie = try #require(analyserLaBibliotheque().serie("Serie A"))

        #expect(serie.chapitres.allSatisfy { $0.nombrePages == nil })
    }

    @Test("Les chapitres en dossier d images sont detectes avec leur nombre de pages")
    func chapitresEnDossier() throws {
        let serie = try #require(analyserLaBibliotheque().serie("Serie B"))

        #expect(serie.chapitres.map(\.titre) == ["Ch 01", "Ch 02"])
        #expect(serie.chapitres.map(\.numero) == [1, 2])
        #expect(serie.chapitres.map(\.nombrePages) == [2, 1])
        #expect(serie.chapitres.allSatisfy { $0.forme == .dossierDImages })
    }

    @Test("Un dossier sans image n est pas un chapitre")
    func dossierSansImageIgnore() throws {
        let serie = try #require(analyserLaBibliotheque().serie("Serie B"))

        #expect(serie.chapitres.contains { $0.titre == "Notes" } == false)
    }

    @Test("Une serie faite d images posees a plat est son propre chapitre")
    func serieQuiEstSonChapitre() throws {
        let serie = try #require(analyserLaBibliotheque().serie("Serie C"))

        #expect(serie.chapitres.count == 1)
        #expect(serie.chapitres.first?.identifiant == "Serie C")
        #expect(serie.chapitres.first?.nombrePages == 2)
    }

    @Test("Une archive posee a la racine est une serie a un seul chapitre")
    func archiveIsolee() throws {
        let serie = try #require(analyserLaBibliotheque().serie("Tome unique.cbz"))

        #expect(serie.titre == "Tome unique")
        #expect(serie.chapitres.map(\.identifiant) == ["Tome unique.cbz"])
        #expect(serie.chapitres.first?.numero == 1)
    }

    // MARK: Parasites

    @Test("Les entrees parasites disparaissent de l analyse")
    func parasitesIgnores() throws {
        let serie = try #require(analyserLaBibliotheque().serie("Serie A"))

        #expect(serie.chapitres.count == 3)
        #expect(serie.chapitres.contains { $0.titre.contains("MACOSX") } == false)
        #expect(serie.chapitres.contains { $0.titre.hasPrefix(".") } == false)
    }

    // MARK: Formats

    @Test("Un format connu mais pas encore lisible reste liste comme chapitre")
    func formatConnuNonLisible() throws {
        let arbre = try ArbreDeTest()
        try arbre.fichier("Serie D/Chapitre 1.cbr", contenu: Data([0x52, 0x61, 0x72, 0x21]))

        let serie = try #require(
            AnalyseurDeDossier().analyser(arbre.racine, source: "test").serie("Serie D")
        )

        #expect(serie.chapitres.map(\.forme) == [.archive(format: "cbr")])
    }

    @Test("Un fichier d un format inconnu n est pas un chapitre")
    func formatInconnuIgnore() throws {
        let arbre = try ArbreDeTest()
        try arbre.fichier("Serie D/lisezmoi.txt", contenu: Data("texte".utf8))
        try arbre.image("Serie D/Chapitre 1/page1.jpg")

        let serie = try #require(
            AnalyseurDeDossier().analyser(arbre.racine, source: "test").serie("Serie D")
        )

        #expect(serie.chapitres.map(\.titre) == ["Chapitre 1"])
    }

    // MARK: Racine illisible

    @Test("Une racine qui n existe pas arrete l analyse")
    func racineIllisible() throws {
        let arbre = try ArbreDeTest()
        let absente = arbre.racine.appending(path: "nulle-part")

        #expect(throws: ErreurDeSource.sourceInjoignable(source: "test")) {
            _ = try AnalyseurDeDossier().analyser(absente, source: "test")
        }
    }

    @Test("Une analyse annulee ne rend pas de resultat")
    func analyseAnnulable() async throws {
        let arbre = try ArbreDeTest()
        try BibliothequeDeTest.poser(dans: arbre)

        let tache = Task {
            // L attente rend le test deterministe : le parcours ne commence
            // jamais avant que l annulation soit visible.
            while Task.isCancelled == false {
                await Task.yield()
            }

            return try AnalyseurDeDossier().analyser(arbre.racine, source: "test")
        }
        tache.cancel()

        await #expect(throws: CancellationError.self) {
            _ = try await tache.value
        }
    }

    // MARK: Outils

    private func analyserLaBibliotheque() throws -> AnalyseDeDossier {
        let arbre = try ArbreDeTest()
        try BibliothequeDeTest.poser(dans: arbre)

        return try AnalyseurDeDossier().analyser(arbre.racine, source: "test")
    }
}
