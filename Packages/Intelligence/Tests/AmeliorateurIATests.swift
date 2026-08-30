import Core
import Foundation
import ImagePipeline
import Testing
@testable import Intelligence

/// Couvre les deux derniers criteres de la fonctionnalite : deux traitements ne
/// tournent jamais en parallele, et le resultat est mis en cache et jamais
/// recalcule.
///
/// Les deux se mesurent au meme endroit, sur ce que le modele a reellement recu.
/// Le journal compte les appels et surveille leur recouvrement dans le temps, et
/// un cas verifie d abord que ce journal sait voir deux appels simultanes. Sans
/// lui, une assertion qui exige un maximum de un passerait aussi sur un
/// compteur aveugle.
struct AmeliorateurIATests {
    private let chapitre = UUID()

    /// Page d une seule tuile, pour que le compte d appels se lise directement.
    private func pageDUneTuile() throws -> ImageDePage {
        try #require(PagesDeTest.decodee(largeur: 256, hauteur: 256))
    }

    private func cle(_ index: Int) -> ClePage {
        ClePage(chapitre: chapitre, index: index)
    }

    // MARK: L instrument voit le parallelisme

    @Test("Le journal sait voir deux traitements simultanes")
    func leJournalVoitLeParallele() {
        let journal = JournalDeModele()

        journal.entrer(largeur: 256, hauteur: 256)
        journal.entrer(largeur: 256, hauteur: 256)
        journal.sortir()
        journal.sortir()

        #expect(journal.maximumSimultane == 2)
    }

    // MARK: Deux traitements ne tournent jamais en parallele

    @Test("Six ameliorations lancees ensemble s executent une par une")
    func traitementsSerialises() async throws {
        let journal = JournalDeModele()
        let modele = ModeleSurveille(base: ModeleDeRecopie(), journal: journal, attente: 0.02)
        let ameliorateur = AmeliorateurIA(modele: modele)
        let page = try pageDUneTuile()
        let identifiantDuChapitre = chapitre

        await withTaskGroup(of: Void.self) { groupe in
            for index in 0..<6 {
                groupe.addTask {
                    _ = await ameliorateur.ameliorerOuRendreTelQuel(
                        page,
                        pour: ClePage(chapitre: identifiantDuChapitre, index: index)
                    )
                }
            }
        }

        let traitements = await ameliorateur.nombreDeTraitements

        #expect(journal.appels == 6)
        #expect(journal.maximumSimultane == 1)
        #expect(traitements == 6)
    }

    // MARK: Le resultat est mis en cache et jamais recalcule

    @Test("La meme page sous les memes reglages n est traitee qu une fois")
    func pageTraiteeUneSeuleFois() async throws {
        let journal = JournalDeModele()
        let ameliorateur = AmeliorateurIA(modele: ModeleSurveille(
            base: ModeleDeRecopie(),
            journal: journal
        ))
        let page = try pageDUneTuile()

        let premiere = try await ameliorateur.ameliorer(page, pour: cle(0))
        let seconde = try await ameliorateur.ameliorer(page, pour: cle(0))
        let troisieme = try await ameliorateur.ameliorer(page, pour: cle(0))

        let traitements = await ameliorateur.nombreDeTraitements

        #expect(journal.appels == 1)
        #expect(traitements == 1)
        #expect(premiere.tailleDecodee == TailleEnPixels(largeur: 512, hauteur: 512))
        #expect(seconde.tailleDecodee == premiere.tailleDecodee)
        #expect(troisieme.image === premiere.image)
    }

    @Test("Deux pages differentes tiennent ensemble dans le cache")
    func deuxPagesRetenuesEnsemble() async throws {
        let journal = JournalDeModele()
        let ameliorateur = AmeliorateurIA(modele: ModeleSurveille(
            base: ModeleDeRecopie(),
            journal: journal
        ))
        let page = try pageDUneTuile()

        _ = try await ameliorateur.ameliorer(page, pour: cle(0))
        _ = try await ameliorateur.ameliorer(page, pour: cle(1))
        _ = try await ameliorateur.ameliorer(page, pour: cle(0))
        _ = try await ameliorateur.ameliorer(page, pour: cle(1))

        let traitements = await ameliorateur.nombreDeTraitements
        let retenues = await ameliorateur.nombreDePagesRetenues
        let octets = await ameliorateur.octetsRetenus

        #expect(traitements == 2)
        #expect(retenues == 2)
        #expect(octets > 0)
    }

