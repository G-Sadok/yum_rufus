import Core
import Foundation
import Testing
@testable import Sync

//
// Le premier critere de F060 mesure sur le moteur complet : la verification en
// arriere plan respecte les quotas du systeme.
//
// Les trois limites sont eprouvees separement, chacune par le chemin qu elle
// protege : le plafond quotidien contre une journee de reveils rapproches,
// l intervalle minimal contre deux reveils qui se suivent, le budget de temps
// contre une bibliotheque plus grande que ce qu une execution peut tenir.
//
// S y ajoute le refus de travailler sans etat lisible, qui est la meme regle
// vue par l autre bout : une veille qui ne sait pas ce qu elle a deja fait ne
// peut tenir aucune limite, elle s abstient donc.
//

struct QuotasDeLaVeilleEnArrierePlanTests {
    private let calendrier = calendrierDeVeille()

    @Test("Une journee de reveils rapproches ne donne que six executions")
    func plafondQuotidienTenu() async {
        let source = SourceDeChapitresDeTest(chapitresParSerie: ["serie-1": []])
        let magasin = MagasinDeVeilleEnMemoire(series: [serieSurveillee(1, source: source.id, connus: [])])
        let centre = CentreDeNotificationsDeTest()
        let horloge = HorlogeDeTest(depart: calendrier.startOfDay(for: midiDeVeille))

        let veille = await moteurDeVeille(
            source: source,
            magasin: magasin,
            centre: centre,
            horloge: horloge
        )

        var executions = 0

        // Un reveil toutes les quinze minutes pendant vingt quatre heures.
        for _ in 0..<96 {
            if await veille.tic().aTravaille {
                executions += 1
            }

            horloge.avancer(de: 15 * 60)
        }

        #expect(executions == QuotaDeVeille.parDefaut.executionsParJour)
        #expect(await source.seriesInterrogees.count == executions)
    }

    @Test("Un reveil trop proche du precedent est refuse sans rien interroger")
    func intervalleMinimalTenu() async {
        let source = SourceDeChapitresDeTest(chapitresParSerie: ["serie-1": []])
        let magasin = MagasinDeVeilleEnMemoire(series: [serieSurveillee(1, source: source.id, connus: [])])
        let centre = CentreDeNotificationsDeTest()
        let horloge = HorlogeDeTest(depart: midiDeVeille)

        let veille = await moteurDeVeille(source: source, magasin: magasin, centre: centre, horloge: horloge)

        #expect(await veille.tic().aTravaille)

        horloge.avancer(de: 60 * 60)

        let refus = await veille.tic()

        #expect(refus.decision.verifie == false)
        #expect(refus.decision.prochaineTentative != nil)
        #expect(await source.seriesInterrogees.count == 1)
    }

    @Test("Le budget de temps arrete l execution et laisse les series suivantes au tour d apres")
    func budgetDeTempsTenu() async {
        let chapitres = Dictionary(
            uniqueKeysWithValues: (1...6).map { numero in
                ("serie-\(numero)", [ChapitreDistant.deTest("s\(numero)-c0", serie: "serie-\(numero)", ordre: 0)])
            }
        )

        let source = SourceDeChapitresDeTest(chapitresParSerie: chapitres)
        let magasin = MagasinDeVeilleEnMemoire(
            series: (1...6).map { serieSurveillee($0, source: source.id, connus: ["s\($0)-c0"]) }
        )
        let centre = CentreDeNotificationsDeTest()

        // Chaque lecture d horloge avance de dix secondes : le budget de vingt
        // cinq secondes est depasse au bout de trois series.
        let horloge = HorlogeDeTest(depart: midiDeVeille, pasParLecture: 10)

        let veille = await moteurDeVeille(source: source, magasin: magasin, centre: centre, horloge: horloge)
        let rapport = await veille.tic()

        #expect(rapport.interrompue)
        #expect(rapport.seriesInterrogees < 6)
        #expect(await source.seriesInterrogees.count == rapport.seriesInterrogees)
    }

    @Test("Une source en echec fait reculer la veille au lieu de la marteler")
    func reculApresEchec() async {
        let source = SourceDeChapitresDeTest(chapitresParSerie: ["serie-1": []], echoue: true)
        let magasin = MagasinDeVeilleEnMemoire(series: [serieSurveillee(1, source: source.id, connus: [])])
        let centre = CentreDeNotificationsDeTest()
        let horloge = HorlogeDeTest(depart: midiDeVeille)

        let veille = await moteurDeVeille(source: source, magasin: magasin, centre: centre, horloge: horloge)
        let rapport = await veille.tic()

        #expect(rapport.sourcesEnEchec == 1)
        #expect(await magasin.etatCourant.echecsConsecutifs == 1)

        // Le recul initial vaut trente minutes, un reveil dix minutes plus tard
        // est donc refuse.
        horloge.avancer(de: 10 * 60)

        #expect(await veille.tic().decision.verifie == false)
    }

    @Test("Sans etat lisible, la veille refuse de travailler plutot que d ignorer ses quotas")
    func magasinIndisponible() async {
        let source = SourceDeChapitresDeTest(chapitresParSerie: ["serie-1": []])
        let magasin = MagasinDeVeilleEnMemoire(
            series: [serieSurveillee(1, source: source.id, connus: [])],
            echoueALaLecture: true
        )
        let centre = CentreDeNotificationsDeTest()

        let veille = await moteurDeVeille(
            source: source,
            magasin: magasin,
            centre: centre,
            horloge: HorlogeDeTest(depart: midiDeVeille)
        )

        #expect(await veille.tic().decision.verifie == false)
        #expect(await source.seriesInterrogees.isEmpty)
    }

    @Test("Une source qui ne declare pas la veille n est jamais interrogee")
    func sourceSansCapacite() async {
        let muette = SourceDeChapitresDeTest(
            nom: "Dossier local",
            capacites: [.recherche, .pagination],
            chapitresParSerie: ["serie-1": [.deTest("s1-c1", serie: "serie-1", ordre: 1)]]
        )
        let declarante = SourceDeChapitresDeTest(
            nom: "Serveur",
            chapitresParSerie: ["serie-2": [.deTest("s2-c1", serie: "serie-2", ordre: 1)]]
        )

        let registre = RegistreDeSources()
        await registre.inscrire(muette)
        await registre.inscrire(declarante)

        let magasin = MagasinDeVeilleEnMemoire(series: [
            serieSurveillee(1, source: muette.id, connus: []),
            serieSurveillee(2, source: declarante.id, connus: []),
        ])
        let centre = CentreDeNotificationsDeTest()

        let veille = moteurDeVeille(
            registre: registre,
            magasin: magasin,
            centre: centre,
            horloge: HorlogeDeTest(depart: midiDeVeille)
        )

        let rapport = await veille.tic()

        #expect(rapport.seriesInterrogees == 1)
        #expect(await muette.seriesInterrogees.isEmpty)
        #expect(await declarante.seriesInterrogees == ["serie-2"])
    }
}
