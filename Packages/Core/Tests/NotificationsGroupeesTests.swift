import Foundation
import Testing
@testable import Core

//
// Regroupement des notifications, F060.
//
// Les deux derniers criteres sont mesures ici : les notifications sont
// regroupees par serie, et aucune n est emise en mode incognito. Les deux
// portent sur la meme fonction, parce que c est le seul chemin par lequel une
// notification peut naitre.
//

/// Fabrique une nouveaute, avec le strict necessaire pour la reconnaitre.
private func nouveaute(
    serie: UUID,
    titreDeLaSerie: String,
    numero: Double,
    ordre: Int,
    source: SourceID = SourceID()
) -> NouveauChapitre {
    NouveauChapitre(
        serie: serie,
        titreDeLaSerie: titreDeLaSerie,
        source: source,
        identifiant: "\(titreDeLaSerie)-\(numero)",
        numero: numero,
        ordre: ordre
    )
}

struct NotificationsGroupeesParSerieTests {
    private let berserk = UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID()
    private let vagabond = UUID(uuidString: "22222222-2222-2222-2222-222222222222") ?? UUID()

    @Test("Douze chapitres de deux series donnent deux notifications, pas douze")
    func uneNotificationParSerie() {
        let chapitres =
            (0..<7).map { nouveaute(serie: berserk, titreDeLaSerie: "Berserk", numero: Double($0), ordre: $0) }
                + (0..<5).map { nouveaute(serie: vagabond, titreDeLaSerie: "Vagabond", numero: Double($0), ordre: $0) }

        let notifications = RegroupementDeNotifications.notifications(pour: chapitres)

        #expect(notifications.count == 2)
        #expect(notifications.map(\.nombreDeChapitres) == [7, 5])
        #expect(Set(notifications.map(\.serie)) == [berserk, vagabond])
    }

    @Test("Une notification porte tous les chapitres de sa serie et aucun autre")
    func aucuneFuiteEntreSeries() throws {
        let chapitres = [
            nouveaute(serie: berserk, titreDeLaSerie: "Berserk", numero: 375, ordre: 375),
            nouveaute(serie: vagabond, titreDeLaSerie: "Vagabond", numero: 328, ordre: 328),
            nouveaute(serie: berserk, titreDeLaSerie: "Berserk", numero: 376, ordre: 376),
        ]

        let notifications = RegroupementDeNotifications.notifications(pour: chapitres)
        let premiere = try #require(notifications.first)

        #expect(premiere.serie == berserk)
        #expect(premiere.chapitres.allSatisfy { $0.serie == berserk })
        #expect(premiere.chapitres.map(\.numero) == [375, 376])
    }

    @Test("Les chapitres d une notification sont ordonnes par leur rang dans la serie")
    func chapitresOrdonnes() throws {
        let melanges = [
            nouveaute(serie: berserk, titreDeLaSerie: "Berserk", numero: 12, ordre: 12),
            nouveaute(serie: berserk, titreDeLaSerie: "Berserk", numero: 10, ordre: 10),
            nouveaute(serie: berserk, titreDeLaSerie: "Berserk", numero: 10.5, ordre: 11),
        ]

        let notification = try #require(RegroupementDeNotifications.notifications(pour: melanges).first)

        #expect(notification.chapitres.map(\.numero) == [10, 10.5, 12])
        #expect(notification.dernierChapitre?.numero == 12)
    }

    @Test("L identifiant de fil est celui de la serie, pour empiler les executions successives")
    func identifiantDeRegroupement() throws {
        let premiere = try #require(
            RegroupementDeNotifications
                .notifications(pour: [nouveaute(serie: berserk, titreDeLaSerie: "Berserk", numero: 1, ordre: 1)])
                .first
        )
        let seconde = try #require(
            RegroupementDeNotifications
                .notifications(pour: [nouveaute(serie: berserk, titreDeLaSerie: "Berserk", numero: 2, ordre: 2)])
                .first
        )

        #expect(premiere.identifiantDeRegroupement == seconde.identifiantDeRegroupement)
        #expect(premiere.identifiantDeRegroupement.contains(berserk.uuidString))
        #expect(premiere.id == berserk)
    }

    @Test("L ordre d emission ne depend pas de l ordre d arrivee")
    func ordreStable() {
        let chapitres = [
            nouveaute(serie: vagabond, titreDeLaSerie: "Vagabond", numero: 1, ordre: 1),
            nouveaute(serie: berserk, titreDeLaSerie: "Berserk", numero: 1, ordre: 1),
        ]

        let premierPassage = RegroupementDeNotifications.notifications(pour: chapitres)
        let secondPassage = RegroupementDeNotifications.notifications(pour: chapitres.reversed())

        #expect(premierPassage.map(\.titreDeLaSerie) == ["Berserk", "Vagabond"])
        #expect(premierPassage == secondPassage)
    }

    @Test("Sans nouveaute, aucune notification n est construite")
    func aucuneNouveaute() {
        #expect(RegroupementDeNotifications.notifications(pour: []).isEmpty)
    }
}

