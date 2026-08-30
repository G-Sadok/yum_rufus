import Foundation
import Testing
@testable import Core

//
// Veille de nouveaux chapitres, F060.
//
// Le premier critere, la verification en arriere plan respecte les quotas du
// systeme, est mesure ici et non dans le moteur : les trois limites sont des
// fonctions pures, et une suite qui avance une horloge simulee les couvre sans
// attendre quatre heures ni demander un reveil au systeme.
//

/// Calendrier fixe, pour que les journees civiles ne dependent pas du fuseau de
/// la machine qui lance la suite.
private func calendrierDeTest() -> Calendar {
    var calendrier = Calendar(identifier: .gregorian)
    calendrier.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt

    return calendrier
}

/// Reglages ou l interrupteur de la section General est arme.
private var veilleArmee: ReglagesDeLApplication {
    ReglagesDeLApplication([.notificationsDeNouveauxChapitres: .booleen(true)])
}

/// Instant de reference, un mercredi a midi.
private let midi = Date(timeIntervalSince1970: 1_700_000_000)

struct QuotasDeLaVeilleTests {
    private let calendrier = calendrierDeTest()

    // MARK: Interrupteur, autorisation, incognito

    @Test("Sans reglage arme, aucune verification ne part")
    func reglageInactif() {
        let contexte = ContexteDeVeille(reglages: .parDefaut)

        #expect(
            VeilleDeChapitres.decision(etat: .neuf, selon: contexte, le: midi, calendrier: calendrier)
                == .desactiveeParReglage
        )
    }

    @Test("Sans autorisation accordee, rien n est interroge")
    func autorisationRefusee() {
        let contexte = ContexteDeVeille(reglages: veilleArmee, autorisationAccordee: false)

        #expect(
            VeilleDeChapitres.decision(etat: .neuf, selon: contexte, le: midi, calendrier: calendrier)
                == .autorisationRefusee
        )
    }

    @Test("Le mode incognito passe avant toutes les autres questions")
    func incognitoGagneToujours() {
        // Tout est par ailleurs favorable : reglage arme, autorisation
        // accordee, reseau present, aucune execution recente.
        let contexte = ContexteDeVeille(
            reglages: veilleArmee,
            session: .demarree(le: midi),
            autorisationAccordee: true,
            enLigne: true
        )

        #expect(
            VeilleDeChapitres.decision(etat: .neuf, selon: contexte, le: midi, calendrier: calendrier)
                == .suspendueParIncognito
        )
    }

    @Test("Toutes conditions reunies, la verification part")
    func verificationAutorisee() {
        let contexte = ContexteDeVeille(reglages: veilleArmee)
        let decision = VeilleDeChapitres.decision(etat: .neuf, selon: contexte, le: midi, calendrier: calendrier)

        #expect(decision == .verifier)
        #expect(decision.verifie)
        #expect(decision.prochaineTentative == nil)
    }

    // MARK: Intervalle minimal

    @Test("Une verification trop proche de la precedente est refusee")
    func intervalleNonEcoule() {
        let quota = QuotaDeVeille.parDefaut
        let etat = EtatDeVeille(
            derniereTentative: midi,
            jourCompte: calendrier.startOfDay(for: midi),
            executionsDuJour: 1
        )
        let contexte = ContexteDeVeille(reglages: veilleArmee)

        let tropTot = midi.addingTimeInterval(quota.intervalleMinimal - 1)
        let attendue = DecisionDeVeille.intervalleNonEcoule(
            prochaine: midi.addingTimeInterval(quota.intervalleMinimal)
        )

        #expect(
            VeilleDeChapitres.decision(etat: etat, selon: contexte, le: tropTot, calendrier: calendrier) == attendue
        )
        #expect(attendue.prochaineTentative == midi.addingTimeInterval(quota.intervalleMinimal))
    }

    @Test("Passe l intervalle minimal, la verification repart")
    func intervalleEcoule() {
        let quota = QuotaDeVeille.parDefaut
        let etat = EtatDeVeille(
            derniereTentative: midi,
            jourCompte: calendrier.startOfDay(for: midi),
            executionsDuJour: 1
        )
        let contexte = ContexteDeVeille(reglages: veilleArmee)
        let plusTard = midi.addingTimeInterval(quota.intervalleMinimal)

        #expect(
            VeilleDeChapitres.decision(etat: etat, selon: contexte, le: plusTard, calendrier: calendrier) == .verifier
        )
    }

    // MARK: Plafond quotidien

    @Test("Le plafond quotidien coupe les executions, et repart le lendemain")
    func plafondQuotidien() {
        let quota = QuotaDeVeille.parDefaut
        var etat = EtatDeVeille.neuf
        var instant = calendrier.startOfDay(for: midi)
        var lancees = 0

        // Une journee entiere de reveils toutes les quinze minutes, ce que le
        // systeme peut tout a fait offrir sur un appareil tres utilise.
        let contexte = ContexteDeVeille(reglages: veilleArmee)

        for _ in 0..<96 {
            let decision = VeilleDeChapitres.decision(
                etat: etat,
                quota: quota,
                selon: contexte,
                le: instant,
                calendrier: calendrier
            )

            if decision.verifie {
                etat.compterUneExecution(le: instant, calendrier: calendrier)
                etat.compterUneReussite(le: instant)
                lancees += 1
            }

            instant = instant.addingTimeInterval(15 * 60)
        }

        // Vingt quatre heures a quatre heures d intervalle donnent six departs,
        // et le plafond quotidien vaut six : les deux limites concordent.
        #expect(lancees == quota.executionsParJour)
        #expect(etat.executions(le: instant.addingTimeInterval(-15 * 60), calendrier: calendrier) == 6)
    }

    @Test("Le compteur quotidien ne vaut que pour son propre jour")
    func compteurRemisALeroLeLendemain() {
        var etat = EtatDeVeille.neuf
        etat.compterUneExecution(le: midi, calendrier: calendrier)

        let lendemain = midi.addingTimeInterval(24 * 3600)

        #expect(etat.executions(le: midi, calendrier: calendrier) == 1)
        #expect(etat.executions(le: lendemain, calendrier: calendrier) == 0)
    }

    @Test("Le plafond atteint renvoie au debut du jour civil suivant")
    func prochaineTentativeApresPlafond() throws {
        let quota = QuotaDeVeille.parDefaut
        let etat = EtatDeVeille(
            derniereTentative: midi.addingTimeInterval(-quota.intervalleMinimal),
            jourCompte: calendrier.startOfDay(for: midi),
            executionsDuJour: quota.executionsParJour
        )

        let decision = VeilleDeChapitres.decision(
            etat: etat,
            quota: quota,
            selon: ContexteDeVeille(reglages: veilleArmee),
            le: midi,
            calendrier: calendrier
        )

        let prochaine = try #require(decision.prochaineTentative)

        #expect(decision == .quotaQuotidienAtteint(prochaine: prochaine))
        #expect(calendrier.isDate(prochaine, inSameDayAs: midi) == false)
        #expect(prochaine == calendrier.startOfDay(for: midi.addingTimeInterval(24 * 3600)))
    }

    // MARK: Recul apres echec

    @Test("Le recul double a chaque echec consecutif et s arrete au plafond")
    func reculExponentiel() {
        let quota = QuotaDeVeille.parDefaut

        #expect(quota.recul(apres: 0) == 0)
        #expect(quota.recul(apres: 1) == quota.reculInitial)
        #expect(quota.recul(apres: 2) == quota.reculInitial * 2)
        #expect(quota.recul(apres: 3) == quota.reculInitial * 4)
        #expect(quota.recul(apres: 40) == quota.reculMaximal)
    }

    @Test("Une source en echec n est pas martelee")
    func reculApresEchec() {
        let quota = QuotaDeVeille.parDefaut
        let etat = EtatDeVeille(derniereTentative: midi, echecsConsecutifs: 1)
        let contexte = ContexteDeVeille(reglages: veilleArmee)

        let pendantLeRecul = midi.addingTimeInterval(quota.reculInitial - 1)
        let apresLeRecul = midi.addingTimeInterval(quota.reculInitial)

        #expect(
            VeilleDeChapitres.decision(etat: etat, selon: contexte, le: pendantLeRecul, calendrier: calendrier)
                == .reculApresEchec(prochaine: apresLeRecul)
        )
        #expect(
            VeilleDeChapitres.decision(etat: etat, selon: contexte, le: apresLeRecul, calendrier: calendrier)
                == .verifier
        )
    }

    @Test("Une reussite efface les echecs accumules")
    func reussiteRemetLeCompteurAZero() {
        var etat = EtatDeVeille.neuf
        etat.compterUnEchec()
        etat.compterUnEchec()

        #expect(etat.echecsConsecutifs == 2)

        etat.compterUneReussite(le: midi)

        #expect(etat.echecsConsecutifs == 0)
        #expect(etat.derniereReussite == midi)
    }

    // MARK: Reseau

    @Test("Hors ligne, rien n est interroge et la question est reposee au reveil suivant")
    func horsLigne() {
        let contexte = ContexteDeVeille(reglages: veilleArmee, enLigne: false)
        let decision = VeilleDeChapitres.decision(etat: .neuf, selon: contexte, le: midi, calendrier: calendrier)

        #expect(decision == .differeeHorsLigne)
        #expect(decision.prochaineTentative == nil)
    }

    // MARK: Budget de temps

    @Test("Le nombre de series par execution tient dans le budget de temps accorde")
    func budgetDeTempsTenable() {
        let quota = QuotaDeVeille.parDefaut

        // Une source distante qui repond en un quart de seconde par serie est
        // deja lente pour une simple liste de chapitres.
        #expect(quota.tientDansLeBudget(delaiParSerie: 0.25))
        #expect(quota.tientDansLeBudget(delaiParSerie: 2) == false)
        #expect(quota.budgetDeTemps < 30)
    }
}

