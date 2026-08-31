import Core
import Foundation
import Sources
import Testing
@testable import Sync

//
// Couvre le troisieme critere : la synchronisation automatique respecte le mode
// incognito.
//
// La verification porte sur le transport et non sur la valeur rendue. Une
// decision qui dit ne pas envoyer tout en ayant deja envoye serait une
// regression invisible a l ecran et parfaitement visible chez le service de
// suivi, qui est le seul endroit ou l utilisateur decouvrirait la fuite. Le
// journal du transport fige repond a la seule question qui compte : est ce que
// quelque chose est parti.
//

@Suite("Synchronisation automatique et mode incognito")
struct SynchronisationAutomatiqueTests {
    /// Reglages ou l envoi automatique est actif et sans confirmation.
    static var envoiActif: ReglagesDeLApplication {
        var reglages = ReglagesDeLApplication.parDefaut
        reglages.definir(.booleen(true), pour: .envoyerLaProgression)
        reglages.definir(.booleen(false), pour: .confirmerAvantDEnvoyer)

        return reglages
    }

    /// Conditions d une installation abonnee, envoi actif.
    static var conditions: ConditionsDEnvoi {
        ConditionsDEnvoi(reglages: envoiActif)
    }

    /// Liaison arretee au chapitre 10 sur le service donne.
    static func liaison(pour service: ServiceDeSuivi, identifiant: String) -> LiaisonSuivi {
        LiaisonSuivi(
            mangaId: UUID(),
            service: service,
            identifiantDistant: identifiant,
            chapitreVu: 10
        )
    }

    @Test("Une progression neuve part vers le service")
    func envoiNominal() async throws {
        let atelier = try await AtelierDeSuivi(service: .aniList).avecPublication()
        try await atelier.connecter()

        let avant = await atelier.transport.journal.count
        let resultat = try await atelier.registre.synchroniser(
            Self.liaison(pour: .aniList, identifiant: "11"),
            chapitreLu: 12,
            aupresDe: .aniList,
            selon: Self.conditions
        )

        #expect(resultat.decision == .envoyer)
        #expect(resultat.liaison?.chapitreVu == 12)
        #expect(resultat.liaison?.dateSynchronisation == AtelierDeSuivi.maintenant)
        #expect(await atelier.transport.journal.count > avant)
    }

    @Test("Le chapitre publie est bien celui qui vient d etre lu")
    func chapitrePublie() async throws {
        let atelier = try await AtelierDeSuivi(service: .myAnimeList).avecPublication()
        try await atelier.connecter()

        _ = try await atelier.registre.synchroniser(
            Self.liaison(pour: .myAnimeList, identifiant: "21"),
            chapitreLu: 12,
            aupresDe: .myAnimeList,
            selon: Self.conditions
        )

        let publication = try #require(await atelier.transport.requetes(vers: "/my_list_status").last)

        #expect(publication.methode == "PATCH")
        #expect(publication.texteDuCorps.contains("num_chapters_read=12"))
        #expect(publication.entete("Content-Type") == "application/x-www-form-urlencoded")
    }

    @Test("Une session incognito n envoie rien du tout", arguments: ServiceDeSuivi.allCases)
    func incognitoNEnvoieRien(service: ServiceDeSuivi) async throws {
        let incognito = RegistreDIncognito()
        let atelier = try await AtelierDeSuivi(service: service, incognito: incognito).avecPublication()
        try await atelier.connecter()

        incognito.demarrer()
        let avant = await atelier.transport.journal.count

        let resultat = try await atelier.registre.synchroniser(
            Self.liaison(pour: service, identifiant: "11"),
            chapitreLu: 12,
            aupresDe: service,
            selon: Self.conditions
        )

        #expect(resultat.decision == .suspendueParIncognito)
        #expect(resultat.liaison == nil)
        #expect(await atelier.transport.journal.count == avant)
    }

    @Test("La banniere ne tombe pas et rien ne part apres plusieurs chapitres")
    func incognitoTientTouteLaSession() async throws {
        let incognito = RegistreDIncognito()
        let atelier = try await AtelierDeSuivi(service: .kitsu, incognito: incognito).avecPublication()
        try await atelier.connecter()

        incognito.demarrer()
        let avant = await atelier.transport.journal.count
        var liaison = Self.liaison(pour: .kitsu, identifiant: "31")

        for chapitre in 11...15 {
            let resultat = try await atelier.registre.synchroniser(
                liaison,
                chapitreLu: Double(chapitre),
                aupresDe: .kitsu,
                selon: Self.conditions
            )

            #expect(resultat.decision == .suspendueParIncognito)
            liaison = resultat.liaison ?? liaison
        }

        #expect(liaison.chapitreVu == 10)
        #expect(incognito.sessionCourante.porteLaBanniere)
        #expect(await atelier.transport.journal.count == avant)
    }

    @Test("La session arretee laisse repartir la progression accumulee")
    func repriseApresIncognito() async throws {
        let incognito = RegistreDIncognito()
        let atelier = try await AtelierDeSuivi(service: .aniList, incognito: incognito).avecPublication()
        try await atelier.connecter()

        incognito.demarrer()
        _ = try await atelier.registre.synchroniser(
            Self.liaison(pour: .aniList, identifiant: "11"),
            chapitreLu: 15,
            aupresDe: .aniList,
            selon: Self.conditions
        )

        incognito.arreter()
        let resultat = try await atelier.registre.synchroniser(
            Self.liaison(pour: .aniList, identifiant: "11"),
            chapitreLu: 15,
            aupresDe: .aniList,
            selon: Self.conditions
        )

        #expect(resultat.decision == .envoyer)
        #expect(resultat.liaison?.chapitreVu == 15)
    }

