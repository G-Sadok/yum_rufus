import Core
import Foundation
import Testing

/// Verifie le bouton principal de la fiche contre le tableau des libelles de la
/// section 5.6 de DESIGN-SPEC.md.
///
/// Premier critere de F016 : le libelle du bouton principal change selon l etat
/// de lecture. Le libelle lui meme vit dans le catalogue de chaines, ce qui se
/// verifie du cote DesignSystem. Ce qui se verifie ici, c est que les quatre
/// etats de lecture produisent bien quatre cas distincts.
struct ActionPrincipaleDeFicheTests {
    @Test("Une serie sans chapitre desactive le bouton")
    func aucunChapitre() {
        let action = ActionPrincipaleDeFiche.pour(chapitres: [])

        #expect(action == .aucunChapitre)
        #expect(action.estActive == false)
        #expect(action.chapitreAOuvrir == nil)
    }

    @Test("Une serie jamais ouverte propose de commencer par son premier chapitre")
    func aucunChapitreLu() throws {
        let chapitres = ChapitresDeTest.serie(de: 3)
        let action = ActionPrincipaleDeFiche.pour(chapitres: chapitres)

        let premier = try #require(chapitres.first)

        #expect(action == .commencerLaLecture(chapitre: premier.id))
        #expect(action.estActive)
        #expect(action.numeroAffiche == nil)
    }

    @Test("Un chapitre laisse en cours est celui que le bouton reprend")
    func lectureEnCours() {
        let enCours = ChapitresDeTest.chapitre(rang: 1, numero: 42, nombrePages: 38, pageAtteinte: 13)

        let chapitres = [
            ChapitresDeTest.chapitre(rang: 0, numero: 41, estLu: true),
            enCours,
            ChapitresDeTest.chapitre(rang: 2, numero: 43),
        ]

        let action = ActionPrincipaleDeFiche.pour(chapitres: chapitres)

        #expect(action == .reprendre(chapitre: enCours.id, numero: 42))
        #expect(action.numeroAffiche == 42)
        #expect(action.estActive)
    }

    @Test("Entre deux chapitres en cours, le plus recemment lu gagne")
    func deuxChapitresEnCours() {
        let hier = Date(timeIntervalSinceReferenceDate: 1000)
        let aujourdHui = Date(timeIntervalSinceReferenceDate: 2000)

        let ancien = ChapitresDeTest.chapitre(rang: 0, numero: 1, pageAtteinte: 2, dateLecture: hier)
        let recent = ChapitresDeTest.chapitre(rang: 1, numero: 2, pageAtteinte: 5, dateLecture: aujourdHui)

        let action = ActionPrincipaleDeFiche.pour(chapitres: [ancien, recent])

        #expect(action == .reprendre(chapitre: recent.id, numero: 2))
    }

    @Test("Une serie commencee sans chapitre ouvert reprend au premier non lu")
    func chapitresLusSansChapitreOuvert() {
        let aLire = ChapitresDeTest.chapitre(rang: 2, numero: 3)

        let chapitres = [
            ChapitresDeTest.chapitre(rang: 0, numero: 1, estLu: true),
            ChapitresDeTest.chapitre(rang: 1, numero: 2, estLu: true),
            aLire,
        ]

        let action = ActionPrincipaleDeFiche.pour(chapitres: chapitres)

        #expect(action == .reprendre(chapitre: aLire.id, numero: 3))
    }

    @Test("Une serie entierement lue le dit, et reste ouvrable")
    func toutEstLu() throws {
        let chapitres = (0..<3).map { rang in
            ChapitresDeTest.chapitre(rang: rang, estLu: true, dateLecture: Date())
        }

        let action = ActionPrincipaleDeFiche.pour(chapitres: chapitres)
        let premier = try #require(chapitres.first)

        #expect(action == .toutEstLu(chapitre: premier.id))
        #expect(action.estActive, "Une serie lue se relit, le bouton n est pas une impasse")
        #expect(action.chapitreAOuvrir == premier.id)
    }

    @Test("Les quatre etats de lecture produisent quatre actions distinctes")
    func quatreActionsDistinctes() {
        let lus = (0..<2).map { rang in ChapitresDeTest.chapitre(rang: rang, estLu: true) }

        let actions: [ActionPrincipaleDeFiche] = [
            .pour(chapitres: []),
            .pour(chapitres: ChapitresDeTest.serie(de: 2)),
            .pour(chapitres: [ChapitresDeTest.chapitre(rang: 0, pageAtteinte: 3)]),
            .pour(chapitres: lus),
        ]

        #expect(Set(actions).count == 4, "Deux etats de lecture rendent la meme action")
    }

    @Test("Le rang dans la serie decide, pas l ordre du tableau recu")
    func ordreDuTableauSansEffet() throws {
        let chapitres = ChapitresDeTest.serie(de: 3)
        let premier = try #require(chapitres.first)

        let action = ActionPrincipaleDeFiche.pour(chapitres: chapitres.reversed())

        #expect(action == .commencerLaLecture(chapitre: premier.id))
    }

    @Test("Le filtre de la liste ne change pas ce que le bouton propose")
    func filtreSansEffetSurLeBouton() {
        let chapitres = [
            ChapitresDeTest.chapitre(rang: 0, numero: 1, estLu: true),
            ChapitresDeTest.chapitre(rang: 1, numero: 2),
        ]

        let fiche = FicheDeSerie(
            serie: SerieDeTest.manga(),
            nomDeLaSource: "Dossier de test",
            tousLesChapitres: chapitres,
            reglage: ReglageDeListeDeChapitres(filtre: .lus)
        )

        #expect(fiche.chapitres.count == 1, "Le filtre Lus ne garde qu un chapitre")
        #expect(fiche.nombreDeChapitres == 2)
        #expect(fiche.actionPrincipale.numeroAffiche == 2, "Le bouton parle du chapitre a lire")
        #expect(fiche.estSansChapitre == false)
    }
}

/// Serie minimale, quand seul son existence compte.
enum SerieDeTest {
    static func manga(titre: String = "Serie de test") -> Manga {
        Manga(
            sourceId: UUID(),
            identifiantDistant: "serie",
            titre: titre,
            estDansBibliotheque: true
        )
    }
}
