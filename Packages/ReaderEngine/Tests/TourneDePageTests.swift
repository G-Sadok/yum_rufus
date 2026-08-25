import Core
import Foundation
import ImagePipeline
import Testing
@testable import ReaderEngine

/// Mesure la tourne de page en local contre le budget de 80 ms de la section 12.
///
/// La mesure porte sur le chemin reel : vraies pages de 3000 par 4500 encodees
/// en JPEG, vrai decodeur sous echantillonne, vrai cache memoire, precharge en
/// marche. Un test qui remplacerait l un de ces trois elements par un double ne
/// mesurerait plus rien de ce que l utilisateur ressent.
struct TourneDePageTests {
    private let zone = TailleEnPixels(largeur: 1600, hauteur: 2400)

    @Test("La tourne de page reste sous 80 ms quand la voisine est prechargee")
    func tourneDePageSousLeBudget() async throws {
        let octets = PageDecodeeDeTest.scanStandard
        #expect(octets.isEmpty == false)

        let fournisseur = FournisseurDeTest(nombreDePages: 12, octets: octets)
        let cache = CacheMemoireDePages()
        let moteur = PrechargeDesPagesVoisines(
            fournisseur: fournisseur,
            cache: cache,
            reglages: ReglagesDePrecharge(zone: zone)
        )

        // Ouverture du chapitre, hors budget de tourne de page : la section 12
        // lui accorde 350 ms et non 80.
        _ = try await moteur.pageVisible(0)
        await moteur.deplacerVers(0)

        var mesures: [Duration] = []

        for index in 1...4 {
            let cle = ClePage(chapitre: fournisseur.chapitre, index: index)

            #expect(await Attente.jusqua { await cache.contient(cle) }, "page \(index) jamais prechargee")

            let debut = ContinuousClock.now
            _ = try await moteur.pageVisible(index)
            mesures.append(ContinuousClock.now - debut)

            await moteur.deplacerVers(index)
        }

        for (rang, mesure) in mesures.enumerated() {
            #expect(mesure < .milliseconds(80), "tourne vers la page \(rang + 1) en \(mesure)")
        }

        await moteur.arreter()
    }

    @Test("Un retour en arriere reste sous 80 ms, la page precedente etant prechargee")
    func retourEnArriereSousLeBudget() async throws {
        let octets = PageDecodeeDeTest.scanStandard
        #expect(octets.isEmpty == false)

        let fournisseur = FournisseurDeTest(nombreDePages: 12, octets: octets)
        let cache = CacheMemoireDePages()
        let moteur = PrechargeDesPagesVoisines(
            fournisseur: fournisseur,
            cache: cache,
            reglages: ReglagesDePrecharge(zone: zone)
        )

        _ = try await moteur.pageVisible(5)
        await moteur.deplacerVers(5)

        let precedente = ClePage(chapitre: fournisseur.chapitre, index: 4)
        #expect(await Attente.jusqua { await cache.contient(precedente) }, "page precedente jamais prechargee")

        let debut = ContinuousClock.now
        _ = try await moteur.pageVisible(4)
        let duree = ContinuousClock.now - debut

        #expect(duree < .milliseconds(80), "retour en arriere en \(duree)")

        await moteur.arreter()
    }
}
