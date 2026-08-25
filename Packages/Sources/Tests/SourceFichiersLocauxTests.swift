import Core
import Foundation
import Testing
@testable import Sources

/// Ce que la source rend une fois le dossier analyse : series, chapitres,
/// pages, et refus nets quand la demande ne correspond a rien.
struct SourceFichiersLocauxTests {
    private static let nom = EnvironnementDeSource.nomDeLaSource

    // MARK: Series et chapitres

    @Test("Le detail d une serie reprend son titre et son nombre de chapitres")
    func detailDUneSerie() async throws {
        try await avecBibliotheque { source in
            let serie = try await source.detailsManga("Serie A")

            #expect(serie.titre == "Serie A")
            #expect(serie.nombreChapitres == 3)
        }
    }

    @Test("Une serie inconnue est refusee")
    func serieInconnue() async throws {
        try await avecBibliotheque { source in
            await #expect(throws: ErreurDeSource.mangaIntrouvable(identifiant: "Serie Z")) {
                _ = try await source.detailsManga("Serie Z")
            }
        }
    }

    @Test("Les chapitres sont rendus dans l ordre de lecture")
    func chapitresOrdonnes() async throws {
        try await avecBibliotheque { source in
            let chapitres = try await source.chapitres(pour: "Serie A")

            #expect(chapitres.map(\.titre) == ["Chapitre 1", "Chapitre 2", "Chapitre 10"])
            #expect(chapitres.map(\.ordre) == [0, 1, 2])
            #expect(chapitres.map(\.numero) == [1, 2, 10])
            #expect(chapitres.allSatisfy { $0.identifiantManga == "Serie A" })
        }
    }

    // MARK: Pages

    @Test("Les pages d une archive sont triees naturellement et nomment leur entree")
    func pagesDUneArchive() async throws {
        try await avecBibliotheque { source in
            let pages = try await source.pages(pour: "Serie A/Chapitre 1.cbz")

            #expect(pages.map(\.entree) == ["page1.jpg", "page2.jpg", "page10.jpg"])
            #expect(pages.map(\.index) == [0, 1, 2])
            #expect(pages.map(\.estDansUnConteneur) == [true, true, true])
            #expect(pages.allSatisfy { $0.emplacement.lastPathComponent == "Chapitre 1.cbz" })
        }
    }

    @Test("Les pages d un dossier d images sont des fichiers, sans entree")
    func pagesDUnDossier() async throws {
        try await avecBibliotheque { source in
            let pages = try await source.pages(pour: "Serie B/Ch 01")

            #expect(pages.map(\.emplacement.lastPathComponent) == ["page1.jpg", "page2.jpg"])
            #expect(pages.allSatisfy { $0.entree == nil })
            #expect(pages.allSatisfy { ($0.octets ?? 0) > 0 })
        }
    }

    @Test("Un chapitre inconnu est refuse")
    func chapitreInconnu() async throws {
        try await avecBibliotheque { source in
            await #expect(throws: ErreurDeSource.chapitreIntrouvable(identifiant: "Serie A/Chapitre 99.cbz")) {
                _ = try await source.pages(pour: "Serie A/Chapitre 99.cbz")
            }
        }
    }

    @Test("Les pages d un chapitre en PDF sont enumerees comme celles d une archive")
    func pagesDUnPdf() async throws {
        let arbre = try ArbreDeTest()
        try arbre.pdf("Serie E/Chapitre 1.pdf", pages: 7)

        let environnement = try EnvironnementDeSource(arbre: arbre)
        let source = try environnement.sourcePremierLancement()
        let pages = try await source.pages(pour: "Serie E/Chapitre 1.pdf")

        #expect(pages.map(\.index) == Array(0..<7))
        #expect(pages.first?.entree == "page-0001")
        #expect(pages.map(\.estDansUnConteneur) == Array(repeating: true, count: 7))

        withExtendedLifetime(environnement) {}
    }

    @Test("Un PDF protege demande son mot de passe au lieu de se dire illisible")
    func pdfProtege() async throws {
        let arbre = try ArbreDeTest()
        let emplacement = try arbre.pdf("Serie E/Chapitre 2.pdf", pages: 3, motDePasse: "kokoro")

        let environnement = try EnvironnementDeSource(arbre: arbre)
        let source = try environnement.sourcePremierLancement()

        let erreur = await #expect(throws: ErreurDeDocument.self) {
            _ = try await source.pages(pour: "Serie E/Chapitre 2.pdf")
        }

        // Le cas est compare, pas le chemin en entier : la source travaille sur
        // le dossier tel que le systeme le lui a rendu, prefixe /private compris,
        // qui n est pas celui que l arbre de test a fabrique.
        guard case let .conteneurChiffre(chemin) = try #require(erreur) else {
            Issue.record("erreur inattendue : \(String(describing: erreur))")

            return
        }

        #expect(chemin.hasSuffix(emplacement.lastPathComponent))

        withExtendedLifetime(environnement) {}
    }

    @Test("Un format pas encore lisible nomme le format dans son refus")
    func formatNonLisible() async throws {
        let arbre = try ArbreDeTest()
        try arbre.fichier("Serie D/Chapitre 1.cbr", contenu: Data([0x52, 0x61, 0x72, 0x21]))

        let environnement = try EnvironnementDeSource(arbre: arbre)
        let source = try environnement.sourcePremierLancement()

        await #expect(
            throws: ErreurDeSource.formatNonPrisEnCharge(nom: "Chapitre 1", format: "cbr")
        ) {
            _ = try await source.pages(pour: "Serie D/Chapitre 1.cbr")
        }

        withExtendedLifetime(environnement) {}
    }

    // MARK: Requete image

    @Test("Une page posee sur le disque se demande par son fichier")
    func requeteSurUneImagePosee() async throws {
        try await avecBibliotheque { source in
            let page = try #require(await source.pages(pour: "Serie B/Ch 01").first)
            let requete = try await source.requeteImage(pour: page)

            #expect(requete.url == page.emplacement)
        }
    }

    @Test("Une page rangee dans une archive ne se demande pas par requete")
    func requeteSurUnePageDArchive() async throws {
        try await avecBibliotheque { source in
            let page = try #require(await source.pages(pour: "Serie A/Chapitre 1.cbz").first)

            await #expect(throws: ErreurDeSource.pageNonAdressableParRequete(entree: "page1.jpg")) {
                _ = try await source.requeteImage(pour: page)
            }
        }
    }

    // MARK: Analyse et actualisation

    @Test("Une analyse deja faite n est pas refaite tant qu on ne la relance pas")
    func analyseEnCache() async throws {
        let arbre = try ArbreDeTest()
        try BibliothequeDeTest.poser(dans: arbre)

        let environnement = try EnvironnementDeSource(arbre: arbre)
        let source = try environnement.sourcePremierLancement()

        _ = try await source.analyse()
        try arbre.archive("Serie A/Chapitre 11.cbz", pages: ["01.jpg"])

        let avant = try await source.chapitres(pour: "Serie A")
        let apres = try await source.reanalyser()

        #expect(avant.count == 3)
        #expect(apres.serie("Serie A")?.chapitres.count == 4)

        withExtendedLifetime(environnement) {}
    }

    @Test("Un dossier vide donne un catalogue vide, pas une erreur")
    func dossierVide() async throws {
        let arbre = try ArbreDeTest()
        let environnement = try EnvironnementDeSource(arbre: arbre)
        let source = try environnement.sourcePremierLancement()

        let catalogue = try await source.parcourir(.tout, page: 0)

        #expect(catalogue.elements.isEmpty)
        #expect(catalogue.ilResteDesPages == false)
        #expect(await source.verifierConnexion() == .connecte)

        withExtendedLifetime(environnement) {}
    }

    // MARK: Outils

    /// Voir `CapacitesDeSourceTests.avecBibliotheque` : l arbre doit rester en
    /// vie pendant tout le corps du test, sans quoi son dossier temporaire
    /// disparait sous les pieds de la source.
    private func avecBibliotheque(_ corps: (SourceFichiersLocaux) async throws -> Void) async throws {
        let arbre = try ArbreDeTest()
        try BibliothequeDeTest.poser(dans: arbre)

        let environnement = try EnvironnementDeSource(arbre: arbre)

        try await corps(environnement.sourcePremierLancement())

        withExtendedLifetime(environnement) {}
    }
}
