import Core
import Foundation
import Testing

/// Couvre la pagination du protocole, cote appelant.
///
/// Trois choses sont verifiees, et ce sont les trois facons dont une grille de
/// catalogue se casse. Le parcours ramene tout quand il y a plusieurs pages.
/// Il s arrete quand la source ne pagine pas, au lieu de reclamer une page
/// suivante qu elle refusera. Et il s arrete quand la source promet une suite
/// qu elle ne sert pas, au lieu de tourner sans fin.
struct ParcoursDeCatalogueTests {
    // MARK: Enchainement des pages

    @Test("Le parcours enchaine les pages jusqu a la derniere")
    func enchainementDesPages() async throws {
        let source = SourceDeTest(nom: "Catalogue", series: .suiteDeTest(5), tailleDePage: 2)
        let parcours = ParcoursDeCatalogue(source: source, section: .tout)

        var tailles: [Int] = []
        var numeros: [Int] = []

        for try await page in parcours {
            tailles.append(page.elements.count)
            numeros.append(page.page)
        }

        #expect(tailles == [2, 2, 1])
        #expect(numeros == [0, 1, 2])
    }

    @Test("Le parcours ramene toutes les series du catalogue")
    func toutesLesSeries() async throws {
        let source = SourceDeTest(nom: "Catalogue", series: .suiteDeTest(5), tailleDePage: 2)
        let parcours = ParcoursDeCatalogue(source: source, section: .tout)
        let series = try await parcours.collecter(maximum: 100)

        #expect(series.map(\.titre) == (0..<5).map { "Serie \($0)" })
    }

    @Test("Un catalogue vide rend une page vide et s arrete")
    func catalogueVide() async throws {
        let source = SourceDeTest(nom: "Catalogue", series: [])
        let parcours = ParcoursDeCatalogue(source: source, section: .tout)

        var pages = 0

        for try await page in parcours {
            pages += 1
            #expect(page.elements.isEmpty)
        }

        #expect(pages == 1)
    }

    @Test("Le parcours peut reprendre a une page donnee")
    func repriseEnCoursDeCatalogue() async throws {
        let source = SourceDeTest(nom: "Catalogue", series: .suiteDeTest(5), tailleDePage: 2)
        let parcours = ParcoursDeCatalogue(source: source, section: .tout, depuis: 1)
        let series = try await parcours.collecter(maximum: 100)

        #expect(series.map(\.titre) == ["Serie 2", "Serie 3", "Serie 4"])
    }

    // MARK: Arret

    @Test("Une source qui ne pagine pas est interrogee une seule fois")
    func sourceSansPagination() async throws {
        // La source annonce une suite, mais elle ne declare pas la pagination :
        // lui demander la page 1 leverait `capaciteIndisponible`. Le parcours
        // s arrete donc apres la premiere page, et l ecran affiche ce qu il a.
        let source = SourceDeTest(
            nom: "Sans pagination",
            capacites: [.recherche],
            series: .suiteDeTest(5),
            tailleDePage: 2
        )
        let parcours = ParcoursDeCatalogue(source: source, section: .tout)

        var pages = 0

        for try await page in parcours {
            pages += 1
            #expect(page.elements.count == 2)
        }

        #expect(pages == 1)
        #expect(await source.nombreDAppels == 1)
    }

    @Test("Une source qui promet une suite sans jamais la servir ne fait pas tourner le parcours")
    func sourceQuiPromettraitSansFin() async throws {
        let source = SourceDeTest(
            nom: "Menteuse",
            series: .suiteDeTest(3),
            tailleDePage: 2,
            promettreUneSuiteSansFin: true
        )
        let parcours = ParcoursDeCatalogue(source: source, section: .tout)

        var pages = 0

        for try await _ in parcours {
            pages += 1

            #expect(pages <= 3, "le parcours ne s arrete pas")
        }

        // Deux pages pleines, puis une page vide qui arrete tout.
        #expect(pages == 3)
    }

    @Test("Le plafond de collecte est respecte")
    func plafondDeCollecte() async throws {
        let source = SourceDeTest(nom: "Catalogue", series: .suiteDeTest(10), tailleDePage: 2)
        let parcours = ParcoursDeCatalogue(source: source, section: .tout)
        let series = try await parcours.collecter(maximum: 3)

        #expect(series.count == 3)
        // Deux pages suffisent a atteindre le plafond, la source n est pas
        // interrogee cinq fois pour rien.
        #expect(await source.nombreDAppels == 2)
    }

    // MARK: Recherche

    @Test("Le parcours d une recherche conserve la requete et avance la page")
    func parcoursDeRecherche() async throws {
        let source = SourceDeTest(nom: "Catalogue", series: .suiteDeTest(5), tailleDePage: 2)
        let parcours = ParcoursDeCatalogue(source: source, recherche: RequeteRecherche(texte: "Serie"))
        let series = try await parcours.collecter(maximum: 100)

        #expect(series.count == 5)
    }

    @Test("Une recherche filtree par une source qui ne filtre pas remonte l erreur typee")
    func rechercheFiltreeRefusee() async throws {
        let source = SourceDeTest(nom: "Catalogue", capacites: [.recherche], series: .suiteDeTest(5))
        let requete = RequeteRecherche(texte: "Serie", filtres: FiltresDeRecherche(genres: ["action"]))
        let parcours = ParcoursDeCatalogue(source: source, recherche: requete)

        await #expect(throws: ErreurDeSource.capaciteIndisponible(capacite: .filtres, source: "Catalogue")) {
            _ = try await parcours.collecter(maximum: 100)
        }
    }

    // MARK: Erreurs et annulation

    @Test("Une panne de la source remonte telle quelle, sans etre avalee")
    func panneRemonte() async throws {
        let source = SourceDeTest(nom: "Catalogue", series: .suiteDeTest(5), panne: .transport(.timedOut))
        let parcours = ParcoursDeCatalogue(source: source, section: .tout)

        await #expect(throws: URLError.self) {
            _ = try await parcours.collecter(maximum: 100)
        }
    }

    @Test("L annulation arrete le parcours")
    func annulationArreteLeParcours() async throws {
        // La source muette ne repond que lorsque la tache est annulee. Le tour
        // suivant se heurte alors au controle d annulation du parcours.
        let source = SourceDeTest(
            nom: "Muette",
            series: .suiteDeTest(5),
            tailleDePage: 2,
            panne: .muette
        )
        let parcours = ParcoursDeCatalogue(source: source, section: .tout)

        let tache = Task { try await parcours.collecter(maximum: 100) }

        try await Task.sleep(for: .milliseconds(50))
        tache.cancel()

        await #expect(throws: CancellationError.self) {
            _ = try await tache.value
        }
    }
}
