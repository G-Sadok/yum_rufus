import Core
import Foundation
import ImagePipeline
import Testing
@testable import ReaderEngine

/// Couvre les trois criteres de la precharge : elle ne gene jamais la page
/// visible, elle s annule quand la page change, et elle laisse la tourne de
/// page dans son budget.
struct PrechargeDesPagesVoisinesTests {
    private let zone = TailleEnPixels(largeur: 1600, hauteur: 2400)

    // MARK: Ordre et remplissage de la file

    @Test("La file suit l ordre de priorite du plan")
    func ordreDeLaFile() async {
        let fournisseur = FournisseurDeTest(nombreDePages: 20, ouvert: false)
        let moteur = moteur(fournisseur: fournisseur, atelier: AtelierEspion(), cache: CacheMemoireDePages())

        await moteur.deplacerVers(5)

        #expect(await moteur.cleEnCours == cle(fournisseur, 6))
        #expect(await moteur.clesEnAttente == [cle(fournisseur, 7), cle(fournisseur, 4)])

        await moteur.arreter()
    }

    @Test("La precharge remplit le cache des voisines")
    func remplissageDuCache() async {
        let fournisseur = FournisseurDeTest(nombreDePages: 20)
        let cache = CacheMemoireDePages()
        let moteur = moteur(fournisseur: fournisseur, atelier: AtelierEspion(), cache: cache)

        await moteur.deplacerVers(5)

        let voisines = [cle(fournisseur, 6), cle(fournisseur, 7), cle(fournisseur, 4)]

        #expect(await Attente.jusqua { await toutesPresentes(voisines, dans: cache) })

        await moteur.arreter()
    }

    // MARK: Critere, la precharge ne gene jamais la page visible

    @Test("Aucune precharge ne commence pendant la production de la page visible")
    func aucunePrechargePendantLaPageVisible() async throws {
        let fournisseur = FournisseurDeTest(nombreDePages: 20)
        let atelier = AtelierEspion()
        let cache = CacheMemoireDePages()
        let moteur = moteur(fournisseur: fournisseur, atelier: atelier, cache: cache)

        atelier.retenir("page-3")
        let visible = Task { try await moteur.pageVisible(3) }

        #expect(await Attente.jusqua { atelier.commences.contains("page-3") })

        await moteur.deplacerVers(3)

        // Largement de quoi laisser trois precharges demarrer, si rien ne les
        // retenait. La page visible est toujours dans son decodage.
        try await Task.sleep(for: .milliseconds(150))
        #expect(atelier.commences == ["page-3"])

        atelier.liberer("page-3")
        _ = try await visible.value

        // La file reprend une fois la page visible produite. Sans cette
        // verification, un moteur qui ne precharge jamais rien passerait le
        // test precedent sans rien faire.
        let voisines = [cle(fournisseur, 4), cle(fournisseur, 5)]

        #expect(await Attente.jusqua { await toutesPresentes(voisines, dans: cache) })

        await moteur.arreter()
    }

    @Test("La page visible n attend jamais derriere une precharge en cours")
    func pageVisibleJamaisDerriereUnePrecharge() async throws {
        let fournisseur = FournisseurDeTest(nombreDePages: 20)
        let atelier = AtelierEspion()
        let moteur = moteur(fournisseur: fournisseur, atelier: atelier, cache: CacheMemoireDePages())

        // La voisine met une demi seconde a se decoder, bien plus que le budget
        // de tourne de page. Une page visible qui passerait par la meme file en
        // heriterait.
        atelier.ralentir("page-1", de: 0.5)
        await moteur.deplacerVers(0)

        #expect(await Attente.jusqua { atelier.commences.contains("page-1") })

        let debut = ContinuousClock.now
        _ = try await moteur.pageVisible(9)
        let duree = ContinuousClock.now - debut

        #expect(duree < .milliseconds(80), "tourne de page en \(duree)")

        await moteur.arreter()
    }

    // MARK: Critere, un changement de page annule les precharges inutiles

    @Test("Un changement de page annule la precharge en cours devenue inutile")
    func annulationDeLaPrechargeEnCours() async {
        let fournisseur = FournisseurDeTest(nombreDePages: 20, ouvert: false)
        let atelier = AtelierEspion()
        let cache = CacheMemoireDePages()
        let moteur = moteur(fournisseur: fournisseur, atelier: atelier, cache: cache)

        await moteur.deplacerVers(15)
        #expect(await Attente.jusqua { await fournisseur.demandees.contains(16) })

        await moteur.deplacerVers(0)

        #expect(await moteur.cleEnCours == cle(fournisseur, 1))
        #expect(await moteur.clesEnAttente == [cle(fournisseur, 2)])

        await fournisseur.ouvrir()

        let voisines = [cle(fournisseur, 1), cle(fournisseur, 2)]

        #expect(await Attente.jusqua { await toutesPresentes(voisines, dans: cache) })

        // Rien de ce qui a ete annule n arrive dans le cache, meme en retard.
        for index in [14, 16, 17] {
            #expect(await cache.contient(cle(fournisseur, index)) == false)
        }

        #expect(atelier.commences.contains("page-16") == false)

        await moteur.arreter()
    }

