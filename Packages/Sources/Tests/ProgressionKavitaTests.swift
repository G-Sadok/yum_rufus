import Core
import Foundation
import Testing
@testable import Sources

//
// ProgressionKavitaTests
//
// La progression distante de Kavita, ou tout se joue sur deux points.
//
// Le premier est l absence de conversion. Kavita indexe ses pages a partir de
// zero, comme le modele, la ou Komga compte a partir de un. Les tests verifient
// donc explicitement qu aucun decalage n a ete recopie par symetrie : c est le
// genre d ecart d une page qui ne se voit pas a la relecture du code et se voit
// a chaque reprise de chapitre.
//
// Le second est le marquage. Le serveur ne publie aucun drapeau de lecture par
// chapitre, il compare le nombre de pages lues au total. Un chapitre lu doit
// donc partir a son nombre de pages, et non a l index de sa derniere page.
//

struct ProgressionKavitaTests {
    // MARK: Lecture

    @Test("La page atteinte est lue sans decalage")
    func progressionLueSansDecalage() async throws {
        let serveur = ServeurKavitaDeTest(ServeurKavitaDeTest.reglesCompletes)
        let source = try await serveur.source()
        let chapitre = String(ReponsesFigeesDeKavita.identifiantDuPremierChapitre)
        let progression = try #require(await source.progression(pour: chapitre))

        // Le serveur annonce la page un, le modele attend la page un. Ajouter
        // ou retrancher une unite ici deplacerait la reprise a chaque chapitre.
        #expect(progression.pageAtteinte == 1)
        #expect(progression.nombreDePages == 3)
        #expect(progression.estLu == false)
        #expect(progression.identifiantChapitre == chapitre)

        // Le serveur horodate a la milliseconde. La comparaison se fait donc a
        // la tolerance et non a l egalite stricte, qui echouerait sur une date
        // pourtant lue correctement.
        let lue = try #require(progression.dateDeLecture)
        let attendue = try #require(DatesDeTest.instant(2026, 2, 3, HeureDeTest(18, 24, 5)))

        #expect(abs(lue.timeIntervalSince(attendue) - 0.123) < 0.001)
    }

    @Test("Un chapitre jamais ouvert ne tient aucune progression")
    func progressionAbsente() async throws {
        var regles = ServeurKavitaDeTest.reglesCompletes
        regles.insert(
            .json(.get, CheminsKavita.progressionLue, ReponsesFigeesDeKavita.progressionAbsente),
            at: 0
        )

        let serveur = ServeurKavitaDeTest(regles)
        let source = try await serveur.source()

        // Kavita rend une page zero sans date pour un chapitre jamais ouvert.
        // La rendre comme une progression poserait une pastille de lecture en
        // cours sur toute la bibliotheque.
        #expect(
            try await source.progression(
                pour: String(ReponsesFigeesDeKavita.identifiantDuPremierChapitre)
            ) == nil
        )
    }

    @Test("Un chapitre lu de bout en bout est reconnu comme lu")
    func progressionTerminee() async throws {
        var regles = ServeurKavitaDeTest.reglesCompletes
        regles.insert(
            .json(.get, CheminsKavita.progressionLue, ReponsesFigeesDeKavita.progressionTerminee),
            at: 0
        )

        let serveur = ServeurKavitaDeTest(regles)
        let source = try await serveur.source()
        let progression = try #require(
            await source.progression(pour: String(ReponsesFigeesDeKavita.identifiantDuPremierChapitre))
        )

        #expect(progression.estLu)
        #expect(progression.part == 1)
        // Le serveur compte trois pages lues sur trois. La page atteinte est
        // bornee au dernier index, sans quoi elle designerait une page qui
        // n existe pas.
        #expect(progression.pageAtteinte == 2)
    }

    // MARK: Publication

    @Test("La progression publiee porte les quatre identifiants du serveur")
    func publicationPorteLesIdentifiants() async throws {
        let serveur = ServeurKavitaDeTest(ServeurKavitaDeTest.reglesCompletes)
        let source = try await serveur.source()

        try await source.publier(
            ProgressionDistante(identifiantChapitre: "401", pageAtteinte: 1, nombreDePages: 3)
        )

        let envoyee = try #require(await serveur.transport.derniere)
        let corps = try #require(envoyee.corpsJson())

        #expect(envoyee.chemin.hasSuffix("/api/Reader/progress"))
        #expect(envoyee.methode == "POST")
        // Les envoyer a zero laisserait la progression enregistree mais les
        // compteurs de la grille inchanges.
        #expect(corps["chapterId"] as? Int == 401)
        #expect(corps["volumeId"] as? Int == 91)
        #expect(corps["seriesId"] as? Int == 17)
        #expect(corps["libraryId"] as? Int == 2)
        #expect(corps["pageNum"] as? Int == 1)
    }

    @Test("Un chapitre marque lu part a son nombre de pages, pas au dernier index")
    func chapitreLuPartAuTotal() async throws {
        let serveur = ServeurKavitaDeTest(ServeurKavitaDeTest.reglesCompletes)
        let source = try await serveur.source()

        try await source.publier(
            ProgressionDistante(
                identifiantChapitre: "401",
                pageAtteinte: 2,
                nombreDePages: 3,
                estLu: true
            )
        )

        // Le serveur compare le nombre de pages lues au total. Envoyer l index
        // de la derniere page laisserait le chapitre a une page de la fin pour
        // toujours.
        #expect(await serveur.transport.derniere?.corpsJson()?["pageNum"] as? Int == 3)
    }

    @Test("Une page au dela du chapitre est ramenee dans ses bornes")
    func pageBornee() async throws {
        let serveur = ServeurKavitaDeTest(ServeurKavitaDeTest.reglesCompletes)
        let source = try await serveur.source()

        try await source.publier(
            ProgressionDistante(identifiantChapitre: "401", pageAtteinte: 99, nombreDePages: 3)
        )

        // Le repere du serveur annonce trois pages. Une page hors bornes serait
        // refusee, ou pire, accepterait un chapitre marque lu par accident.
        #expect(await serveur.transport.derniere?.corpsJson()?["pageNum"] as? Int == 2)
    }

    @Test("Le marquage comme non lu remet la page a zero")
    func effacementRemetAZero() async throws {
        let serveur = ServeurKavitaDeTest(ServeurKavitaDeTest.reglesCompletes)
        let source = try await serveur.source()

        try await source.effacerLaProgression(pour: "401")

        let envoyee = try #require(await serveur.transport.derniere)

        // Kavita n a aucun point d entree qui efface la progression d un seul
        // chapitre. Remettre la page a zero produit exactement l etat vise.
        #expect(envoyee.chemin.hasSuffix("/api/Reader/progress"))
        #expect(envoyee.corpsJson()?["pageNum"] as? Int == 0)
        #expect(envoyee.corpsJson()?["chapterId"] as? Int == 401)
    }

    @Test("Une progression sur un chapitre absent nomme le chapitre")
    func publicationSurChapitreAbsent() async throws {
        let serveur = ServeurKavitaDeTest([
            .json(.post, CheminsKavita.connexion, ReponsesFigeesDeKavita.connexion(
                jeton: ServeurKavitaDeTest.jetonValable
            )),
            .statut(CheminsKavita.infoDeChapitre, 404),
        ])
        let source = try await serveur.source()

        await #expect(throws: ErreurDeSource.chapitreIntrouvable(identifiant: "777")) {
            try await source.publier(
                ProgressionDistante(identifiantChapitre: "777", pageAtteinte: 0)
            )
        }
    }
}
