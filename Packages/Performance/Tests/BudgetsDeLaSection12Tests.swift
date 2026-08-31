import Foundation
import Testing
@testable import BudgetsDePerformance

//
// BudgetsDeLaSection12Tests
//
// Verrouille les sept valeurs du tableau de la section 12.
//
// Cette suite existe contre une seule tentation, nommee dans la competence
// tests-qualite : elargir un budget parce qu il ne passe plus. Les sept bornes
// sont recopiees ici a la main depuis le cahier de developpement, et toute
// modification de BudgetDePerformance.section12 fait rougir la suite avant que
// la campagne ne devienne complaisante.
//

struct BudgetsDeLaSection12Tests {
    @Test("Les sept mesures de la section 12 sont toutes declarees")
    func septBudgets() {
        #expect(BudgetDePerformance.section12.count == 7)
        #expect(Set(BudgetDePerformance.section12.map(\.cle)) == Set(CleDeBudget.allCases))
    }

    @Test(
        "Chaque budget porte la borne du cahier",
        arguments: [
            (CleDeBudget.lancementAFroid, 900.0, UniteDeBudget.millisecondes, SensDuBudget.auPlus),
            (CleDeBudget.ouvertureDeChapitreLocal, 350.0, UniteDeBudget.millisecondes, SensDuBudget.auPlus),
            (CleDeBudget.tourneDePage, 80.0, UniteDeBudget.millisecondes, SensDuBudget.auPlus),
            (CleDeBudget.defilementDeLaGrille, 120.0, UniteDeBudget.imagesParSeconde, SensDuBudget.auMoins),
            (CleDeBudget.defilementWebtoon, 120.0, UniteDeBudget.imagesParSeconde, SensDuBudget.auMoins),
            (CleDeBudget.memoireEnLecture, 400.0, UniteDeBudget.megaOctets, SensDuBudget.auPlus),
            (CleDeBudget.memoireAuRepos, 200.0, UniteDeBudget.megaOctets, SensDuBudget.auPlus),
        ]
    )
    func borneDuCahier(cle: CleDeBudget, borne: Double, unite: UniteDeBudget, sens: SensDuBudget) throws {
        let budget = try #require(BudgetDePerformance.pour(cle))

        #expect(budget.borne == borne)
        #expect(budget.unite == unite)
        #expect(budget.sens == sens)
    }

    @Test("Une duree sous la borne tient le budget, une duree au dessus le depasse")
    func sensAuPlus() throws {
        let budget = try #require(BudgetDePerformance.pour(.tourneDePage))

        #expect(budget.tenuPar(79.9))
        #expect(budget.tenuPar(80) == false)
        #expect(budget.tenuPar(80.1) == false)
    }

    @Test("Une cadence sous le plancher depasse le budget, une cadence egale le tient")
    func sensAuMoins() throws {
        let budget = try #require(BudgetDePerformance.pour(.defilementWebtoon))

        #expect(budget.tenuPar(119.9) == false)
        #expect(budget.tenuPar(120))
        #expect(budget.tenuPar(144))
    }

    @Test("La cadence soutenue se deduit de la pire image et non de la moyenne")
    func cadenceSoutenue() {
        #expect(Chronometre.cadenceSoutenue(pireImage: 8) == 125)
        #expect(Chronometre.cadenceSoutenue(pireImage: 10) == 100)
        #expect(Chronometre.cadenceSoutenue(pireImage: 0) == .infinity)
    }

    @Test("La meilleure de deux passes depend du sens du budget")
    func meilleurePasse() {
        #expect(Chronometre.plusFavorable(12, 30, sens: .auPlus) == 12)
        #expect(Chronometre.plusFavorable(12, 30, sens: .auMoins) == 30)
    }

    @Test("Le chronometre s arrete des qu une passe tient le budget")
    func arretALaPremierePasseTenue() throws {
        let budget = try #require(BudgetDePerformance.pour(.tourneDePage))
        var passes = 0

        let valeur = Chronometre(passes: 5).meilleure(sous: budget) {
            passes += 1

            return 10
        }

        #expect(passes == 1)
        #expect(valeur == 10)
    }

    @Test("Le chronometre epuise ses passes quand aucune ne tient, et garde la meilleure")
    func toutesLesPassesQuandLeBudgetDeborde() throws {
        let budget = try #require(BudgetDePerformance.pour(.tourneDePage))
        let durees = [400.0, 250.0, 900.0, 310.0, 260.0]
        var passes = 0

        let valeur = Chronometre(passes: 5).meilleure(sous: budget) {
            defer { passes += 1 }

            return durees[passes]
        }

        #expect(passes == 5)
        #expect(valeur == 250)
    }
}
