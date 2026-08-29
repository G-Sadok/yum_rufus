import Core
import Foundation
import Sources
import Testing
@testable import Sync

//
// Couvre le renouvellement du jeton, qui decide de ce que l utilisateur voit
// quand une session vieillit.
//
// Sans lui, une connexion etablie une fois cesserait de valoir au bout de
// l heure que le service accorde, et la seule sortie serait une reconnexion par
// le navigateur a chaque session de lecture. Avec lui, la reconnexion ne
// s impose plus que dans le seul cas ou elle est inevitable : un service qui
// n emet aucun jeton de rafraichissement, ou un renouvellement lui meme refuse.
//

@Suite("Renouvellement du jeton d un service")
struct RenouvellementDuJetonTests {
    /// Un jeton deja perime, avec de quoi le renouveler.
    static let jetonPerime = IdentifiantsDeSource.jeton(
        acces: "jeton-perime",
        rafraichissement: "renouvellement",
        expiration: Date(timeIntervalSince1970: 1_600_000_000)
    )

    @Test("Un jeton perime est renouvele avant que la requete parte")
    func renouvellementAvantLaRequete() async throws {
        let atelier = try await AtelierDeSuivi(service: .myAnimeList).avecRecherche()
        try await atelier.connecter()
        try await atelier.magasin.enregistrer(Self.jetonPerime, pour: .myAnimeList)

        _ = try await atelier.registre.proposerUneLiaison(pourTitre: "Le Voyage du Heros", aupresDe: .myAnimeList)

        let recherche = try #require(await atelier.transport.requetes(vers: "/manga").last)
        let echange = try #require(await atelier.transport.requetes(vers: "/oauth2/token").last)

        #expect(recherche.entete("Authorization") == "Bearer jeton-neuf")
        #expect(echange.texteDuCorps.contains("grant_type=refresh_token"))
        #expect(echange.texteDuCorps.contains("refresh_token=renouvellement"))
    }

    @Test("Le jeton renouvele remplace celui du magasin")
    func jetonRange() async throws {
        let atelier = try await AtelierDeSuivi(service: .myAnimeList).avecRecherche()
        try await atelier.connecter()
        try await atelier.magasin.enregistrer(Self.jetonPerime, pour: .myAnimeList)

        _ = try await atelier.registre.proposerUneLiaison(pourTitre: "Le Voyage du Heros", aupresDe: .myAnimeList)

        guard case let .jeton(acces, rafraichissement, expiration) =
            await atelier.magasin.identifiants(pour: .myAnimeList)
        else {
            Issue.record("le magasin devrait porter un jeton")

            return
        }

        #expect(acces == "jeton-neuf")
        #expect(rafraichissement == "renouvellement")
        #expect(expiration == AtelierDeSuivi.maintenant.addingTimeInterval(3600))
    }

    @Test("Un renouvellement refuse laisse le service demander une reconnexion")
    func renouvellementRefuse() async throws {
        let atelier = try await AtelierDeSuivi(service: .myAnimeList).avecRecherche()
        try await atelier.connecter()
        try await atelier.magasin.enregistrer(Self.jetonPerime, pour: .myAnimeList)

        // Le service refuse le renouvellement, puis refuse le jeton perime.
        await atelier.servir(.json(.post, "/oauth2/token", #"{"error": "invalid_grant"}"#, code: 400))
        await atelier.servir(.statut(.get, "/manga", 401))

        await #expect(throws: ErreurDeSuivi.reconnexionNecessaire(service: .myAnimeList)) {
            _ = try await atelier.registre.proposerUneLiaison(
                pourTitre: "Le Voyage du Heros",
                aupresDe: .myAnimeList
            )
        }
    }

    @Test("Un jeton sans echeance part tel quel, sans renouvellement inutile")
    func jetonSansEcheance() async throws {
        let atelier = try await AtelierDeSuivi(service: .mangaUpdates).avecRecherche()
        try await atelier.connecter()

        let avant = await atelier.transport.requetes(vers: "/account/login").count
        _ = try await atelier.registre.proposerUneLiaison(pourTitre: "Le Voyage du Heros", aupresDe: .mangaUpdates)

        let recherche = try #require(await atelier.transport.requetes(vers: "/series/search").last)

        #expect(recherche.entete("Authorization") == "Bearer jeton-de-session")
        #expect(await atelier.transport.requetes(vers: "/account/login").count == avant)
    }

    @Test("Un jeton refuse fait passer le service en expire")
    func jetonRefuseParLeService() async throws {
        let atelier = try await AtelierDeSuivi(service: .aniList).avecPublication()
        try await atelier.connecter()

        await atelier.servir(.statut(.post, "graphql.anilist.co", 401))

        await #expect(throws: ErreurDeSuivi.reconnexionNecessaire(service: .aniList)) {
            _ = try await atelier.registre.synchroniser(
                LiaisonSuivi(mangaId: UUID(), service: .aniList, identifiantDistant: "11", chapitreVu: 10),
                chapitreLu: 12,
                aupresDe: .aniList,
                selon: ConditionsDEnvoi(
                    reglages: SynchronisationAutomatiqueTests.envoiActif,
                    premium: .definitif
                )
            )
        }

        #expect(await atelier.registre.etatDesServices.servicesExpires == [.aniList])
        #expect(await atelier.registre.etatDesServices[.aniList].peutEnvoyer == false)
    }
}
