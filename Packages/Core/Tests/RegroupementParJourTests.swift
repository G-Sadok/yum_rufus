import Core
import Foundation
import Testing

/// Un jour du calendrier, sans heure.
///
/// Le type existe pour que les helpers de test prennent un jour et une heure
/// plutot que six entiers de suite, ou une inversion du mois et du jour ne se
/// verrait pas a la lecture.
struct JourCivil {
    let annee: Int
    let mois: Int
    let jour: Int

    static func le(_ annee: Int, _ mois: Int, _ jour: Int) -> JourCivil {
        JourCivil(annee: annee, mois: mois, jour: jour)
    }
}

extension Calendar {
    /// Calendrier gregorien dans le fuseau demande.
    static func gregorien(_ fuseau: String) throws -> Calendar {
        var calendrier = Calendar(identifier: .gregorian)
        calendrier.timeZone = try #require(TimeZone(identifier: fuseau))

        return calendrier
    }

    /// Instant local, dans le fuseau de ce calendrier.
    func instant(_ date: JourCivil, heure: Int = 0, minute: Int = 0) throws -> Date {
        let composantes = DateComponents(
            calendar: self,
            timeZone: timeZone,
            year: date.annee,
            month: date.mois,
            day: date.jour,
            hour: heure,
            minute: minute
        )

        return try #require(composantes.date)
    }
}

/// Regroupement de l historique par jour, section 5.2 de DESIGN-SPEC.md.
///
/// Chaque test pose son propre calendrier et son propre fuseau. Une suite qui
/// se fierait au fuseau de la machine passerait a Paris et echouerait a
/// Auckland, ce qui est exactement le defaut que ces tests cherchent.
struct RegroupementParJourTests {
    /// Entree minimale, seule la date compte pour le regroupement.
    static func entree(_ date: Date, serie: String = "Serie") -> EntreeDHistorique {
        EntreeDHistorique(
            chapitreId: UUID(),
            serieId: UUID(),
            titreDeLaSerie: serie,
            numeroDeChapitre: 1,
            dateLecture: date
        )
    }

    @Test("Deux lectures du meme jour tiennent dans un seul groupe")
    func unSeulGroupeParJour() throws {
        let calendrier = try Calendar.gregorien("Europe/Paris")
        let matin = try calendrier.instant(.le(2026, 8, 25), heure: 0, minute: 30)
        let soir = try calendrier.instant(.le(2026, 8, 25), heure: 23, minute: 30)

        let journees = RegroupementParJour.grouper(
            [Self.entree(matin), Self.entree(soir)],
            calendrier: calendrier
        )

        #expect(journees.count == 1)
        #expect(journees[0].entrees.count == 2)
        #expect(try journees[0].debutDuJour == (calendrier.instant(.le(2026, 8, 25))))
    }

    @Test("Minuit separe deux jours, a une seconde d ecart")
    func minuitSepareDeuxJours() throws {
        let calendrier = try Calendar.gregorien("Europe/Paris")
        let avant = try calendrier.instant(.le(2026, 8, 25), heure: 23, minute: 59)
            .addingTimeInterval(59)
        let apres = try calendrier.instant(.le(2026, 8, 26)).addingTimeInterval(1)

        let journees = RegroupementParJour.grouper(
            [Self.entree(avant), Self.entree(apres)],
            calendrier: calendrier
        )

        #expect(journees.count == 2, "Une seconde apres minuit ouvre un nouveau jour")
        #expect(try journees[0].debutDuJour == (calendrier.instant(.le(2026, 8, 26))))
        #expect(try journees[1].debutDuJour == (calendrier.instant(.le(2026, 8, 25))))
    }

    @Test("Le jour est celui du fuseau de l utilisateur, pas celui du temps universel")
    func leJourSuitLeFuseau() throws {
        let auckland = try Calendar.gregorien("Pacific/Auckland")
        let utc = try Calendar.gregorien("UTC")

        // Deux lectures du meme jour a Auckland, 01 h 00 et 22 h 00. En temps
        // universel elles tombent la veille et le jour meme : le regroupement
        // brut en ferait deux journees.
        let tot = try auckland.instant(.le(2026, 8, 25), heure: 1)
        let tard = try auckland.instant(.le(2026, 8, 25), heure: 22)
        let entrees = [Self.entree(tot), Self.entree(tard)]

        #expect(RegroupementParJour.grouper(entrees, calendrier: auckland).count == 1)
        #expect(RegroupementParJour.grouper(entrees, calendrier: utc).count == 2)
    }

    @Test("Un changement d heure ne coupe pas la journee en deux")
    func leChangementDHeureNeCoupePasLaJournee() throws {
        let calendrier = try Calendar.gregorien("Europe/Paris")

        // Nuit du 25 octobre 2026, ou 03 h 00 revient a 02 h 00. La journee
        // dure vingt cinq heures et reste une seule journee.
        let avantLeRecul = try calendrier.instant(.le(2026, 10, 25), heure: 1, minute: 30)
        let apresLeRecul = try calendrier.instant(.le(2026, 10, 25), heure: 23, minute: 30)

        let journees = RegroupementParJour.grouper(
            [Self.entree(avantLeRecul), Self.entree(apresLeRecul)],
            calendrier: calendrier
        )

        #expect(journees.count == 1)
        #expect(journees[0].entrees.count == 2)
    }

    @Test("Les journees et leurs entrees sortent de la plus recente a la plus ancienne")
    func lOrdreEstAntichronologique() throws {
        let calendrier = try Calendar.gregorien("Europe/Paris")
        let hier = try calendrier.instant(.le(2026, 8, 24), heure: 12)
        let ceMatin = try calendrier.instant(.le(2026, 8, 25), heure: 9)
        let ceSoir = try calendrier.instant(.le(2026, 8, 25), heure: 21)

        let journees = RegroupementParJour.grouper(
            [
                Self.entree(ceMatin, serie: "Matin"),
                Self.entree(hier, serie: "Hier"),
                Self.entree(ceSoir, serie: "Soir"),
            ],
            calendrier: calendrier
        )

        #expect(journees.map(\.entrees.count) == [2, 1])
        #expect(journees[0].entrees.map(\.titreDeLaSerie) == ["Soir", "Matin"])
        #expect(journees[1].entrees.map(\.titreDeLaSerie) == ["Hier"])
    }

    @Test("Un historique vide ne produit aucune journee")
    func unHistoriqueVideNeProduitRien() throws {
        let calendrier = try Calendar.gregorien("UTC")

        #expect(RegroupementParJour.grouper([], calendrier: calendrier).isEmpty)
    }
}
