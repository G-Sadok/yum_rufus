import Foundation
import Testing
@testable import ImagePipeline

/// Source d alertes que le test declenche a la main.
///
/// La pression memoire du systeme ne se commande pas. Sans ce double, le chemin
/// qui va de l alerte au cache ne serait couvert par aucun test, et le critere
/// reposerait sur un appel direct a la reaction.
private actor SourceDAlerteSimulee: SourceDAlerteMemoire {
    private var reaction: (@Sendable () async -> Void)?
    private(set) var observations = 0
    private(set) var arrets = 0

    func observer(_ reaction: @escaping @Sendable () async -> Void) async {
        self.reaction = reaction
        observations += 1
    }

    func arreter() async {
        reaction = nil
        arrets += 1
    }

    /// Emet une alerte et attend que la reaction soit allee au bout.
    func declencher() async {
        await reaction?()
    }
}

/// Couvre le branchement des alertes memoire du systeme sur le cache.
struct VeilleDAlerteMemoireTests {
    private let chapitre = UUID()

    @Test("Une alerte du systeme vide le cache sauf la page visible")
    func alerteDuSystemeVideLeCache() async throws {
        let cache = CacheMemoireDePages()
        let source = SourceDAlerteSimulee()
        let veille = VeilleDAlerteMemoire(cache: cache, source: source)
        let image = try #require(ImageDeTest.page())

        for index in 0..<5 {
            await cache.deposer(image, pour: cle(index))
        }

        await cache.marquerVisible(cle(3))
        await veille.demarrer()
        await source.declencher()

        #expect(await cache.nombreDePages == 1)
        #expect(await cache.contient(cle(3)))
    }

    @Test("Tant que la veille n a pas demarre, rien n observe la memoire")
    func rienAvantLeDemarrage() async {
        let cache = CacheMemoireDePages()
        let source = SourceDAlerteSimulee()
        _ = VeilleDAlerteMemoire(cache: cache, source: source)

        #expect(await source.observations == 0)
    }

    @Test("Arreter la veille coupe la source")
    func arretCoupeLaSource() async throws {
        let cache = CacheMemoireDePages()
        let source = SourceDAlerteSimulee()
        let veille = VeilleDAlerteMemoire(cache: cache, source: source)
        let image = try #require(ImageDeTest.page())

        await veille.demarrer()
        await veille.arreter()
        await cache.deposer(image, pour: cle(0))
        await source.declencher()

        #expect(await source.arrets == 1)
        #expect(await cache.nombreDePages == 1)
    }

    @Test("Plusieurs alertes de suite ne cassent rien")
    func alertesRepetees() async throws {
        let cache = CacheMemoireDePages()
        let source = SourceDAlerteSimulee()
        let veille = VeilleDAlerteMemoire(cache: cache, source: source)
        let image = try #require(ImageDeTest.page())

        await cache.deposer(image, pour: cle(0))
        await cache.marquerVisible(cle(0))
        await veille.demarrer()

        for _ in 0..<3 {
            await source.declencher()
        }

        #expect(await cache.nombreDePages == 1)
        #expect(await cache.octetsRetenus == image.octetsEnMemoire)
    }

    private func cle(_ index: Int) -> ClePage {
        ClePage(chapitre: chapitre, index: index)
    }
}
