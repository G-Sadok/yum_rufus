import Core
import Foundation
import Testing
@testable import Sources

//
// LectureOpdsTests
//
// Le premier critere de la fonctionnalite pris par son autre bout : un chapitre
// s ouvre, par les deux chemins que les catalogues OPDS offrent.
//
// Les deux chemins sont couverts parce que les deux existent chez des serveurs
// reels, et parce qu ils ne se ressemblent pas. La diffusion page par page rend
// des pages adressables et ne fait partir aucune requete a l enumeration. Le
// rapatriement rend des pages rangees dans un conteneur, qui ne s obtiennent pas
// par une requete du tout. Une couche qui traiterait les deux pareil casserait
// l une ou l autre.
//

struct LectureOpdsTests {
    // MARK: Diffusion page par page

    @Test("Un chapitre diffuse page par page est enumere sans aucune requete")
    func diffusionSansRequete() async throws {
        let catalogue = CatalogueOpdsDeTest(CatalogueOpdsDeTest.reglesCompletes())
        let source = try await catalogue.source()

        _ = try await source.chapitres(pour: identifiantDeLaSerieAtom)
        let avant = await catalogue.transport.journal.count
        let pages = try await source.pages(pour: identifiantDuPremierChapitre)
        let apres = await catalogue.transport.journal.count

        #expect(pages.count == 3)
        #expect(pages.map(\.index) == [0, 1, 2])
        #expect(pages.allSatisfy { $0.entree == nil })
        // Le catalogue a deja dit combien de pages et comment les adresser. Une
        // requete de plus ici serait une requete pour rien.
        #expect(apres == avant)
    }

