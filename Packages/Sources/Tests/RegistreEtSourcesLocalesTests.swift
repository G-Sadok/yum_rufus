import Core
import Foundation
import Testing
@testable import Sources

/// Reprend le deuxieme critere avec de vraies sources, et non des doublures.
///
/// Le registre est couvert dans Core avec une source pilotee par le test, ce
/// qui permet de fabriquer des pannes qu un dossier local ne produit pas. Ici
/// la panne est reelle : un dossier dont le signet n a jamais ete enregistre,
/// exactement ce qui arrive quand l utilisateur deplace son dossier entre deux
/// lancements. La source voisine doit continuer a servir son catalogue.
struct RegistreEtSourcesLocalesTests {
    @Test("Une source locale sans acces ne prive pas les autres de leur catalogue")
    func sourceSansAccesIsolee() async throws {
        let arbre = try ArbreDeTest()
        try BibliothequeDeTest.poser(dans: arbre)

        let environnement = try EnvironnementDeSource(arbre: arbre)
        let registre = RegistreDeSources()

        await registre.inscrire(environnement.sourceSansSignet())
        try await registre.inscrire(environnement.sourcePremierLancement())

        let recolte = await registre.parcourir(.tout)

        #expect(recolte.count == 2)
        #expect(recolte[0].aReussi == false)
        #expect(recolte[0].erreur?.etatDeConnexion == .injoignable)
        #expect(recolte[1].valeur?.elements.count == 4)

        withExtendedLifetime(environnement) {}
    }

    @Test("La verification de connexion distingue la source saine de celle qui a perdu son dossier")
    func verificationDeDeuxSourcesLocales() async throws {
        let arbre = try ArbreDeTest()
        try BibliothequeDeTest.poser(dans: arbre)

        let environnement = try EnvironnementDeSource(arbre: arbre)
        let registre = RegistreDeSources()

        try await registre.inscrire(environnement.sourcePremierLancement())
        await registre.inscrire(environnement.sourceSansSignet())

        let recolte = await registre.verifierToutes()

        #expect(recolte[0].valeur == .connecte)
        #expect(recolte[1].valeur == .injoignable)

        withExtendedLifetime(environnement) {}
    }

    @Test("Une section non servie par une source ne bloque pas celle qui la sert")
    func sectionRefuseeIsolee() async throws {
        let arbre = try ArbreDeTest()
        try BibliothequeDeTest.poser(dans: arbre)

        let environnement = try EnvironnementDeSource(arbre: arbre)
        let registre = RegistreDeSources()

        try await registre.inscrire(environnement.sourcePremierLancement())
        await registre.inscrire(SourceDeCatalogueComplet())

        let recolte = await registre.parcourir(.populaires)

        // Un dossier local ne mesure aucune popularite et le dit. La source qui
        // sait classer par popularite repond quand meme.
        #expect(recolte[0].erreur?.codeDeJournal == "source.sectionNonPriseEnCharge")
        #expect(recolte[1].valeur?.elements.count == 1)

        withExtendedLifetime(environnement) {}
    }

    @Test("Les actions offertes par la source locale sont celles de ses deux capacites")
    func actionsDeLaSourceLocale() throws {
        let arbre = try ArbreDeTest()
        try BibliothequeDeTest.poser(dans: arbre)

        let environnement = try EnvironnementDeSource(arbre: arbre)
        let source = try environnement.sourcePremierLancement()

        #expect(source.actionsOffertes.contains(.rechercher))
        #expect(source.actionsOffertes.contains(.chargerLaSuite))
        #expect(source.actionsOffertes.contains(.filtrer) == false)
        #expect(source.actionsOffertes.contains(.telecharger) == false)
        #expect(source.actionsOffertes.contains(.publierLaProgression) == false)
        #expect(source.actionsOffertes.contains(.choisirLaLangue) == false)
        #expect(source.actionsOffertes.isSuperset(of: ActionDeSource.inconditionnelles))

        withExtendedLifetime(environnement) {}
    }

    @Test("Le parcours pagine le catalogue reel jusqu au bout")
    func parcoursDuCatalogueReel() async throws {
        let arbre = try ArbreDeTest()
        try BibliothequeDeTest.poser(dans: arbre)

        let environnement = try EnvironnementDeSource(arbre: arbre)
        let source = try environnement.sourcePremierLancement(tailleDePage: 3)
        let parcours = ParcoursDeCatalogue(source: source, section: .tout)
        let series = try await parcours.collecter(maximum: 100)

        #expect(series.map(\.titre) == ["Serie A", "Serie B", "Serie C", "Tome unique"])

        withExtendedLifetime(environnement) {}
    }
}

/// Source minimale qui sert toutes les sections, y compris la popularite.
///
/// Elle existe pour prouver qu un refus de section reste local a la source qui
/// refuse. La source de fichiers locaux ne peut pas jouer ce role : elle refuse
/// la popularite par construction.
private struct SourceDeCatalogueComplet: SourceProvider {
    let id = SourceID()
    let nom = "Catalogue complet"
    let capacites: SourceCapacites = [.recherche, .pagination]

    private let serie = MangaDistant(identifiant: "unique", titre: "Serie populaire")

    func verifierConnexion() async -> EtatConnexion {
        .connecte
    }

    func rechercher(_ requete: RequeteRecherche) async throws -> PageResultats<MangaDistant> {
        try exiger(.recherche)

        return PageResultats(elements: [serie])
    }

    func parcourir(_ section: SectionCatalogue, page: Int) async throws -> PageResultats<MangaDistant> {
        PageResultats(elements: page == 0 ? [serie] : [])
    }

    func detailsManga(_ identifiant: String) async throws -> MangaDistant {
        serie
    }

    func chapitres(pour identifiant: String) async throws -> [ChapitreDistant] {
        []
    }

    func pages(pour chapitre: String) async throws -> [PageDistante] {
        []
    }

    func requeteImage(pour page: PageDistante) async throws -> URLRequest {
        URLRequest(url: page.emplacement)
    }
}
