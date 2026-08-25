import Core
import Foundation
import GRDB
import Testing
@testable import Storage

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

/// Historique de lecture, section 5.2 de DESIGN-SPEC.md.
struct HistoriquePersisteTests {
    @Test("Une lecture laisse une entree qui porte la serie et le chapitre")
    func uneLectureLaisseUneEntree() throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(
            dans: base,
            nombreDeChapitres: 2,
            pagesParChapitre: 30,
            titre: "Serie lue"
        )
        let calendrier = try Calendar.gregorien("Europe/Paris")
        let date = try calendrier.instant(.le(2026, 8, 25), heure: 21, minute: 4)

        try MagasinDeProgression(base: base).enregistrer(
            PositionDeLecture(chapitreId: jeu.chapitres[1].id, pageIndex: 12),
            le: date,
            calendrier: calendrier
        )

        let entrees = try MagasinDHistorique(base: base).entrees()

        #expect(entrees.count == 1)
        #expect(entrees[0].chapitreId == jeu.chapitres[1].id)
        #expect(entrees[0].serieId == jeu.manga.id)
        #expect(entrees[0].titreDeLaSerie == "Serie lue")
        #expect(entrees[0].numeroDeChapitre == 2)
        #expect(entrees[0].dateLecture == date)
    }

    @Test("Les sauvegardes repetees d un meme chapitre tiennent dans une entree par jour")
    func uneSeuleEntreeParChapitreEtParJour() throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(
            dans: base,
            nombreDeChapitres: 1,
            pagesParChapitre: 40
        )
        let calendrier = try Calendar.gregorien("Europe/Paris")
        let debut = try calendrier.instant(.le(2026, 8, 25), heure: 20)
        let magasin = MagasinDeProgression(base: base)
        let chapitre = jeu.chapitres[0].id

        // Ce que fait le moteur pendant une lecture : une sauvegarde toutes les
        // deux secondes.
        for page in 0..<12 {
            try magasin.enregistrer(
                PositionDeLecture(chapitreId: chapitre, pageIndex: page),
                le: debut.addingTimeInterval(Double(page) * 2),
                calendrier: calendrier
            )
        }

        let entrees = try MagasinDHistorique(base: base).entrees()

        #expect(entrees.count == 1, "Une lecture continue ne remplit pas l ecran de doublons")
        #expect(entrees[0].dateLecture == debut.addingTimeInterval(22))
    }

    @Test("Le meme chapitre relu le lendemain ouvre une seconde entree")
    func leLendemainOuvreUneSecondeEntree() throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(
            dans: base,
            nombreDeChapitres: 1,
            pagesParChapitre: 40
        )
        let calendrier = try Calendar.gregorien("Europe/Paris")
        let magasin = MagasinDeProgression(base: base)
        let chapitre = jeu.chapitres[0].id

        try magasin.enregistrer(
            PositionDeLecture(chapitreId: chapitre, pageIndex: 3),
            le: calendrier.instant(.le(2026, 8, 25), heure: 23, minute: 50),
            calendrier: calendrier
        )
        try magasin.enregistrer(
            PositionDeLecture(chapitreId: chapitre, pageIndex: 4),
            le: calendrier.instant(.le(2026, 8, 26), heure: 0, minute: 10),
            calendrier: calendrier
        )

        let journees = try MagasinDHistorique(base: base).journees(calendrier: calendrier)

        #expect(journees.count == 2, "Minuit ouvre un nouveau jour, donc une nouvelle entree")
        #expect(journees.allSatisfy { $0.entrees.count == 1 })
    }

    @Test("La suppression unitaire ne retire que l entree visee")
    func laSuppressionUnitaireNeRetireQueLEntreeVisee() throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(
            dans: base,
            nombreDeChapitres: 3,
            pagesParChapitre: 20
        )
        let calendrier = try Calendar.gregorien("Europe/Paris")
        let progression = MagasinDeProgression(base: base)
        let historique = MagasinDHistorique(base: base)

        for (rang, chapitre) in jeu.chapitres.enumerated() {
            try progression.enregistrer(
                PositionDeLecture(chapitreId: chapitre.id, pageIndex: 2),
                le: calendrier.instant(.le(2026, 8, 25), heure: 10 + rang),
                calendrier: calendrier
            )
        }

        let avant = try historique.entrees()
        try historique.supprimer(avant[0].id)

        let apres = try historique.entrees()

        #expect(apres.count == 2)
        #expect(apres.contains { $0.id == avant[0].id } == false)

        // Effacer une trace n annule pas une lecture.
        let page = try base.ecrivain.read { connexion in
            try Int.fetchOne(
                connexion,
                sql: "SELECT pageAtteinte FROM chapitre WHERE id = ?",
                arguments: [avant[0].chapitreId]
            )
        }

        #expect(page == 2)
    }

    @Test("L effacement global vide l historique et ne touche a rien d autre")
    func lEffacementGlobalNeToucheQueLHistorique() throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(
            dans: base,
            nombreDeChapitres: 2,
            pagesParChapitre: 20
        )
        let historique = MagasinDHistorique(base: base)

        for chapitre in jeu.chapitres {
            try MagasinDeProgression(base: base).enregistrer(
                PositionDeLecture(chapitreId: chapitre.id, pageIndex: 5)
            )
        }

        #expect(try historique.entrees().count == 2)

        try historique.effacer()

        #expect(try historique.entrees().isEmpty)
        #expect(try historique.journees().isEmpty)

        let chapitresRestants = try base.ecrivain.read { connexion in
            try Int.fetchOne(connexion, sql: "SELECT COUNT(*) FROM chapitre")
        }

        #expect(chapitresRestants == 2, "La bibliotheque n est pas touchee")
    }

    @Test("La suppression d un chapitre emporte ses entrees d historique")
    func laSuppressionDUnChapitreEmporteSesEntrees() throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(
            dans: base,
            nombreDeChapitres: 1,
            pagesParChapitre: 20
        )

        try MagasinDeProgression(base: base).enregistrer(
            PositionDeLecture(chapitreId: jeu.chapitres[0].id, pageIndex: 4)
        )

        _ = try base.ecrivain.write { connexion in
            try Chapitre.deleteOne(connexion, key: jeu.chapitres[0].id)
        }

        #expect(try MagasinDHistorique(base: base).entrees().isEmpty)
    }

    @Test("Les journees remontent groupees et antichronologiques")
    func lesJourneesRemontentGroupees() throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(
            dans: base,
            nombreDeChapitres: 3,
            pagesParChapitre: 20
        )
        let calendrier = try Calendar.gregorien("Europe/Paris")
        let progression = MagasinDeProgression(base: base)

        try progression.enregistrer(
            PositionDeLecture(chapitreId: jeu.chapitres[0].id, pageIndex: 1),
            le: calendrier.instant(.le(2026, 8, 24), heure: 9),
            calendrier: calendrier
        )
        try progression.enregistrer(
            PositionDeLecture(chapitreId: jeu.chapitres[1].id, pageIndex: 1),
            le: calendrier.instant(.le(2026, 8, 25), heure: 9),
            calendrier: calendrier
        )
        try progression.enregistrer(
            PositionDeLecture(chapitreId: jeu.chapitres[2].id, pageIndex: 1),
            le: calendrier.instant(.le(2026, 8, 25), heure: 22),
            calendrier: calendrier
        )

        let journees = try MagasinDHistorique(base: base).journees(calendrier: calendrier)

        #expect(journees.map(\.entrees.count) == [2, 1])
        #expect(try journees[0].debutDuJour == (calendrier.instant(.le(2026, 8, 25))))
        #expect(try journees[1].debutDuJour == (calendrier.instant(.le(2026, 8, 24))))
    }
}
