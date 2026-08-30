import Foundation
import Testing
@testable import Core

//
// Couvre le deuxieme critere de la fonctionnalite : un conflit est resolu de
// facon deterministe et documentee.
//
// Deterministe veut dire trois choses precises, et chacune a son test. La
// reponse ne depend pas de l ordre dans lequel les deux versions se presentent.
// Elle ne depend pas de l ordre dans lequel un lot arrive. Et elle existe
// toujours, y compris quand les horodatages sont egaux, cas ou une regle
// ecrite a la va vite laisse deux appareils diverger pour toujours.
//
// Le test ne verifie pas seulement quel changement gagne mais aussi par quelle
// ligne de la regle. Sans cela, une regle qui rendrait le bon gagnant pour la
// mauvaise raison passerait, et le premier horodatage egal la ferait tomber.
//

@Suite("Resolution de conflit par horodatage")
struct ResolutionDeConflitTests {
    static let base = Date(timeIntervalSince1970: 1_700_000_000)

    static func changement(
        page: Int,
        appareil: String,
        secondes: TimeInterval,
        chapitre: UUID
    ) throws -> ChangementSynchronise {
        let progression = ProgressionSynchronisee(
            chapitreId: chapitre,
            pageAtteinte: page,
            dateLecture: base.addingTimeInterval(secondes)
        )

        return try progression.changement(depuis: appareil)
    }

    @Test("L horodatage le plus recent gagne")
    func plusRecentGagne() throws {
        let chapitre = UUID()
        let ancien = try Self.changement(page: 3, appareil: "A", secondes: 0, chapitre: chapitre)
        let recent = try Self.changement(page: 9, appareil: "B", secondes: 10, chapitre: chapitre)

        let issue = ResolutionDeConflit.gagnant(ancien, recent)

        #expect(issue.changement == recent)
        #expect(issue.arbitrage == .parHorodatage)
    }

    @Test("La regle donne la meme reponse dans les deux sens")
    func commutative() throws {
        let chapitre = UUID()
        let premier = try Self.changement(page: 3, appareil: "A", secondes: 0, chapitre: chapitre)
        let second = try Self.changement(page: 9, appareil: "B", secondes: 10, chapitre: chapitre)

        let unSens = ResolutionDeConflit.gagnant(premier, second)
        let autreSens = ResolutionDeConflit.gagnant(second, premier)

        #expect(unSens == autreSens)
    }

    @Test("A horodatage egal, l appareil departage, et toujours de la meme facon")
    func departageParAppareil() throws {
        let chapitre = UUID()
        let appareilA = try Self.changement(page: 3, appareil: "appareil-a", secondes: 42, chapitre: chapitre)
        let appareilB = try Self.changement(page: 9, appareil: "appareil-b", secondes: 42, chapitre: chapitre)

        let issue = ResolutionDeConflit.gagnant(appareilA, appareilB)

        #expect(issue.changement == appareilB)
        #expect(issue.arbitrage == .parAppareil)
        #expect(ResolutionDeConflit.gagnant(appareilB, appareilA) == issue)
    }

    @Test("A horodatage et appareil egaux, la charge departe encore")
    func departageParCharge() throws {
        let chapitre = UUID()
        let premier = try Self.changement(page: 3, appareil: "appareil-a", secondes: 42, chapitre: chapitre)
        let second = try Self.changement(page: 9, appareil: "appareil-a", secondes: 42, chapitre: chapitre)

        let issue = ResolutionDeConflit.gagnant(premier, second)

        #expect(issue.arbitrage == .parCharge)
        #expect(ResolutionDeConflit.gagnant(second, premier) == issue)
    }

    @Test("Deux versions identiques ne creent pas de conflit")
    func versionsIdentiques() throws {
        let chapitre = UUID()
        let changement = try Self.changement(page: 3, appareil: "A", secondes: 0, chapitre: chapitre)

        let issue = ResolutionDeConflit.gagnant(changement, changement)

        #expect(issue.changement == changement)
        #expect(issue.arbitrage == .versionsIdentiques)
    }

    @Test("Le meme lot melange donne le meme resultat")
    func fusionIndependanteDeLOrdre() throws {
        let premierChapitre = UUID()
        let secondChapitre = UUID()

        let lot = try [
            Self.changement(page: 1, appareil: "A", secondes: 0, chapitre: premierChapitre),
            Self.changement(page: 7, appareil: "B", secondes: 30, chapitre: premierChapitre),
            Self.changement(page: 2, appareil: "B", secondes: 10, chapitre: secondChapitre),
            Self.changement(page: 5, appareil: "A", secondes: 20, chapitre: secondChapitre),
        ]

        let ordreNaturel = ResolutionDeConflit.fusion(Array(lot[0...1]), Array(lot[2...3]))
        let ordreInverse = ResolutionDeConflit.fusion(Array(lot[2...3].reversed()), Array(lot[0...1].reversed()))

        #expect(ordreNaturel == ordreInverse)
        #expect(ordreNaturel.count == 2)
    }

    @Test("La progression relue est celle qui a gagne")
    func gagnantRelisible() throws {
        let chapitre = UUID()
        let ancien = try Self.changement(page: 3, appareil: "A", secondes: 0, chapitre: chapitre)
        let recent = try Self.changement(page: 9, appareil: "B", secondes: 10, chapitre: chapitre)

        let issue = ResolutionDeConflit.gagnant(ancien, recent)
        let progression = try ProgressionSynchronisee.lire(issue.changement)

        #expect(progression.pageAtteinte == 9)
        #expect(progression.chapitreId == chapitre)
    }

    @Test("Une charge illisible est refusee au lieu d etre appliquee a moitie")
    func chargeIllisible() throws {
        let cle = CleDeChangement(entite: .progressionDeChapitre, identifiant: UUID())
        let changement = ChangementSynchronise(
            cle: cle,
            charge: Data("ceci n est pas du JSON".utf8),
            horodatage: Self.base,
            appareil: "A"
        )

        #expect(throws: ErreurDeSynchronisation.chargeIllisible(cle: cle)) {
            try ProgressionSynchronisee.lire(changement)
        }
    }
}