    @Test("Une precharge encore utile apres le changement de page est conservee")
    func prechargeEncoreUtileConservee() async {
        let fournisseur = FournisseurDeTest(nombreDePages: 20, ouvert: false)
        let moteur = moteur(fournisseur: fournisseur, atelier: AtelierEspion(), cache: CacheMemoireDePages())

        await moteur.deplacerVers(5)
        #expect(await Attente.jusqua { await fournisseur.demandees.contains(6) })

        // Depuis la page 6, la page 7 reste une voisine en avant. La precharge
        // en cours ne doit donc pas etre relancee depuis le debut.
        await moteur.deplacerVers(7)

        #expect(await moteur.cleEnCours == cle(fournisseur, 6))
        #expect(await moteur.clesEnAttente == [cle(fournisseur, 8), cle(fournisseur, 9)])
        #expect(await fournisseur.demandees.filter { $0 == 6 }.count == 1)

        await moteur.arreter()
    }

    @Test("Arreter annule tout et ne depose plus rien")
    func arretComplet() async {
        let fournisseur = FournisseurDeTest(nombreDePages: 20, ouvert: false)
        let cache = CacheMemoireDePages()
        let moteur = moteur(fournisseur: fournisseur, atelier: AtelierEspion(), cache: cache)

        await moteur.deplacerVers(5)
        #expect(await Attente.jusqua { await fournisseur.demandees.contains(6) })

        await moteur.arreter()
        await fournisseur.ouvrir()

        #expect(await moteur.cleEnCours == nil)
        #expect(await moteur.clesEnAttente.isEmpty)

        try? await Task.sleep(for: .milliseconds(100))
        #expect(await cache.nombreDePages == 0)
    }

    // MARK: Page visible

    @Test("Une page deja prechargee revient du cache sans nouveau decodage")
    func pageVisibleServieParLeCache() async throws {
        let fournisseur = FournisseurDeTest(nombreDePages: 20)
        let atelier = AtelierEspion()
        let cache = CacheMemoireDePages()
        let moteur = moteur(fournisseur: fournisseur, atelier: atelier, cache: cache)

        await moteur.deplacerVers(0)
        #expect(await Attente.jusqua { await cache.contient(cle(fournisseur, 1)) })

        let decodagesAvant = atelier.commences.count
        _ = try await moteur.pageVisible(1)

        #expect(atelier.commences.count == decodagesAvant)
        #expect(await cache.pageVisible == cle(fournisseur, 1))

        await moteur.arreter()
    }

    @Test("Une page illisible en precharge ne fait tomber ni la file ni le lecteur")
    func prechargeIllisible() async {
        let fournisseur = FournisseurDeTest(nombreDePages: 20)
        let cache = CacheMemoireDePages()

        // L atelier reel refuse ces octets, qui ne sont pas une image.
        let moteur = PrechargeDesPagesVoisines(
            fournisseur: fournisseur,
            cache: cache,
            reglages: ReglagesDePrecharge(zone: zone)
        )

        await moteur.deplacerVers(5)

        #expect(await Attente.jusqua { await moteur.fileEstVide })
        #expect(await cache.nombreDePages == 0)
    }

    // MARK: Outils

    private func moteur(
        fournisseur: FournisseurDeTest,
        atelier: AtelierEspion,
        cache: CacheMemoireDePages
    ) -> PrechargeDesPagesVoisines {
        PrechargeDesPagesVoisines(
            fournisseur: fournisseur,
            cache: cache,
            reglages: ReglagesDePrecharge(zone: zone),
            atelier: atelier
        )
    }

    /// Vrai quand toutes ces cles sont dans le cache.
    ///
    /// Une boucle plutot qu une conjonction : une expression de `#expect` ne
    /// sait pas franchir plusieurs suspensions.
    private func toutesPresentes(_ cles: [ClePage], dans cache: CacheMemoireDePages) async -> Bool {
        for cle in cles {
            let presente = await cache.contient(cle)

            if presente == false {
                return false
            }
        }

        return true
    }

    private func cle(_ fournisseur: FournisseurDeTest, _ index: Int) -> ClePage {
        ClePage(chapitre: fournisseur.chapitre, index: index)
    }
}
