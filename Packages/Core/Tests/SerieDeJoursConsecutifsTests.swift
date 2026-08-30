import Foundation
import Testing
@testable import Core

//
// La serie de jours consecutifs de F059.
//
// Les journees sont posees en jours civils d un calendrier fixe, pas en
// intervalles de vingt quatre heures. Un test ecrit avec des additions de
// quatre vingt six mille quatre cents secondes passerait onze mois par an et
// echouerait au changement d heure.
//

struct SerieDeJoursConsecutifsTests {
    /// Calendrier fixe, pour que la suite ne depende pas du reglage de la
    /// machine qui l execute.
    private var calendrier: Calendar {
        var calendrier = Calendar(identifier: .gregorian)
        calendrier.timeZone = TimeZone(identifier: "Europe/Paris") ?? .gmt
        return calendrier
    }

    /// Reference stable, un mardi.
    private var aujourdHui: Date {
        Date(timeIntervalSince1970: 1_700_000_000)
    }

    /// Journee posee a `recul` jours avant la reference.
    private func journee(ilYA recul: Int, chapitres: Int) -> JourneeDeLecture {
        let debut = calendrier.startOfDay(for: aujourdHui)
        let jour = calendrier.date(byAdding: .day, value: -recul, to: debut) ?? debut

        return JourneeDeLecture(jour: jour, chapitresLus: chapitres, pagesLues: chapitres * 20)
    }

    private func longueur(
        _ journees: [JourneeDeLecture],
        objectif: ObjectifQuotidien = .desactive
    ) -> Int {
        SerieDeJoursConsecutifs.longueur(
            journees: journees,
            objectif: objectif,
            le: aujourdHui,
            calendrier: calendrier
        )
    }

    // MARK: Comptage

    @Test("Aucune journee ne donne aucune serie")
    func aucuneJournee() {
        #expect(longueur([]) == 0)
    }

    @Test("Trois jours de suite jusqu au jour en cours donnent trois")
    func troisJoursDeSuite() {
        let journees = [
            journee(ilYA: 2, chapitres: 1),
            journee(ilYA: 1, chapitres: 2),
            journee(ilYA: 0, chapitres: 1),
        ]

        #expect(longueur(journees) == 3)
    }

    @Test("Un trou coupe la serie a l endroit du trou")
    func leTrouCoupeLaSerie() {
        let journees = [
            journee(ilYA: 5, chapitres: 3),
            journee(ilYA: 4, chapitres: 3),
            // Rien le troisieme jour.
            journee(ilYA: 2, chapitres: 1),
            journee(ilYA: 1, chapitres: 1),
            journee(ilYA: 0, chapitres: 1),
        ]

        #expect(longueur(journees) == 3)
    }

    @Test("Une journee sans chapitre lu ne compte pas, meme si elle existe en base")
    func journeeSansChapitre() {
        let journees = [
            JourneeDeLecture(jour: journee(ilYA: 1, chapitres: 0).jour, chapitresLus: 0, pagesLues: 12),
            journee(ilYA: 0, chapitres: 1),
        ]

        #expect(longueur(journees) == 1)
    }

    // MARK: La journee en cours ne casse pas la serie

    @Test("Une journee pas encore commencee ne remet pas la serie a zero")
    func laJourneeNonCommenceeNeCassePas() {
        let journees = [
            journee(ilYA: 3, chapitres: 2),
            journee(ilYA: 2, chapitres: 2),
            journee(ilYA: 1, chapitres: 2),
        ]

        // La serie s arrete a hier et vaut trois. Annoncer zero a une personne
        // qui n a pas encore ouvert l application ce matin serait le reproche
        // que le troisieme critere de F059 ecarte.
        #expect(longueur(journees) == 3)
    }

    @Test("Deux jours sans lecture arretent bien la serie")
    func deuxJoursSansLectureArretent() {
        let journees = [
            journee(ilYA: 4, chapitres: 2),
            journee(ilYA: 3, chapitres: 2),
            journee(ilYA: 2, chapitres: 2),
        ]

        #expect(longueur(journees) == 0)
    }

    // MARK: L objectif decide de ce qui compte

    @Test("Avec un objectif, seules les journees qui l atteignent comptent")
    func lObjectifDecide() {
        let journees = [
            journee(ilYA: 2, chapitres: 3),
            journee(ilYA: 1, chapitres: 1),
            journee(ilYA: 0, chapitres: 3),
        ]

        #expect(longueur(journees, objectif: ObjectifQuotidien(chapitresParJour: 3)) == 1)
        #expect(longueur(journees, objectif: .desactive) == 3)
    }

    @Test("Changer l objectif recalcule la serie sur les memes journees")
    func changerLObjectifRecalcule() {
        let journees = (0..<5).map { recul in journee(ilYA: recul, chapitres: 2) }

        #expect(longueur(journees, objectif: ObjectifQuotidien(chapitresParJour: 2)) == 5)
        #expect(longueur(journees, objectif: ObjectifQuotidien(chapitresParJour: 3)) == 0)
    }

    // MARK: Vue d ensemble

    @Test("L instantane expose la meme serie que le calcul")
    func instantaneCoherent() {
        let journees = [
            journee(ilYA: 1, chapitres: 2),
            journee(ilYA: 0, chapitres: 2),
        ]

        let instantane = StatistiquesDeLecture(
            journees: journees,
            objectif: .desactive,
            le: aujourdHui,
            calendrier: calendrier
        )

        #expect(instantane.serieDeJours == 2)
        #expect(instantane.joursDeLecture == 2)
        #expect(instantane.totalDeChapitres == 4)
        #expect(instantane.totalDePages == 80)
        #expect(instantane.estVide == false)
    }

    @Test("La carte des derniers jours porte sept journees, trous compris")
    func septJournees() {
        let instantane = StatistiquesDeLecture(
            journees: [journee(ilYA: 0, chapitres: 2)],
            objectif: .desactive,
            le: aujourdHui,
            calendrier: calendrier
        )

        let derniers = instantane.derniersJours

        #expect(derniers.count == StatistiquesDeLecture.joursMontres)
        #expect(derniers.count == 7)
        #expect(derniers.map(\.chapitresLus) == [0, 0, 0, 0, 0, 0, 2])
        #expect(derniers.last?.jour == calendrier.startOfDay(for: aujourdHui))
        #expect(instantane.maximumDesDerniersJours == 2)
    }

    @Test("Une semaine sans lecture ne divise jamais par zero")
    func semaineVide() {
        let instantane = StatistiquesDeLecture(
            journees: [],
            objectif: .desactive,
            le: aujourdHui,
            calendrier: calendrier
        )

        #expect(instantane.estVide)
        #expect(instantane.maximumDesDerniersJours == 1)
        #expect(instantane.journeeDuJour.chapitresLus == 0)
    }
}
