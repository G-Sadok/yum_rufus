import Core
import Foundation
import Testing
@testable import Sources

//
// AnalyseDesReponsesKomgaTests
//
// Couvre le troisieme critere de la fonctionnalite : des tests avec reponses
// figees couvrent l analyse des reponses.
//
// La strategie de test nomme quatre cas et ils sont tous ici : une reponse
// figee de la source, une reponse malformee, une reponse vide, une reponse
// tronquee. S y ajoutent les codes de refus du serveur, qui sont l autre moitie
// de ce qu une source distante recoit reellement, et la garantie qu une source
// en echec ne fait pas tomber les autres.
//

struct AnalyseDesReponsesKomgaTests {
    private static let nom = "Komga de test"

    // MARK: Reponses illisibles

    @Test("Une reponse qui n est pas du JSON est nommee illisible")
    func reponseMalformee() async throws {
        let serveur = ServeurKomgaDeTest([
            .json(.get, "api/v1/series", ReponsesFigeesDeKomga.malformee),
        ])
        let source = try await serveur.source()

        await #expect(throws: ErreurDeSource.reseau(.reponseIllisible, source: Self.nom)) {
            _ = try await source.parcourir(.tout, page: 0)
        }
    }

    @Test("Une reponse sans aucun octet est nommee vide, pas illisible")
    func reponseVide() async throws {
        let serveur = ServeurKomgaDeTest([.vide("api/v1/series")])
        let source = try await serveur.source()

        // La distinction compte : une reponse vide se repare en reessayant, une
        // reponse illisible se repare en corrigeant l adresse de la source.
        await #expect(throws: ErreurDeSource.reseau(.reponseVide, source: Self.nom)) {
            _ = try await source.parcourir(.tout, page: 0)
        }
    }

    @Test("Une reponse plus courte que sa longueur annoncee est nommee tronquee")
    func reponseTronquee() async throws {
        let serveur = ServeurKomgaDeTest([
            .tronquee("api/v1/series", ReponsesFigeesDeKomga.troncature, annonce: 4096),
        ])
        let source = try await serveur.source()

        await #expect(throws: ErreurDeSource.reseau(.reponseTronquee, source: Self.nom)) {
            _ = try await source.parcourir(.tout, page: 0)
        }
    }

    @Test("Une reponse plus longue que sa longueur annoncee n est pas rejetee")
    func longueurAnnonceeTropCourte() async throws {
        // Un serveur qui compte mal ne perd aucune donnee. Rejeter sa reponse
        // rendrait la source inutilisable pour une erreur sans consequence.
        let serveur = ServeurKomgaDeTest([
            .tronquee("api/v1/series", ReponsesFigeesDeKomga.premiereTrancheDeSeries, annonce: 10),
        ])
        let source = try await serveur.source()
        let catalogue = try await source.parcourir(.tout, page: 0)

        #expect(catalogue.elements.count == 2)
    }

    // MARK: Codes de refus

    @Test("Un serveur qui demande de ralentir rend son delai")
    func tropDeRequetes() async throws {
        let serveur = ServeurKomgaDeTest([
            .statut("api/v1/series", 429, entetes: ["Retry-After": "30"]),
        ])
        let source = try await serveur.source()
        let attendue = ErreurDeSource.reseau(
            .tropDeRequetes(secondesAvantNouvelEssai: 30),
            source: Self.nom
        )

        await #expect(throws: attendue) {
            _ = try await source.parcourir(.tout, page: 0)
        }
    }

    @Test("Une panne du serveur est distinguee d un refus definitif")
    func pannePassagere() async throws {
        let serveur = ServeurKomgaDeTest([.statut("api/v1/series", 503)])
        let source = try await serveur.source()

        await #expect(throws: ErreurDeSource.reseau(.pannePassagere(code: 503), source: Self.nom)) {
            _ = try await source.parcourir(.tout, page: 0)
        }
    }

    @Test("Un compte sans droit est un refus d acces, pas un refus d identifiants")
    func accesRefuse() async throws {
        let serveur = ServeurKomgaDeTest([.statut("api/v1/series", 403)])
        let source = try await serveur.source()

        await #expect(throws: ErreurDeSource.reseau(.accesRefuse, source: Self.nom)) {
            _ = try await source.parcourir(.tout, page: 0)
        }
    }

    // MARK: Forme des tranches

    @Test("Une tranche sans drapeau de fin se lit sur son total de pages")
    func trancheSansDrapeauDeFin() throws {
        let sansDrapeau = """
        {"content": [], "number": 1, "totalPages": 3}
        """
        let derniere = """
        {"content": [], "number": 2, "totalPages": 3}
        """
        let muette = """
        {"content": []}
        """

        #expect(try Self.tranche(sansDrapeau).ilResteDesPages)
        #expect(try Self.tranche(derniere).ilResteDesPages == false)
        // Sans drapeau ni total, la tranche est traitee comme la derniere :
        // promettre une suite inexistante ferait tourner le defilement infini.
        #expect(try Self.tranche(muette).ilResteDesPages == false)
    }

    // MARK: Lecture des dates

    @Test("Les trois formes de date rendues par Komga sont lues")
    func formesDeDate() {
        #expect(LecteurDeDateDeServeur.lire("1990-11-26") == DatesDeTest.jour(1990, 11, 26))
        #expect(
            LecteurDeDateDeServeur.lire("2026-02-04T07:10:00Z")
                == DatesDeTest.instant(2026, 2, 4, HeureDeTest(7, 10))
        )
        // Komga publie ses horodatages en temps universel sans le dire.
        #expect(
            LecteurDeDateDeServeur.lire("2026-02-03T18:24:05")
                == DatesDeTest.instant(2026, 2, 3, HeureDeTest(18, 24, 5))
        )
    }

    @Test("Une fraction de seconde ne fait pas perdre la date")
    func dateAvecFraction() throws {
        let lue = try #require(LecteurDeDateDeServeur.lire("2026-02-03T18:24:05.123Z"))
        let attendue = try #require(DatesDeTest.instant(2026, 2, 3, HeureDeTest(18, 24, 5)))

        #expect(abs(lue.timeIntervalSince(attendue) - 0.123) < 0.001)
    }

    @Test("Une date absente ou vide reste absente")
    func dateAbsente() {
        #expect(LecteurDeDateDeServeur.lire(nil) == nil)
        #expect(LecteurDeDateDeServeur.lire("   ") == nil)
        #expect(LecteurDeDateDeServeur.lire("hier") == nil)
    }

    // MARK: Vocabulaire

    @Test("Les statuts de Komga sont traduits dans les deux sens")
    func statutsTraduits() {
        #expect(StatutSerie.depuisKomga("ONGOING") == .enCours)
        #expect(StatutSerie.depuisKomga("ENDED") == .termine)
        #expect(StatutSerie.depuisKomga("HIATUS") == .enPause)
        #expect(StatutSerie.depuisKomga("ABANDONED") == .abandonne)
        // Un statut ajoute par une version future ne fait pas echouer la serie.
        #expect(StatutSerie.depuisKomga("CANCELLED_BY_PUBLISHER") == .inconnu)
        #expect(StatutSerie.depuisKomga(nil) == .inconnu)

        for statut in StatutSerie.allCases where statut != .inconnu {
            #expect(StatutSerie.depuisKomga(statut.motDeKomga) == statut)
        }

        #expect(StatutSerie.inconnu.motDeKomga == nil)
    }

    // MARK: Isolation des sources

    @Test("Une source en echec ne fait pas tomber les autres")
    func sourceEnEchecIsolee() async throws {
        let saine = ServeurKomgaDeTest(ServeurKomgaDeTest.reglesCompletes)
        let cassee = ServeurKomgaDeTest([
            .json(.get, "api/v1/series", ReponsesFigeesDeKomga.malformee),
        ])
        let registre = RegistreDeSources()

        try await registre.inscrire(saine.source())
        try await registre.inscrire(cassee.source())

        let resultats = await registre.parcourir(.tout, page: 0)

        #expect(resultats.count == 2)
        #expect(resultats[0].valeur?.elements.count == 2)
        #expect(resultats[1].erreur == .reseau(.reponseIllisible, source: cassee.nom))
    }

    // MARK: Outils

    /// Decode une tranche de series depuis une reponse figee.
    private static func tranche(_ corps: String) throws -> PageDeKomga<SerieDeKomga> {
        try JSONDecoder().decode(PageDeKomga<SerieDeKomga>.self, from: Data(corps.utf8))
    }
}
