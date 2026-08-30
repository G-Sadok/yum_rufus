import Core
import Foundation
import Testing
@testable import Sync

//
// Ce que la veille remet a l utilisateur, F060.
//
// Deux criteres sont mesures ici sur le moteur complet, la ou les regles pures
// de Core le sont sur les fonctions elles memes : les notifications sont
// regroupees par serie, et aucune n est emise en mode incognito. Les deux
// niveaux sont utiles, une regle juste appelee au mauvais endroit ne protege de
// rien.
//
// Les quotas ont leur propre suite, `QuotasDeLaVeilleEnArrierePlanTests`.
//

struct VeilleDeNouveauxChapitresTests {
    // MARK: Regroupement

    @Test("Deux series et douze chapitres donnent deux notifications")
    func regroupementParSerie() async {
        let source = SourceDeChapitresDeTest(chapitresParSerie: [
            "serie-1": (0..<7).map { .deTest("s1-c\($0)", serie: "serie-1", ordre: $0) },
            "serie-2": (0..<5).map { .deTest("s2-c\($0)", serie: "serie-2", ordre: $0) },
        ])

        let magasin = MagasinDeVeilleEnMemoire(series: [
            serieSurveillee(1, source: source.id, connus: ["s1-c0"]),
            serieSurveillee(2, source: source.id, connus: ["s2-c0"]),
        ])
        let centre = CentreDeNotificationsDeTest()

        let veille = await moteurDeVeille(
            source: source,
            magasin: magasin,
            centre: centre,
            horloge: HorlogeDeTest(depart: midiDeVeille)
        )

        let rapport = await veille.tic()

        #expect(rapport.decision == .verifier)
        #expect(rapport.seriesInterrogees == 2)
        #expect(rapport.notifications.count == 2)
        #expect(rapport.notifications.map(\.nombreDeChapitres) == [6, 4])

        // Une seule remise au centre, deux notifications dedans : la couche
        // systeme n a aucun moyen d en emettre une par chapitre.
        let emissions = await centre.emissions
        #expect(emissions.count == 1)
        #expect(emissions.first?.count == 2)
    }

    @Test("Une serie deja a jour ne produit aucune notification")
    func aucuneNouveaute() async {
        let source = SourceDeChapitresDeTest(chapitresParSerie: [
            "serie-1": [.deTest("s1-c0", serie: "serie-1", ordre: 0)],
        ])
        let magasin = MagasinDeVeilleEnMemoire(series: [
            serieSurveillee(1, source: source.id, connus: ["s1-c0"]),
        ])
        let centre = CentreDeNotificationsDeTest()

        let veille = await moteurDeVeille(
            source: source,
            magasin: magasin,
            centre: centre,
            horloge: HorlogeDeTest(depart: midiDeVeille)
        )

        let rapport = await veille.tic()

        #expect(rapport.notifications.isEmpty)
        #expect(await centre.emissions.isEmpty)

        // La serie a bien ete vue, ce qui la fait passer en fin de file.
        #expect(await magasin.verifications.count == 1)
    }

    @Test("Une premiere visite prend connaissance sans notifier")
    func premiereVisiteSilencieuse() async {
        let source = SourceDeChapitresDeTest(chapitresParSerie: [
            "serie-1": (0..<40).map { .deTest("s1-c\($0)", serie: "serie-1", ordre: $0) },
        ])
        let magasin = MagasinDeVeilleEnMemoire(series: [
            serieSurveillee(1, source: source.id, connus: [], vueLe: nil),
        ])
        let centre = CentreDeNotificationsDeTest()

        let veille = await moteurDeVeille(
            source: source,
            magasin: magasin,
            centre: centre,
            horloge: HorlogeDeTest(depart: midiDeVeille)
        )

        #expect(await veille.tic().notifications.isEmpty)
        #expect(await centre.notificationsEmises.isEmpty)
    }

    // MARK: Mode incognito