/// Rotation des series interrogees, qui fait tenir le plafond par execution sans
/// jamais abandonner une serie.
struct RotationDeLaVeilleTests {
    private func serie(_ rang: Int, vue: Date?) -> SerieSurveillee {
        SerieSurveillee(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000\(String(format: "%02d", rang))") ?? UUID(),
            source: SourceID(),
            identifiantDistant: "serie-\(rang)",
            titre: "Serie \(rang)",
            derniereVerification: vue
        )
    }

    @Test("Une execution n interroge pas plus de series que le quota ne l accorde")
    func plafondParExecution() {
        let quota = QuotaDeVeille.parDefaut
        let series = (0..<50).map { serie($0, vue: midi.addingTimeInterval(Double($0))) }

        #expect(VeilleDeChapitres.seriesAInterroger(series, quota: quota).count == quota.seriesParExecution)
    }

    @Test("Les series jamais vues passent devant, puis les plus anciennes")
    func ordreDeRotation() {
        let jamaisVue = serie(3, vue: nil)
        let ancienne = serie(1, vue: midi.addingTimeInterval(-3600))
        let recente = serie(2, vue: midi)

        let choisies = VeilleDeChapitres.seriesAInterroger([recente, ancienne, jamaisVue])

        #expect(choisies.map(\.id) == [jamaisVue.id, ancienne.id, recente.id])
    }

