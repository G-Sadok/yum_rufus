import Core
import Foundation
import Testing
@testable import Sources

//
// ProgressionKomgaTests
//
// Couvre le deuxieme critere de la fonctionnalite : la progression est
// synchronisee avec le serveur.
//
// Synchronisee veut dire dans les deux sens et sans derive. Les tests verifient
// donc la lecture, la publication, l effacement, et surtout l aller retour :
// une progression lue puis republiee doit repartir sur la meme page. C est la
// que se voit l ecart d une unite entre la numerotation de Komga et celle du
// modele, et c est un ecart qui ne se remarque pas autrement avant d avoir
// perdu une page par chapitre.
//

struct ProgressionKomgaTests {
    private static let livre = ReponsesFigeesDeKomga.identifiantDuPremierLivre

    // MARK: Lecture

    @Test("La page du serveur est ramenee a l index du modele")
    func pageRameneeAZero() async throws {
        let serveur = ServeurKomgaDeTest(ServeurKomgaDeTest.reglesCompletes)
        let source = try await serveur.source()
        let progression = try #require(await source.progression(pour: Self.livre))

        // Le serveur annonce la page 7, comptee a partir de un.
        #expect(progression.pageAtteinte == 6)
        #expect(progression.nombreDePages == 20)
        #expect(progression.estLu == false)
        #expect(progression.identifiantChapitre == Self.livre)
        #expect(progression.dateDeLecture != nil)
    }

    @Test("Un chapitre que le serveur declare lu est lu, quelle que soit sa page")
    func chapitreDeclareLu() async throws {
        let serveur = ServeurKomgaDeTest(ServeurKomgaDeTest.reglesCompletes)

        await serveur.transport.prioriser(
            .json(.get, "api/v1/books/\(Self.livre)", ReponsesFigeesDeKomga.livreLu)
        )

        let source = try await serveur.source()
        let progression = try #require(await source.progression(pour: Self.livre))

        #expect(progression.estLu)
        #expect(progression.part == 1)
    }

    @Test("Un chapitre jamais ouvert n a aucune progression, ce qui n est pas une erreur")
    func chapitreJamaisOuvert() async throws {
        let serveur = ServeurKomgaDeTest(ServeurKomgaDeTest.reglesCompletes)

        await serveur.transport.prioriser(
            .json(.get, "api/v1/books/\(Self.livre)", ReponsesFigeesDeKomga.livreJamaisOuvert)
        )

        let source = try await serveur.source()

        #expect(try await source.progression(pour: Self.livre) == nil)
    }

    @Test("La progression d un chapitre absent nomme le chapitre")
    func chapitreAbsent() async throws {
        let serveur = ServeurKomgaDeTest([.statut("api/v1/books/disparu", 404)])
        let source = try await serveur.source()

        await #expect(throws: ErreurDeSource.chapitreIntrouvable(identifiant: "disparu")) {
            _ = try await source.progression(pour: "disparu")
        }
    }

    // MARK: Publication

    @Test("Publier une page l envoie comptee a partir de un")
    func publicationDUnePage() async throws {
        let serveur = ServeurKomgaDeTest(ServeurKomgaDeTest.reglesCompletes)
        let source = try await serveur.source()

        try await source.publier(ProgressionDistante(
            identifiantChapitre: Self.livre,
            pageAtteinte: 6,
            nombreDePages: 20
        ))

        let envoyee = try #require(await serveur.transport.derniere)
        let corps = try #require(envoyee.corpsJson())

        #expect(envoyee.methode == "PATCH")
        #expect(envoyee.chemin.hasSuffix("/api/v1/books/\(Self.livre)/read-progress"))
        #expect(corps["page"] as? Int == 7)
        #expect(corps["completed"] as? Bool == false)
    }

    @Test("Publier un chapitre lu n envoie aucune page")
    func publicationDUnChapitreLu() async throws {
        let serveur = ServeurKomgaDeTest(ServeurKomgaDeTest.reglesCompletes)
        let source = try await serveur.source()

        try await source.publier(ProgressionDistante(
            identifiantChapitre: Self.livre,
            pageAtteinte: 0,
            estLu: true
        ))

        let corps = try #require(await serveur.transport.derniere?.corpsJson())

        // Komga refuse par un 400 une page superieure au nombre de pages, et ce
        // nombre est justement inconnu quand le marquage vient de la liste.
        #expect(corps["page"] == nil)
        #expect(corps["completed"] as? Bool == true)
    }

    @Test("Une page au dela du chapitre est ramenee a la derniere")
    func pageBorneeAuChapitre() async throws {
        let serveur = ServeurKomgaDeTest(ServeurKomgaDeTest.reglesCompletes)
        let source = try await serveur.source()

        try await source.publier(ProgressionDistante(
            identifiantChapitre: Self.livre,
            pageAtteinte: 99,
            nombreDePages: 20
        ))

        let corps = try #require(await serveur.transport.derniere?.corpsJson())

        #expect(corps["page"] as? Int == 20)
    }

    @Test("Une progression lue puis republiee repart sur la meme page")
    func allerRetourSansDerive() async throws {
        let serveur = ServeurKomgaDeTest(ServeurKomgaDeTest.reglesCompletes)
        let source = try await serveur.source()
        let lue = try #require(await source.progression(pour: Self.livre))

        try await source.publier(lue)

        let corps = try #require(await serveur.transport.derniere?.corpsJson())

        // Le serveur avait annonce la page 7. Il doit la retrouver telle quelle.
        #expect(corps["page"] as? Int == 7)
    }

    // MARK: Effacement

    @Test("Marquer non lu efface la progression cote serveur")
    func effacement() async throws {
        let serveur = ServeurKomgaDeTest(ServeurKomgaDeTest.reglesCompletes)
        let source = try await serveur.source()

        try await source.effacerLaProgression(pour: Self.livre)

        let envoyee = try #require(await serveur.transport.derniere)

        #expect(envoyee.methode == "DELETE")
        #expect(envoyee.chemin.hasSuffix("/api/v1/books/\(Self.livre)/read-progress"))
    }

    // MARK: Part lue

    @Test("La part lue compte la page atteinte comme lue")
    func partLue() {
        let debut = ProgressionDistante(identifiantChapitre: "livre", pageAtteinte: 0, nombreDePages: 20)
        let fin = ProgressionDistante(identifiantChapitre: "livre", pageAtteinte: 19, nombreDePages: 20)
        let inconnue = ProgressionDistante(identifiantChapitre: "livre", pageAtteinte: 5)

        #expect(abs(debut.part - 0.05) < 0.0001)
        #expect(fin.part == 1)
        // Sans nombre de pages, la part reste nulle plutot que de diviser par
        // zero et de marquer lu tout ce qui s ouvre.
        #expect(inconnue.part == 0)
    }

    @Test("Un index de page negatif est ramene a zero")
    func indexNegatifRamene() {
        let progression = ProgressionDistante(
            identifiantChapitre: "livre",
            pageAtteinte: -3,
            nombreDePages: 20
        )

        #expect(progression.pageAtteinte == 0)
    }
}
