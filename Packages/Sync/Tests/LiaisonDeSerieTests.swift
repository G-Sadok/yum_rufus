import Core
import Foundation
import Sources
import Testing
@testable import Sync

//
// Couvre le deuxieme critere : la liaison propose des correspondances et permet
// la correction manuelle.
//
// Les quatre services sont interroges avec la meme reponse figee, ecrite dans
// leur propre dialecte. C est ce qui verifie que les quatre analyses rendent la
// meme chose : un service dont l analyse rendrait un titre vide proposerait
// zero candidat, et la liaison deviendrait impossible sur ce service seul, sans
// que rien d autre ne le signale.
//

@Suite("Liaison d une serie avec un service")
struct LiaisonDeSerieTests {
    @Test("Chaque service propose ses entrees pour un titre", arguments: ServiceDeSuivi.allCases)
    func propositionParService(service: ServiceDeSuivi) async throws {
        let atelier = try await AtelierDeSuivi(service: service).avecRecherche()
        try await atelier.connecter()

        let proposition = try await atelier.registre.proposerUneLiaison(
            pourTitre: "Le Voyage du Heros",
            annee: 2014,
            aupresDe: service
        )
        let meilleur = try #require(proposition.meilleur)

        #expect(meilleur.serie.titre == "Le Voyage du Heros")
        #expect(meilleur.score >= CorrespondanceDeSuivi.seuilDeCertitude)
        #expect(meilleur.serie.id.isEmpty == false)
    }

    @Test("Les entrees sans rapport ne sont pas proposees")
    func entreesEcartees() async throws {
        let atelier = try await AtelierDeSuivi(service: .kitsu).avecRecherche()
        try await atelier.connecter()

        let proposition = try await atelier.registre.proposerUneLiaison(
            pourTitre: "Le Voyage du Heros",
            aupresDe: .kitsu
        )

        #expect(proposition.candidats.count == 1)
        #expect(proposition.candidats.contains { $0.serie.titre == "Chroniques du Sud" } == false)
    }

    @Test("Une suite est proposee derriere l original")
    func suiteDerriereLOriginal() async throws {
        let atelier = try await AtelierDeSuivi(service: .aniList).avecRecherche()
        try await atelier.connecter()

        let proposition = try await atelier.registre.proposerUneLiaison(
            pourTitre: "Le Voyage du Heros",
            aupresDe: .aniList
        )

        #expect(proposition.candidats.count == 2)
        #expect(proposition.candidats.map(\.serie.id) == ["11", "12"])
    }

    @Test("L utilisateur peut retenir un candidat autre que le premier")
    func correctionManuelle() async throws {
        let atelier = try await AtelierDeSuivi(service: .aniList).avecRecherche()
        try await atelier.connecter()

        let manga = UUID()
        let proposition = try await atelier.registre.proposerUneLiaison(
            pourTitre: "Le Voyage du Heros",
            aupresDe: .aniList
        )
        let second = try #require(proposition.candidats.last?.serie)
        let liaison = await atelier.registre.lier(manga, vers: second, aupresDe: .aniList)

        #expect(liaison.identifiantDistant == "12")
        #expect(liaison.mangaId == manga)
        #expect(liaison.service == .aniList)
    }

    @Test("La recherche part avec le titre demande")
    func titreEnvoye() async throws {
        let atelier = try await AtelierDeSuivi(service: .myAnimeList).avecRecherche()
        try await atelier.connecter()

        _ = try await atelier.registre.proposerUneLiaison(pourTitre: "Le Voyage du Heros", aupresDe: .myAnimeList)

        let recherche = try #require(await atelier.transport.requetes(vers: "/manga").last)

        #expect(recherche.parametre("q") == "Le Voyage du Heros")
        #expect(recherche.parametre("fields")?.contains("start_date") == true)
    }

    @Test("Une reponse vide ne propose rien et ne fait rien tomber")
    func reponseVide() async throws {
        let atelier = try AtelierDeSuivi(service: .kitsu)
        try await atelier.connecter()
        await atelier.servir(.json(.get, "/manga", #"{"data": []}"#))

        let proposition = try await atelier.registre.proposerUneLiaison(
            pourTitre: "Le Voyage du Heros",
            aupresDe: .kitsu
        )

        #expect(proposition.candidats.isEmpty)
        #expect(proposition.demandeUnChoix)
    }

    @Test("Une reponse malformee remonte une erreur nommee")
    func reponseMalformee() async throws {
        let atelier = try AtelierDeSuivi(service: .kitsu)
        try await atelier.connecter()
        await atelier.servir(.json(.get, "/manga", "{ceci n est pas du json"))

        await #expect(throws: ErreurDeSuivi.reponseIllisible(service: .kitsu)) {
            _ = try await atelier.registre.proposerUneLiaison(pourTitre: "Le Voyage du Heros", aupresDe: .kitsu)
        }
    }
}