    @Test("Deux executions successives ne reprennent pas les memes series")
    func aucuneSerieOubliee() {
        let quota = QuotaDeVeille(
            intervalleMinimal: 4 * 3600,
            executionsParJour: 6,
            budgetDeTemps: 25,
            seriesParExecution: 2,
            reculInitial: 60,
            reculMaximal: 3600
        )

        var series = (0..<6).map { serie($0, vue: nil) }
        var vues: Set<UUID> = []
        var instant = midi

        for _ in 0..<3 {
            let tour = VeilleDeChapitres.seriesAInterroger(series, quota: quota)

            #expect(tour.count == 2)

            for choisie in tour {
                #expect(vues.contains(choisie.id) == false, "la serie \(choisie.titre) est reprise trop tot")
                vues.insert(choisie.id)
            }

            let interrogees = Set(tour.map(\.id))
            let momentDuTour = instant

            series = series.map { serie in
                guard interrogees.contains(serie.id) else {
                    return serie
                }

                return SerieSurveillee(
                    id: serie.id,
                    source: serie.source,
                    identifiantDistant: serie.identifiantDistant,
                    titre: serie.titre,
                    chapitresConnus: serie.chapitresConnus,
                    derniereVerification: momentDuTour
                )
            }

            instant = instant.addingTimeInterval(quota.intervalleMinimal)
        }

        #expect(vues.count == 6)
    }
}