    @Test("Une numerotation annoncee a partir de zero est respectee")
    func numerotationDepuisZero() async throws {
        let catalogue = CatalogueOpdsDeTest(CatalogueOpdsDeTest.reglesCompletes())
        let source = try await catalogue.source()

        _ = try await source.chapitres(pour: identifiantDeLaSerieAtom)
        let pages = try await source.pages(pour: identifiantDuPremierChapitre)
        let adresses = pages.map(\.emplacement.path)

        // Le gabarit annonce `zero_based=true`. Numeroter a partir de un
        // decalerait tout le chapitre et ferait manquer la derniere page.
        #expect(adresses == [
            "/opds/v1.2/books/1/pages/0",
            "/opds/v1.2/books/1/pages/1",
            "/opds/v1.2/books/1/pages/2",
        ])
    }

    @Test("Une numerotation par defaut commence a un")
    func numerotationDepuisUn() async throws {
        let catalogue = CatalogueOpdsDeTest(CatalogueOpdsDeTest.reglesCompletes())
        let source = try await catalogue.source(chemin: ReponsesFigeesDOpds.cheminDuCatalogueJson)

        _ = try await source.chapitres(pour: identifiantDeLaSerieJson)
        let pages = try await source.pages(pour: "https://opds.exemple.test/opds/v2/books/1/file")

        #expect(pages.map(\.emplacement.path) == [
            "/opds/v2/books/1/pages/1",
            "/opds/v2/books/1/pages/2",
            "/opds/v2/books/1/pages/3",
        ])
    }

    @Test("Les marqueurs de gabarit non completes disparaissent de l adresse")
    func gabaritResiduelRetire() async throws {
        let catalogue = CatalogueOpdsDeTest(CatalogueOpdsDeTest.reglesCompletes())
        let source = try await catalogue.source()

        _ = try await source.chapitres(pour: identifiantDeLaSerieAtom)
        let pages = try await source.pages(pour: identifiantDuPremierChapitre)
        let premiere = try #require(pages.first)
        let requete = premiere.emplacement.query() ?? ""

        // Le gabarit porte aussi `maxWidth`, que rien ne complete. L envoyer tel
        // quel donnerait au serveur une largeur nommee `maxWidth`.
        #expect(requete.contains("zero_based=true"))
        #expect(requete.contains("maxWidth") == false)
    }

    @Test("Une page diffusee se demande par une requete portant l identite")
    func requeteDePageDiffusee() async throws {
        let catalogue = CatalogueOpdsDeTest(CatalogueOpdsDeTest.reglesCompletes())
        let source = try await catalogue.source()

        _ = try await source.chapitres(pour: identifiantDeLaSerieAtom)
        let pages = try await source.pages(pour: identifiantDuPremierChapitre)
        let premiere = try #require(pages.first)
        let requete = try await source.requeteImage(pour: premiere)

        #expect(requete.url == premiere.emplacement)
        #expect(requete.value(forHTTPHeaderField: "Authorization") == CatalogueOpdsDeTest.enteteBasique)
    }

    // MARK: Rapatriement du conteneur

    @Test("Un chapitre sans diffusion est rapatrie puis lu comme un conteneur")
    func rapatriementDuConteneur() async throws {
        let cache = try ArbreDeTest(nom: "cache-opds")
        let catalogue = try CatalogueOpdsDeTest(
            CatalogueOpdsDeTest.reglesCompletes(conteneur: conteneurDeTest())
        )
        let source = try await catalogue.source(dossierDeCache: cache.racine)

        _ = try await source.chapitres(pour: identifiantDeLaSerieAtom)
        let pages = try await source.pages(pour: identifiantDuSecondChapitre)

        #expect(pages.map(\.entree) == ReponsesFigeesDOpds.pagesDuSecondChapitre)
        #expect(pages.map(\.index) == [0, 1])
        #expect(pages.allSatisfy { $0.emplacement.path.hasPrefix(cache.racine.path) })
    }

    @Test("Une page rangee dans un conteneur ne s obtient pas par une requete")
    func pageDeConteneurNonAdressable() async throws {
        let cache = try ArbreDeTest(nom: "cache-opds")
        let catalogue = try CatalogueOpdsDeTest(
            CatalogueOpdsDeTest.reglesCompletes(conteneur: conteneurDeTest())
        )
        let source = try await catalogue.source(dossierDeCache: cache.racine)

        _ = try await source.chapitres(pour: identifiantDeLaSerieAtom)
        let pages = try await source.pages(pour: identifiantDuSecondChapitre)
        let premiere = try #require(pages.first)

        await #expect(throws: ErreurDeSource.self) {
            _ = try await source.requeteImage(pour: premiere)
        }
    }

    @Test("Un conteneur deja range est relu apres un redemarrage, sans requete")
    func conteneurRelisibleApresRedemarrage() async throws {
        let cache = try ArbreDeTest(nom: "cache-opds")
        let catalogue = try CatalogueOpdsDeTest(
            CatalogueOpdsDeTest.reglesCompletes(conteneur: conteneurDeTest())
        )
        let premiere = try await catalogue.source(dossierDeCache: cache.racine)

        _ = try await premiere.chapitres(pour: identifiantDeLaSerieAtom)
        _ = try await premiere.pages(pour: identifiantDuSecondChapitre)
        let avant = await catalogue.transport.journal.count

        // Une source neuve sur le meme cache, ce qu est un lancement suivant :
        // rien n est retenu en memoire, ni le flux de la serie ni le format du
        // chapitre. Le conteneur range doit malgre tout etre retrouve et lu.
        let seconde = try await catalogue.source(dossierDeCache: cache.racine)
        let pages = try await seconde.pages(pour: identifiantDuSecondChapitre)

        #expect(pages.map(\.entree) == ReponsesFigeesDOpds.pagesDuSecondChapitre)
        #expect(await catalogue.transport.journal.count == avant)
    }

    @Test("Un conteneur vide est refuse plutot que range dans le cache")
    func conteneurVideRefuse() async throws {
        let cache = try ArbreDeTest(nom: "cache-opds")
        let catalogue = CatalogueOpdsDeTest(CatalogueOpdsDeTest.reglesCompletes())
        let source = try await catalogue.source(dossierDeCache: cache.racine)

        _ = try await source.chapitres(pour: identifiantDeLaSerieAtom)

        await #expect(throws: ErreurDeSource.self) {
            _ = try await source.pages(pour: identifiantDuSecondChapitre)
        }
    }

    @Test("Vider le cache efface les conteneurs et oublie les pages")
    func videCacheEffaceTout() async throws {
        let cache = try ArbreDeTest(nom: "cache-opds")
        let catalogue = try CatalogueOpdsDeTest(
            CatalogueOpdsDeTest.reglesCompletes(conteneur: conteneurDeTest())
        )
        let source = try await catalogue.source(
            dossierDeCache: cache.racine.appending(path: "conteneurs")
        )

        _ = try await source.chapitres(pour: identifiantDeLaSerieAtom)
        _ = try await source.pages(pour: identifiantDuSecondChapitre)
        let avant = await catalogue.transport.journal.count

        try await source.viderLeCache()
        _ = try await source.pages(pour: identifiantDuSecondChapitre)

        // Le conteneur a disparu du cache, il repart donc en requete.
        #expect(await catalogue.transport.journal.count > avant)
    }

    // MARK: Outils

    private func conteneurDeTest() throws -> Data {
        let entrees = ReponsesFigeesDOpds.pagesDuSecondChapitre.map { nom in
            EntreeDeZipDeTest(nom: nom, contenu: Data(repeating: 0x2A, count: 24))
        }

        return ConstructeurDeZipDeTest.octets(entrees)
    }

    private var identifiantDeLaSerieAtom: String {
        "https://opds.exemple.test/" + ReponsesFigeesDOpds.cheminDeLaSerieAtom
    }

    private var identifiantDeLaSerieJson: String {
        "https://opds.exemple.test/" + ReponsesFigeesDOpds.cheminDeLaSerieJson
    }

    private var identifiantDuPremierChapitre: String {
        "https://opds.exemple.test/" + ReponsesFigeesDOpds.cheminDuFichierDuPremierChapitre
    }

    private var identifiantDuSecondChapitre: String {
        "https://opds.exemple.test/" + ReponsesFigeesDOpds.cheminDuFichierDuSecondChapitre
    }
}
