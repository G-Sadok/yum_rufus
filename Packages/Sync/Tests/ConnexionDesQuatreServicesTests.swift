import Core
import Foundation
import Sources
import Testing
@testable import Sync

//
// Couvre le premier critere de la fonctionnalite : les quatre services se
// connectent et se deconnectent proprement.
//
// Le mot proprement est verifie a trois endroits pour chaque service. Le jeton
// entre dans le magasin a la connexion, il en sort a la deconnexion, et l etat
// suit les deux. Un test qui n aurait verifie que l etat aurait laisse passer
// un jeton oublie dans le trousseau, ce qui est exactement la fuite que la
// section 11 interdit.
//

@Suite("Connexion et deconnexion des quatre services")
struct ConnexionDesQuatreServicesTests {
    @Test("Chaque service se connecte, range son jeton et nomme son compte", arguments: ServiceDeSuivi.allCases)
    func connexionParService(service: ServiceDeSuivi) async throws {
        let atelier = try AtelierDeSuivi(service: service)
        let compte = try await atelier.connecter()

        #expect(compte.pseudonyme == "lectrice")
        #expect(await atelier.magasin.identifiants(pour: service).estVide == false)
        #expect(await atelier.registre.etatDesServices[service] == .connecte(compte))
        #expect(await atelier.registre.etatDesServices.nombreDeServicesConnectes == 1)
    }

    @Test("Chaque service se deconnecte sans laisser de jeton", arguments: ServiceDeSuivi.allCases)
    func deconnexionParService(service: ServiceDeSuivi) async throws {
        let atelier = try AtelierDeSuivi(service: service)
        _ = try await atelier.connecter()

        try await atelier.registre.deconnecter(service)

        #expect(await atelier.magasin.identifiants(pour: service) == .aucun)
        #expect(await atelier.magasin.servicesConnus.isEmpty)
        #expect(await atelier.registre.etatDesServices[service] == .deconnecte)
        #expect(await atelier.registre.etatDesServices.estVide)
    }

    @Test("Une requete part avec le jeton en porteur", arguments: ServiceDeSuivi.allCases)
    func jetonPresente(service: ServiceDeSuivi) async throws {
        let atelier = try AtelierDeSuivi(service: service)
        _ = try await atelier.connecter()

        let attendu = service == .mangaUpdates ? "Bearer jeton-de-session" : "Bearer jeton-neuf"
        let derniere = try #require(await atelier.transport.derniere)

        #expect(derniere.entete("Authorization") == attendu)
    }

    @Test("Un service deconnecte refuse la recherche sans rien envoyer")
    func rechercheSansConnexion() async throws {
        let atelier = try AtelierDeSuivi(service: .kitsu)
        let avant = await atelier.transport.journal.count

        await #expect(throws: ErreurDeSuivi.serviceDeconnecte(service: .kitsu)) {
            _ = try await atelier.registre.proposerUneLiaison(pourTitre: "Le Voyage du Heros", aupresDe: .kitsu)
        }

        #expect(await atelier.transport.journal.count == avant)
    }

    @Test("Une deconnexion suivie d une reconnexion repart d un jeton neuf")
    func reconnexion() async throws {
        let atelier = try AtelierDeSuivi(service: .aniList)
        _ = try await atelier.connecter()
        try await atelier.registre.deconnecter(.aniList)

        let compte = try await atelier.connecter()

        #expect(await atelier.registre.etatDesServices[.aniList] == .connecte(compte))
        #expect(await atelier.magasin.identifiants(pour: .aniList).estVide == false)
    }

    @Test("Le refus du service a l echange nomme le motif et ne range rien")
    func echangeRefuse() async throws {
        let atelier = try AtelierDeSuivi(
            service: .kitsu,
            reglesSupplementaires: [
                .json(.post, "/oauth/token", #"{"error": "invalid_grant"}"#, code: 400),
            ]
        )

        await #expect(throws: ErreurDeSuivi.autorisationRefusee(service: .kitsu, motif: "invalid_grant")) {
            _ = try await atelier.connecter()
        }

        #expect(await atelier.magasin.identifiants(pour: .kitsu) == .aucun)
        #expect(await atelier.registre.etatDesServices.estVide)
    }

    @Test("Un jeton refuse par le service fait passer l etat en expire")
    func jetonRefuseParLeService() async throws {
        let atelier = try AtelierDeSuivi(service: .myAnimeList)
        _ = try await atelier.connecter()

        // Le service cesse d accepter le jeton. La lecture du compte echoue,
        // le compte reste connu, et la ligne des reglages doit proposer une
        // reconnexion plutot qu une connexion.
        await atelier.transport.prioriser(.statut(.get, "/users/@me", 401))

        #expect(await atelier.registre.rafraichir()[.myAnimeList].peutEnvoyer == false)
        #expect(await atelier.registre.etatDesServices.servicesExpires == [.myAnimeList])
    }

    @Test("La deconnexion de tous les services les efface tous")
    func deconnexionDeTous() async throws {
        let atelier = try AtelierDeSuivi(service: .aniList)
        _ = try await atelier.connecter()

        try await atelier.registre.deconnecterTout()

        #expect(await atelier.magasin.servicesConnus.isEmpty)
        #expect(await atelier.registre.etatDesServices.estVide)
    }
}