struct AucuneNotificationEnIncognitoTests {
    private let berserk = UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID()

    @Test("Une session incognito fait taire toutes les notifications")
    func sessionActive() {
        let chapitres = (0..<20).map {
            nouveaute(serie: berserk, titreDeLaSerie: "Berserk", numero: Double($0), ordre: $0)
        }

        let session = SessionIncognito.demarree(le: Date(timeIntervalSince1970: 1_700_000_000))

        #expect(RegroupementDeNotifications.notifications(pour: chapitres, session: session).isEmpty)
    }

    @Test("La session ouverte pendant la verification fait taire ce qui allait partir")
    func sessionOuverteEnCoursDeRoute() {
        let chapitres = [nouveaute(serie: berserk, titreDeLaSerie: "Berserk", numero: 1, ordre: 1)]

        // La verification a commence hors session, les sources ont repondu, et
        // l utilisateur a arme l incognito entre temps. C est l etat au moment
        // de l emission qui tranche.
        var session = SessionIncognito.inactive
        #expect(RegroupementDeNotifications.notifications(pour: chapitres, session: session).isEmpty == false)

        session.demarrer(le: Date(timeIntervalSince1970: 1_700_000_100))
        #expect(RegroupementDeNotifications.notifications(pour: chapitres, session: session).isEmpty)
    }

    @Test("La session refermee laisse repartir les notifications suivantes")
    func apresLaSession() {
        var session = SessionIncognito.demarree(le: Date(timeIntervalSince1970: 1_700_000_000))
        session.arreter()

        let chapitres = [nouveaute(serie: berserk, titreDeLaSerie: "Berserk", numero: 1, ordre: 1)]

        #expect(RegroupementDeNotifications.notifications(pour: chapitres, session: session).count == 1)
    }

    @Test("Aucun evenement de session ne rouvre la porte aux notifications")
    func permanenceDeLaSession() {
        let depart = SessionIncognito.demarree(le: Date(timeIntervalSince1970: 1_700_000_000))
        let chapitres = [nouveaute(serie: berserk, titreDeLaSerie: "Berserk", numero: 1, ordre: 1)]

        for evenement in EvenementDeSession.allCases {
            let session = depart.apres(evenement)

            #expect(
                RegroupementDeNotifications.notifications(pour: chapitres, session: session).isEmpty,
                "\(evenement)"
            )
        }
    }
}

struct DetectionDesNouveautesTests {
    private let serie = SerieSurveillee(
        id: UUID(uuidString: "33333333-3333-3333-3333-333333333333") ?? UUID(),
        source: SourceID(),
        identifiantDistant: "berserk",
        titre: "Berserk",
        chapitresConnus: ["c1", "c2"],
        derniereVerification: Date(timeIntervalSince1970: 1_699_000_000)
    )

    private func chapitre(_ identifiant: String, ordre: Int) -> ChapitreDistant {
        ChapitreDistant(
            identifiant: identifiant,
            identifiantManga: "berserk",
            numero: Double(ordre),
            ordre: ordre
        )
    }

    @Test("Seuls les chapitres inconnus de cet appareil sont annonces")
    func chapitresInedits() {
        let annonces = [chapitre("c1", ordre: 1), chapitre("c2", ordre: 2), chapitre("c3", ordre: 3)]
        let nouveautes = NouveautesDeSerie.nouveautes(de: serie, annonces: annonces)

        #expect(nouveautes.map(\.identifiant) == ["c3"])
        #expect(nouveautes.first?.titreDeLaSerie == "Berserk")
    }

    @Test("Un chapitre retire puis remplace est detecte, alors que le compte n a pas bouge")
    func detectionParIdentifiantEtNonParNombre() {
        let annonces = [chapitre("c1", ordre: 1), chapitre("c9", ordre: 2)]

        #expect(NouveautesDeSerie.nouveautes(de: serie, annonces: annonces).map(\.identifiant) == ["c9"])
    }

    @Test("Une premiere visite prend connaissance sans rien annoncer")
    func premiereVisiteSilencieuse() {
        let jamaisVue = SerieSurveillee(
            id: UUID(),
            source: SourceID(),
            identifiantDistant: "vinland",
            titre: "Vinland Saga",
            chapitresConnus: [],
            derniereVerification: nil
        )

        let annonces = (0..<200).map { chapitre("c\($0)", ordre: $0) }

        #expect(jamaisVue.estUnePremiereVisite)
        #expect(NouveautesDeSerie.nouveautes(de: jamaisVue, annonces: annonces).isEmpty)
        #expect(NouveautesDeSerie.chapitresInedits(de: jamaisVue, annonces: annonces).count == 200)
    }
}
