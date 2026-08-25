import Core
import Foundation
import Testing
@testable import ImagePipeline

/// Couvre les points trois et cinq de la section 6.1 : cache memoire LRU borne
/// a six pages ou 220 Mo, et alerte memoire qui vide tout sauf la page visible.
struct CacheMemoireDePagesTests {
    private let chapitre = UUID()

    // MARK: Plafond jamais depasse

    @Test("Vingt depots ne laissent jamais plus de six pages en cache")
    func plafondDePagesJamaisDepasse() async throws {
        let cache = CacheMemoireDePages()
        let page = try #require(ImageDeTest.page())

        for index in 0..<20 {
            await cache.deposer(page, pour: cle(index))

            // Verifie apres chaque depot, et non seulement a la fin. Un cache
            // qui gonflerait puis se degonflerait passerait un controle final.
            #expect(await cache.nombreDePages <= 6)
            #expect(await cache.octetsRetenus <= PlafondDeCacheMemoire.parDefaut.octets)
        }

        #expect(await cache.nombreDePages == 6)
    }

    @Test("Le plafond d octets borne avant le plafond de pages quand il tombe le premier")
    func plafondDOctetsJamaisDepasse() async throws {
        // Trois pages d un mebioctet tiennent, la quatrieme ferait deborder.
        let plafond = PlafondDeCacheMemoire(pages: 6, octets: 3_500_000)
        let cache = CacheMemoireDePages(plafond: plafond)
        let page = try #require(ImageDeTest.page())

        for index in 0..<10 {
            await cache.deposer(page, pour: cle(index))

            #expect(await cache.octetsRetenus <= plafond.octets)
            #expect(await cache.nombreDePages <= plafond.pages)
        }

        #expect(await cache.nombreDePages == 3)
        #expect(await cache.octetsRetenus == 3 * page.octetsEnMemoire)
    }

    @Test("Une page plus lourde que le plafond est refusee, pas retenue")
    func pageTropLourdeRefusee() async throws {
        let plafond = PlafondDeCacheMemoire(pages: 6, octets: 500_000)
        let cache = CacheMemoireDePages(plafond: plafond)
        let page = try #require(ImageDeTest.page())

        #expect(page.octetsEnMemoire > plafond.octets)
        #expect(await cache.deposer(page, pour: cle(0)) == false)
        #expect(await cache.nombreDePages == 0)
        #expect(await cache.octetsRetenus == 0)
    }

    @Test("Un refus n abandonne pas une version perimee de la meme page")
    func refusRetireLAncienneVersion() async throws {
        let plafond = PlafondDeCacheMemoire(pages: 6, octets: 3_500_000)
        let cache = CacheMemoireDePages(plafond: plafond)
        let petite = try #require(ImageDeTest.page(cote: 256))
        let enorme = try #require(ImageDeTest.page(cote: 1024))

        await cache.deposer(petite, pour: cle(0))
        #expect(await cache.deposer(enorme, pour: cle(0)) == false)

        #expect(await cache.contient(cle(0)) == false)
        #expect(await cache.octetsRetenus == 0)
    }

    @Test("Redeposer la meme cle remplace l entree au lieu de la compter deux fois")
    func redepotNeDoublePasLeCompte() async throws {
        let cache = CacheMemoireDePages()
        let page = try #require(ImageDeTest.page())

        await cache.deposer(page, pour: cle(0))
        await cache.deposer(page, pour: cle(0))

        #expect(await cache.nombreDePages == 1)
        #expect(await cache.octetsRetenus == page.octetsEnMemoire)
    }

    @Test("Le plafond tient sur des pages reellement decodees")
    func plafondSurDesPagesDecodees() async throws {
        let decodeur = DecodeurDePage()
        let zone = TailleEnPixels(largeur: 1600, hauteur: 2400)
        let cache = CacheMemoireDePages()

        for index in 0..<10 {
            let page = try decodeur.decoder(PageDeTest.standard, nom: "page-\(index).jpg", dans: zone)
            await cache.deposer(page, pour: cle(index))

            #expect(await cache.octetsRetenus <= PlafondDeCacheMemoire.parDefaut.octets)
        }

        #expect(await cache.nombreDePages == 6)

        // Dix pages retenues en pleine chaine peseraient plus de 500 Mo, six
        // pages bornees a 12 Mo en pesent moins de 72.
        #expect(await cache.octetsRetenus < 72_000_000)
        #expect(MesureDeMemoire.octets() < 400_000_000)
    }

    // MARK: Ordre d eviction