    @Test("Le cache oublie sur demande, et la page est alors retraitee")
    func oubliPuisRetraitement() async throws {
        let ameliorateur = AmeliorateurIA(modele: ModeleDeRecopie())
        let page = try pageDUneTuile()

        _ = try await ameliorateur.ameliorer(page, pour: cle(0))
        await ameliorateur.oublier(cle(0), reglages: .arme)
        _ = try await ameliorateur.ameliorer(page, pour: cle(0))

        let traitements = await ameliorateur.nombreDeTraitements

        #expect(traitements == 2)

        await ameliorateur.vider()

        let retenues = await ameliorateur.nombreDePagesRetenues
        let octets = await ameliorateur.octetsRetenus

        #expect(retenues == 0)
        #expect(octets == 0)
    }

    // MARK: La cle de cache

    @Test("La cle integre les reglages, le modele et son facteur")
    func laCleIntegreLesParametres() {
        let page = cle(3)
        let premier = ModeleDeRecopie(identifiant: "esrgan-anime-1")
        let second = ModeleDeRecopie(identifiant: "esrgan-anime-2")
        let quadruple = ModeleDeRecopie(identifiant: "esrgan-anime-1", facteur: 4)

        let reference = AmeliorateurIA.cle(pour: page, reglages: .arme, modele: premier)

        #expect(reference != page)
        #expect(reference != AmeliorateurIA.cle(pour: page, reglages: .parDefaut, modele: premier))
        #expect(reference != AmeliorateurIA.cle(pour: page, reglages: .arme, modele: second))
        #expect(reference != AmeliorateurIA.cle(pour: page, reglages: .arme, modele: quadruple))
    }

    @Test("La cle conserve la variante deja portee par la page")
    func laCleConserveLaVariante() {
        let brute = ClePage(chapitre: chapitre, index: 3)
        let variante = ClePage(chapitre: chapitre, index: 3, variante: "rognage=1")
        let modele = ModeleDeRecopie()

        let depuisLaVariante = AmeliorateurIA.cle(pour: variante, reglages: .arme, modele: modele)

        #expect(depuisLaVariante.variante.contains("rognage=1"))
        #expect(depuisLaVariante != AmeliorateurIA.cle(pour: brute, reglages: .arme, modele: modele))
    }

    // MARK: L interrupteur et les gardes

    @Test("L interrupteur inactif rend la page telle quelle, sans rien traiter")
    func interrupteurInactif() async throws {
        let journal = JournalDeModele()
        let ameliorateur = AmeliorateurIA(modele: ModeleSurveille(
            base: ModeleDeRecopie(),
            journal: journal
        ))
        let page = try pageDUneTuile()

        let rendue = try await ameliorateur.ameliorer(page, pour: cle(0), reglages: .parDefaut)

        let traitements = await ameliorateur.nombreDeTraitements

        #expect(rendue.image === page.image)
        #expect(journal.appels == 0)
        #expect(traitements == 0)
    }

    @Test("Une page qui depasserait le plafond memoire n est pas traitee")
    func pageTropLourdeRefusee() async throws {
        let budget = BudgetDeTraitementIA(octetsParPage: 512 * 512 * 4)
        let ameliorateur = AmeliorateurIA(modele: ModeleDeRecopie(), budget: budget)
        let page = try #require(PagesDeTest.decodee(largeur: 512, hauteur: 512))

        await #expect(throws: ErreurDeTraitementIA.self) {
            _ = try await ameliorateur.ameliorer(page, pour: cle(0))
        }

        let repli = await ameliorateur.ameliorerOuRendreTelQuel(page, pour: cle(0))

        #expect(repli.image === page.image)
    }
}
