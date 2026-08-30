import Foundation
import Testing
@testable import Core

//
// Le rappel facultatif de F059.
//
// Le rappel est une notification, donc une chose qui s affiche hors de
// l application, parfois sur un ecran verrouille. Les quatre cas ou il se tait
// sont donc testes un par un, y compris celui du mode incognito : une
// notification qui annonce le nombre de chapitres lus dans la journee est une
// trace de lecture, et la section 11 les interdit toutes pendant une session.
//

struct RappelDObjectifTests {
    private var calendrier: Calendar {
        var calendrier = Calendar(identifier: .gregorian)
        calendrier.timeZone = TimeZone(identifier: "Europe/Paris") ?? .gmt
        return calendrier
    }

    /// Instant de reference, pose a midi pour que l echeance de vingt heures
    /// tombe plus tard dans la meme journee.
    private var midi: Date {
        let debut = calendrier.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        return calendrier.date(bySettingHour: 12, minute: 0, second: 0, of: debut) ?? debut
    }

    private func prochain(
        rappel: RappelDObjectif = RappelDObjectif(actif: true),
        objectif: ObjectifQuotidien = ObjectifQuotidien(chapitresParJour: 3),
        lus: Int = 0,
        session: SessionIncognito = .inactive,
        le date: Date? = nil
    ) -> Date? {
        PlanificationDuRappel.prochainRappel(
            rappel: rappel,
            objectif: objectif,
            chapitresLusAujourdHui: lus,
            session: session,
            le: date ?? midi,
            calendrier: calendrier
        )
    }

    // MARK: Le rappel part

    @Test("Le rappel arme part a l heure du jour meme quand elle est devant")
    func rappelDuJour() throws {
        let echeance = try #require(prochain())
        let composantes = calendrier.dateComponents([.hour, .minute], from: echeance)

        #expect(composantes.hour == RappelDObjectif.heureParDefaut)
        #expect(composantes.minute == RappelDObjectif.minuteParDefaut)
        #expect(calendrier.isDate(echeance, inSameDayAs: midi))
    }

    @Test("Passe l heure, le rappel se reporte au lendemain")
    func rappelReporte() throws {
        let vingtDeuxHeures = try #require(
            calendrier.date(bySettingHour: 22, minute: 0, second: 0, of: midi)
        )

        let echeance = try #require(prochain(le: vingtDeuxHeures))
        let lendemain = try #require(calendrier.date(byAdding: .day, value: 1, to: midi))

        #expect(calendrier.isDate(echeance, inSameDayAs: lendemain))
    }

    @Test("L heure du rappel est celle du reglage, bornee a une heure reelle")
    func heureBornee() {
        #expect(RappelDObjectif(actif: true, heure: 30, minute: 90).heure == 23)
        #expect(RappelDObjectif(actif: true, heure: 30, minute: 90).minute == 59)
        #expect(RappelDObjectif(actif: true, heure: -4, minute: -2).heure == 0)
        #expect(RappelDObjectif(actif: true, heure: -4, minute: -2).minute == 0)
    }

    // MARK: Les quatre silences

    @Test("Un rappel eteint ne part pas")
    func rappelEteint() {
        #expect(prochain(rappel: .eteint) == nil)
        #expect(RappelDObjectif.eteint.actif == false)
    }

    @Test("Sans objectif, le rappel n a rien a rappeler")
    func sansObjectif() {
        #expect(prochain(objectif: .desactive) == nil)
    }

    @Test("Pendant une session incognito, aucun rappel ne part")
    func pendantUneSessionIncognito() {
        let session = SessionIncognito.demarree(le: midi)

        #expect(prochain(session: session) == nil)
        #expect(prochain(session: .inactive) != nil)
    }

    @Test("Une fois l objectif atteint, le rappel du jour se tait et passe au lendemain")
    func objectifAtteint() throws {
        let echeance = try #require(prochain(lus: 3))
        let lendemain = try #require(calendrier.date(byAdding: .day, value: 1, to: midi))

        #expect(calendrier.isDate(echeance, inSameDayAs: lendemain))
    }

    @Test("Un objectif partiellement fait laisse le rappel du jour en place")
    func objectifPartiel() throws {
        let echeance = try #require(prochain(lus: 2))

        #expect(calendrier.isDate(echeance, inSameDayAs: midi))
    }
}