    @Test("La page la moins recemment lue part la premiere")
    func evictionDeLaMoinsRecente() async throws {
        let cache = CacheMemoireDePages(plafond: PlafondDeCacheMemoire(pages: 3, octets: 220_000_000))
        let page = try #require(ImageDeTest.page())

        for index in 0..<3 {
            await cache.deposer(page, pour: cle(index))
        }

        // La lecture de la page zero la remet en tete. La page un devient la
        // plus ancienne, c est donc elle que le depot suivant doit sacrifier.
        #expect(await cache.image(pour: cle(0)) != nil)
        await cache.deposer(page, pour: cle(3))

        #expect(await cache.contient(cle(0)))
        #expect(await cache.contient(cle(1)) == false)
        #expect(await cache.contient(cle(2)))
        #expect(await cache.contient(cle(3)))
    }

    @Test("La page visible n est pas evincee tant qu une autre peut l etre")
    func pageVisibleEpargneeParLEviction() async throws {
        let cache = CacheMemoireDePages(plafond: PlafondDeCacheMemoire(pages: 3, octets: 220_000_000))
        let page = try #require(ImageDeTest.page())

        for index in 0..<3 {
            await cache.deposer(page, pour: cle(index))
        }

        await cache.marquerVisible(cle(0))
        await cache.deposer(page, pour: cle(3))

        #expect(await cache.contient(cle(0)))
        #expect(await cache.contient(cle(1)) == false)
    }

    // MARK: Alerte memoire

    @Test("Une alerte memoire ne garde que la page visible")
    func alerteMemoireGardeLaPageVisible() async throws {
        let cache = CacheMemoireDePages()
        let page = try #require(ImageDeTest.page())

        for index in 0..<4 {
            await cache.deposer(page, pour: cle(index))
        }

        await cache.marquerVisible(cle(2))
        let liberes = await cache.reagirAUneAlerteMemoire()

        #expect(await cache.nombreDePages == 1)
        #expect(await cache.contient(cle(2)))
        #expect(await cache.octetsRetenus == page.octetsEnMemoire)
        #expect(liberes == 3 * page.octetsEnMemoire)
    }

    @Test("Sans page visible declaree, une alerte memoire vide tout")
    func alerteMemoireSansPageVisible() async throws {
        let cache = CacheMemoireDePages()
        let page = try #require(ImageDeTest.page())

        for index in 0..<4 {
            await cache.deposer(page, pour: cle(index))
        }

        await cache.reagirAUneAlerteMemoire()

        #expect(await cache.nombreDePages == 0)
        #expect(await cache.octetsRetenus == 0)
    }

    @Test("Une page visible sortie du cache ne fait pas survivre une autre page")
    func alerteMemoireAvecPageVisibleAbsente() async throws {
        let cache = CacheMemoireDePages()
        let page = try #require(ImageDeTest.page())

        await cache.deposer(page, pour: cle(0))
        await cache.marquerVisible(cle(9))
        await cache.reagirAUneAlerteMemoire()

        #expect(await cache.nombreDePages == 0)
    }

    @Test("Fermer le lecteur retire la protection de la page visible")
    func pageVisibleEffacee() async throws {
        let cache = CacheMemoireDePages()
        let page = try #require(ImageDeTest.page())

        await cache.deposer(page, pour: cle(0))
        await cache.marquerVisible(cle(0))
        await cache.marquerVisible(nil)
        await cache.reagirAUneAlerteMemoire()

        #expect(await cache.nombreDePages == 0)
    }

    @Test("Vider rend tous les octets, page visible comprise")
    func viderRendTout() async throws {
        let cache = CacheMemoireDePages()
        let page = try #require(ImageDeTest.page())

        await cache.deposer(page, pour: cle(0))
        await cache.marquerVisible(cle(0))
        await cache.vider()

        #expect(await cache.nombreDePages == 0)
        #expect(await cache.octetsRetenus == 0)
    }

    @Test("Retirer une page rend exactement ses octets")
    func retirerRendLesOctets() async throws {
        let cache = CacheMemoireDePages()
        let page = try #require(ImageDeTest.page())

        await cache.deposer(page, pour: cle(0))
        await cache.deposer(page, pour: cle(1))
        await cache.retirer(cle(0))

        #expect(await cache.nombreDePages == 1)
        #expect(await cache.octetsRetenus == page.octetsEnMemoire)

        await cache.retirer(cle(0))

        #expect(await cache.octetsRetenus == page.octetsEnMemoire)
    }

    private func cle(_ index: Int) -> ClePage {
        ClePage(chapitre: chapitre, index: index)
    }
}