    @Test("Une session incognito ne laisse partir aucune notification")
    func incognitoAvantLExecution() async {
        let source = SourceDeChapitresDeTest(chapitresParSerie: [
            "serie-1": [.deTest("s1-c1", serie: "serie-1", ordre: 1)],
        ])
        let magasin = MagasinDeVeilleEnMemoire(series: [serieSurveillee(1, source: source.id, connus: [])])
        let centre = CentreDeNotificationsDeTest()
        let incognito = RegistreDIncognito()
        incognito.demarrer(le: midiDeVeille)

        let veille = await moteurDeVeille(
            source: source,
            magasin: magasin,
            centre: centre,
            horloge: HorlogeDeTest(depart: midiDeVeille),
            incognito: incognito
        )

        let rapport = await veille.tic()

        #expect(rapport.decision == .suspendueParIncognito)
        #expect(await centre.notificationsEmises.isEmpty)

        // Rien n a ete interroge non plus : la session ne se contente pas de
        // faire taire, elle empeche le travail.
        #expect(await source.seriesInterrogees.isEmpty)
        #expect(await magasin.enregistrements == 0)
    }

    @Test("Une session ouverte pendant que les sources repondent fait taire l emission")
    func incognitoPendantLExecution() async {
        let incognito = RegistreDIncognito()
        let source = SourceDeChapitresDeTest(
            chapitresParSerie: ["serie-1": [.deTest("s1-c1", serie: "serie-1", ordre: 1)]],
            aLInterrogation: { incognito.demarrer(le: midiDeVeille) }
        )
        let magasin = MagasinDeVeilleEnMemoire(series: [serieSurveillee(1, source: source.id, connus: [])])
        let centre = CentreDeNotificationsDeTest()

        let veille = await moteurDeVeille(
            source: source,
            magasin: magasin,
            centre: centre,
            horloge: HorlogeDeTest(depart: midiDeVeille),
            incognito: incognito
        )

        let rapport = await veille.tic()

        #expect(rapport.decision == .verifier)
        #expect(rapport.seriesInterrogees == 1)
        #expect(rapport.notifications.isEmpty)
        #expect(await centre.emissions.isEmpty)
    }

    @Test("Sans autorisation du systeme, aucune source n est interrogee")
    func autorisationRefusee() async {
        let source = SourceDeChapitresDeTest(chapitresParSerie: [
            "serie-1": [.deTest("s1-c1", serie: "serie-1", ordre: 1)],
        ])
        let magasin = MagasinDeVeilleEnMemoire(series: [serieSurveillee(1, source: source.id, connus: [])])
        let centre = CentreDeNotificationsDeTest(autorisation: false)

        let veille = await moteurDeVeille(
            source: source,
            magasin: magasin,
            centre: centre,
            horloge: HorlogeDeTest(depart: midiDeVeille)
        )

        #expect(await veille.tic().decision == .autorisationRefusee)
        #expect(await source.seriesInterrogees.isEmpty)
    }

    // MARK: Isolation des sources

    @Test("Une source en echec n empeche pas les autres d etre relues")
    func isolationDesSources() async {
        let tombee = SourceDeChapitresDeTest(
            nom: "Serveur tombe",
            chapitresParSerie: ["serie-1": []],
            echoue: true
        )
        let vivante = SourceDeChapitresDeTest(
            nom: "Serveur vivant",
            chapitresParSerie: ["serie-2": [.deTest("s2-c1", serie: "serie-2", ordre: 1)]]
        )

        let registre = RegistreDeSources()
        await registre.inscrire(tombee)
        await registre.inscrire(vivante)

        let magasin = MagasinDeVeilleEnMemoire(series: [
            serieSurveillee(1, source: tombee.id, connus: []),
            serieSurveillee(2, source: vivante.id, connus: ["s2-c0"]),
        ])
        let centre = CentreDeNotificationsDeTest()

        let veille = moteurDeVeille(
            registre: registre,
            magasin: magasin,
            centre: centre,
            horloge: HorlogeDeTest(depart: midiDeVeille)
        )

        let rapport = await veille.tic()

        #expect(rapport.sourcesEnEchec == 1)
        #expect(rapport.notifications.count == 1)
        #expect(rapport.notifications.first?.titreDeLaSerie == "Serie 2")
    }
}