    @Test("L interrupteur inactif n envoie rien non plus")
    func envoiDesactive() async throws {
        let atelier = try await AtelierDeSuivi(service: .aniList).avecPublication()
        try await atelier.connecter()

        let avant = await atelier.transport.journal.count
        let resultat = try await atelier.registre.synchroniser(
            Self.liaison(pour: .aniList, identifiant: "11"),
            chapitreLu: 12,
            aupresDe: .aniList,
            selon: ConditionsDEnvoi(reglages: .parDefaut)
        )

        #expect(resultat.decision == .desactiveeParReglage)
        #expect(await atelier.transport.journal.count == avant)
    }

    @Test("Un service deconnecte n envoie rien")
    func serviceDeconnecte() async throws {
        let atelier = try await AtelierDeSuivi(service: .aniList).avecPublication()
        let avant = await atelier.transport.journal.count

        let resultat = try await atelier.registre.synchroniser(
            Self.liaison(pour: .aniList, identifiant: "11"),
            chapitreLu: 12,
            aupresDe: .aniList,
            selon: Self.conditions
        )

        #expect(resultat.decision == .serviceDeconnecte)
        #expect(await atelier.transport.journal.count == avant)
    }

    @Test("Une serie non liee n envoie rien")
    func serieNonLiee() async throws {
        let atelier = try await AtelierDeSuivi(service: .aniList).avecPublication()
        try await atelier.connecter()

        let avant = await atelier.transport.journal.count
        let resultat = try await atelier.registre.synchroniser(
            nil,
            chapitreLu: 12,
            aupresDe: .aniList,
            selon: Self.conditions
        )

        #expect(resultat.decision == .aucuneLiaison)
        #expect(await atelier.transport.journal.count == avant)
    }

    @Test("Le service qui tient une entree de bibliotheque la modifie au lieu de la recreer")
    func entreeExistanteModifiee() async throws {
        let atelier = try await AtelierDeSuivi(service: .kitsu).avecPublication()
        try await atelier.connecter()

        _ = try await atelier.registre.synchroniser(
            Self.liaison(pour: .kitsu, identifiant: "31"),
            chapitreLu: 12,
            aupresDe: .kitsu,
            selon: Self.conditions
        )

        let publication = try #require(await atelier.transport.requetes(vers: "/library-entries/9001").last)

        #expect(publication.methode == "PATCH")
        #expect(publication.texteDuCorps.contains("\"progress\":12"))
    }

    @Test("Sans entree de bibliotheque, la publication en cree une")
    func entreeAbsenteCreee() async throws {
        let atelier = try await AtelierDeSuivi(service: .kitsu).avecPublication()
        try await atelier.connecter()
        await atelier.servir(.json(.get, "/library-entries", ReponsesFigeesDesSuivis.entreeKitsuAbsente))

        _ = try await atelier.registre.synchroniser(
            Self.liaison(pour: .kitsu, identifiant: "31"),
            chapitreLu: 12,
            aupresDe: .kitsu,
            selon: Self.conditions
        )

        let publication = try #require(await atelier.transport.requetes(vers: "/library-entries").last)

        #expect(publication.methode == "POST")
        #expect(publication.texteDuCorps.contains("\"manga\""))
        #expect(publication.texteDuCorps.contains("\"users\""))
    }

    @Test("Une progression deja connue du service ne repart pas")
    func dejaAJour() async throws {
        let atelier = try await AtelierDeSuivi(service: .aniList).avecPublication()
        try await atelier.connecter()

        let avant = await atelier.transport.journal.count
        let resultat = try await atelier.registre.synchroniser(
            Self.liaison(pour: .aniList, identifiant: "11"),
            chapitreLu: 10,
            aupresDe: .aniList,
            selon: Self.conditions
        )

        #expect(resultat.decision == .dejaAJour)
        #expect(await atelier.transport.journal.count == avant)
    }

    @Test("La confirmation demandee retient l envoi jusqu a l accord")
    func confirmationDemandee() async throws {
        let atelier = try await AtelierDeSuivi(service: .aniList).avecPublication()
        try await atelier.connecter()

        var reglages = Self.envoiActif
        reglages.definir(.booleen(true), pour: .confirmerAvantDEnvoyer)

        let avant = await atelier.transport.journal.count
        let refuse = try await atelier.registre.synchroniser(
            Self.liaison(pour: .aniList, identifiant: "11"),
            chapitreLu: 12,
            aupresDe: .aniList,
            selon: ConditionsDEnvoi(reglages: reglages)
        )

        #expect(refuse.decision == .confirmationRequise)
        #expect(await atelier.transport.journal.count == avant)

        let accorde = try await atelier.registre.synchroniser(
            Self.liaison(pour: .aniList, identifiant: "11"),
            chapitreLu: 12,
            aupresDe: .aniList,
            selon: ConditionsDEnvoi(reglages: reglages, confirmationAccordee: true)
        )

        #expect(accorde.decision == .envoyer)
    }
}
