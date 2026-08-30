import Core
import Foundation
import ImagePipeline
import Testing
@testable import Intelligence

/// Couvre les deux premiers criteres de la fonctionnalite : la colorisation
/// fonctionne sur une page en noir et blanc, et le resultat est mis en cache.
///
/// Le premier critere ne se regarde pas, il se compte. Une page en noir et blanc
/// est une page dont les trois canaux portent partout la meme valeur, et une
/// page colorisee est une page ou cette egalite a disparu. Les deux mesures
/// encadrent le traitement : la premiere prouve que l entree meritait son nom,
/// la seconde que la sortie a change de nature. Sans la premiere, un test qui
/// mesure de la couleur en sortie passerait aussi sur une page qui en portait
/// deja.
struct ColoriseurIATests {
    private let chapitre = UUID()

    /// Page de plusieurs tuiles, pour que le tuilage soit reellement exerce.
    private let largeurDePage = 300
    private let hauteurDePage = 400

    private func cle(_ index: Int) -> ClePage {
        ClePage(chapitre: chapitre, index: index)
    }

    private func pageEnNoirEtBlanc() throws -> ImageDePage {
        try #require(PagesDeTest.decodeeEnNoirEtBlanc(
            largeur: largeurDePage,
            hauteur: hauteurDePage
        ))
    }

    /// Page d une seule tuile, pour que le compte d appels se lise directement.
    private func pageDUneTuile() throws -> ImageDePage {
        try #require(PagesDeTest.decodeeEnNoirEtBlanc(largeur: 256, hauteur: 256))
    }

    // MARK: La colorisation fonctionne sur une page en noir et blanc

    @Test("Une page en noir et blanc ressort en couleurs, aux memes dimensions")
    func pageEnNoirEtBlancColorisee() async throws {
        let coloriseur = ColoriseurIA(modele: ModeleDeTeinte())
        let page = try pageEnNoirEtBlanc()
        let entree = try #require(MatriceDePixels(page.image))

        #expect(EcartsDePixels.estEnNoirEtBlanc(entree))

        let colorisee = try await coloriseur.coloriser(page, pour: cle(0))
        let sortie = try #require(MatriceDePixels(colorisee.image))

        #expect(sortie.taille == entree.taille)
        #expect(EcartsDePixels.estEnNoirEtBlanc(sortie) == false)
        #expect(EcartsDePixels.partDePixelsColores(sortie) > 0.6)
        #expect(colorisee.tailleDecodee == entree.taille)
        #expect(colorisee.tailleDOrigine == page.tailleDOrigine)
    }

    @Test("La page tuilee est exactement la page colorisee d un seul tenant")
    func colorisationSansRaccord() throws {
        let modele = ModeleDeTeinte()
        let page = try #require(PagesDeTest.noirEtBlanc(largeur: 700, hauteur: 300))
        let reference = try modele.coloriser(page)
        let tuilee = try TraitementParTuiles(tuilage: modele.tuilage).traiter(page, avec: modele)

        #expect(tuilee.taille == page.taille)
        #expect(EcartsDePixels.maximum(tuilee, reference) == 0)
    }

    @Test("Une page plus etroite qu une tuile garde ses dimensions")
    func pagePlusPetiteQuUneTuile() async throws {
        let coloriseur = ColoriseurIA(modele: ModeleDeTeinte())
        let page = try #require(PagesDeTest.decodeeEnNoirEtBlanc(largeur: 91, hauteur: 137))

        let colorisee = try await coloriseur.coloriser(page, pour: cle(0))
        let sortie = try #require(MatriceDePixels(colorisee.image))

        #expect(sortie.taille == TailleEnPixels(largeur: 91, hauteur: 137))
        #expect(EcartsDePixels.estEnNoirEtBlanc(sortie) == false)
    }

    @Test("Le tuilage prend le cote de tuile annonce par le modele")
    func tuilageAuCoteDuModele() async throws {
        let journal = JournalDeModele()
        let modele = ModeleDeColorisationSurveille(
            base: ModeleDeTeinte(coteDeTuile: 128),
            journal: journal
        )
        let coloriseur = ColoriseurIA(modele: modele)
        let page = try pageEnNoirEtBlanc()

        let tuilage = await coloriseur.tuilage

        _ = try await coloriseur.coloriser(page, pour: cle(0))

        #expect(tuilage.cote == 128)
        #expect(tuilage.recouvrement == TuilageDeTraitement.recouvrementDeTuile)
        #expect(journal.taillesObservees == ["128x128"])
        #expect(journal.appels > 1)
    }

    @Test("Un modele qui changerait les dimensions est refuse")
    func modeleQuiAgranditRefuse() async throws {
        let coloriseur = ColoriseurIA(modele: ModeleDeColorisationQuiAgrandit())
        let page = try pageDUneTuile()

        await #expect(throws: ErreurDeTraitementIA.self) {
            _ = try await coloriseur.coloriser(page, pour: cle(0))
        }

        let repli = await coloriseur.coloriserOuRendreTelQuel(page, pour: cle(0))

        #expect(repli.image === page.image)
    }

    // MARK: Le resultat est mis en cache

    @Test("La meme page sous les memes reglages n est colorisee qu une fois")
    func pageColoriseeUneSeuleFois() async throws {
        let journal = JournalDeModele()
        let coloriseur = ColoriseurIA(modele: ModeleDeColorisationSurveille(journal: journal))
        let page = try pageDUneTuile()

        let premiere = try await coloriseur.coloriser(page, pour: cle(0))
        let seconde = try await coloriseur.coloriser(page, pour: cle(0))
        let troisieme = try await coloriseur.coloriser(page, pour: cle(0))

        let traitements = await coloriseur.nombreDeTraitements
        let retenues = await coloriseur.nombreDePagesRetenues
        let octets = await coloriseur.octetsRetenus

        #expect(journal.appels == 1)
        #expect(traitements == 1)
        #expect(retenues == 1)
        #expect(octets > 0)
        #expect(seconde.image === premiere.image)
        #expect(troisieme.image === premiere.image)
    }

    /// Le cache des pages colorisees ne retient qu une page, parce qu une page
    /// colorisee apres amelioration pese jusqu a quarante huit millions
    /// d octets. Ce cas fige ce choix : alterner deux pages fait bien retraiter,
    /// et ce n est pas une regression mais la borne memoire de la section 12.
    @Test("Le cache ne retient qu une page a la fois")
    func cacheDUneSeulePage() async throws {
        let coloriseur = ColoriseurIA(modele: ModeleDeTeinte())
        let page = try pageDUneTuile()

        _ = try await coloriseur.coloriser(page, pour: cle(0))
        _ = try await coloriseur.coloriser(page, pour: cle(1))
        _ = try await coloriseur.coloriser(page, pour: cle(0))

        let traitements = await coloriseur.nombreDeTraitements
        let retenues = await coloriseur.nombreDePagesRetenues

        #expect(traitements == 3)
        #expect(retenues == 1)
        #expect(await coloriseur.plafond == .pagesColorisees)
    }

    @Test("Le cache oublie sur demande, et la page est alors recolorisee")
    func oubliPuisRetraitement() async throws {
        let coloriseur = ColoriseurIA(modele: ModeleDeTeinte())
        let page = try pageDUneTuile()

        _ = try await coloriseur.coloriser(page, pour: cle(0))
        await coloriseur.oublier(cle(0), reglages: .arme)
        _ = try await coloriseur.coloriser(page, pour: cle(0))

        let traitements = await coloriseur.nombreDeTraitements

        #expect(traitements == 2)

        await coloriseur.vider()

        let retenues = await coloriseur.nombreDePagesRetenues
        let octets = await coloriseur.octetsRetenus

        #expect(retenues == 0)
        #expect(octets == 0)
    }

    // MARK: Deux colorisations ne tournent jamais en parallele

    @Test("Six colorisations lancees ensemble s executent une par une")
    func colorisationsSerialisees() async throws {
        let journal = JournalDeModele()
        let coloriseur = ColoriseurIA(modele: ModeleDeColorisationSurveille(
            journal: journal,
            attente: 0.02
        ))
        let page = try pageDUneTuile()
        let identifiantDuChapitre = chapitre

        await withTaskGroup(of: Void.self) { groupe in
            for index in 0..<6 {
                groupe.addTask {
                    _ = await coloriseur.coloriserOuRendreTelQuel(
                        page,
                        pour: ClePage(chapitre: identifiantDuChapitre, index: index)
                    )
                }
            }
        }

        #expect(journal.appels == 6)
        #expect(journal.maximumSimultane == 1)
    }

    // MARK: La cle de cache

    @Test("La cle integre les reglages et le modele")
    func laCleIntegreLesParametres() {
        let page = cle(3)
        let premier = ModeleDeTeinte(identifiant: "colorisation-1")
        let second = ModeleDeTeinte(identifiant: "colorisation-2")

        let reference = ColoriseurIA.cle(pour: page, reglages: .arme, modele: premier)

        #expect(reference != page)
        #expect(reference != ColoriseurIA.cle(pour: page, reglages: .parDefaut, modele: premier))
        #expect(reference != ColoriseurIA.cle(pour: page, reglages: .arme, modele: second))
    }

    /// La colorisation suit l amelioration dans la chaine de la section 6.3. Sa
    /// cle doit donc conserver l empreinte que l amelioration a deja posee, sans
    /// quoi une page amelioree puis colorisee et une page seulement colorisee
    /// partageraient la meme entree de cache.
    @Test("La cle conserve la variante deja portee par la page")
    func laCleConserveLaVariante() {
        let brute = ClePage(chapitre: chapitre, index: 3)
        let amelioree = ClePage(chapitre: chapitre, index: 3, variante: "ia=1;m=esrgan;f=2")
        let modele = ModeleDeTeinte()

        let depuisLAmelioration = ColoriseurIA.cle(pour: amelioree, reglages: .arme, modele: modele)

        #expect(depuisLAmelioration.variante.contains("ia=1;m=esrgan;f=2"))
        #expect(depuisLAmelioration.variante.contains("col=1"))
        #expect(depuisLAmelioration != ColoriseurIA.cle(pour: brute, reglages: .arme, modele: modele))
    }

    @Test("Les deux empreintes de la chaine ne se confondent pas")
    func empreintesDistinctes() {
        #expect(ReglagesDeColorisation.arme.empreinte != ReglagesDAmelioration.arme.empreinte)
        #expect(ReglagesDeColorisation.parDefaut.actif == false)
    }

    // MARK: L interrupteur et les gardes

    @Test("L interrupteur inactif rend la page telle quelle, sans rien traiter")
    func interrupteurInactif() async throws {
        let journal = JournalDeModele()
        let coloriseur = ColoriseurIA(modele: ModeleDeColorisationSurveille(journal: journal))
        let page = try pageDUneTuile()

        let rendue = try await coloriseur.coloriser(page, pour: cle(0), reglages: .parDefaut)

        let traitements = await coloriseur.nombreDeTraitements

        #expect(rendue.image === page.image)
        #expect(journal.appels == 0)
        #expect(traitements == 0)
    }

    @Test("Une page qui depasserait le plafond memoire n est pas colorisee")
    func pageTropLourdeRefusee() async throws {
        let budget = BudgetDeTraitementIA(octetsParPage: 512 * 512 * 4)
        let coloriseur = ColoriseurIA(modele: ModeleDeTeinte(), budget: budget)
        let page = try #require(PagesDeTest.decodeeEnNoirEtBlanc(largeur: 600, hauteur: 600))

        await #expect(throws: ErreurDeTraitementIA.self) {
            _ = try await coloriseur.coloriser(page, pour: cle(0))
        }

        let repli = await coloriseur.coloriserOuRendreTelQuel(page, pour: cle(0))

        #expect(repli.image === page.image)
    }
}
