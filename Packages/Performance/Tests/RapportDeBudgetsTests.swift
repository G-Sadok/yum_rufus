import Foundation
import Testing
@testable import BudgetsDePerformance

//
// RapportDeBudgetsTests
//
// Le rapport doit pouvoir virer au rouge, sinon il ne protege rien.
//
// Un test de performance qui ne peut pas echouer est un decor. Cette suite
// verifie donc l inverse de ce que la campagne cherche : qu une mesure au dessus
// de sa borne est bien signalee, qu une cadence sous son plancher l est aussi,
// et qu un budget qu on cesserait de mesurer ne passe pas pour tenu.
//

struct RapportDeBudgetsTests {
    @Test("Une campagne complete et sous les bornes est tenue")
    func campagneVerte() {
        let rapport = RapportDeBudgets(lignes: BudgetDePerformance.section12.map(ligne(tenue:)))

        #expect(rapport.completEtTenu)
        #expect(rapport.depassements.isEmpty)
        #expect(rapport.nonMesures.isEmpty)
    }

    @Test("Une duree au dessus de sa borne fait rougir le rapport")
    func dureeDepassee() throws {
        let budget = try #require(BudgetDePerformance.pour(.ouvertureDeChapitreLocal))
        var lignes = BudgetDePerformance.section12.map(ligne(tenue:))
        lignes[1] = LigneDeRapport(
            budget: budget,
            mesure: MesureDeBudget(cle: budget.cle, valeur: 351, detail: "mesure de controle")
        )

        let rapport = RapportDeBudgets(lignes: lignes)

        #expect(rapport.completEtTenu == false)
        #expect(rapport.depassements.map(\.budget.cle) == [.ouvertureDeChapitreLocal])
    }

    @Test("Une cadence sous son plancher fait rougir le rapport")
    func cadenceInsuffisante() throws {
        let budget = try #require(BudgetDePerformance.pour(.defilementDeLaGrille))
        var lignes = BudgetDePerformance.section12.map(ligne(tenue:))
        lignes[3] = LigneDeRapport(
            budget: budget,
            mesure: MesureDeBudget(cle: budget.cle, valeur: 119, detail: "mesure de controle")
        )

        let rapport = RapportDeBudgets(lignes: lignes)

        #expect(rapport.completEtTenu == false)
        #expect(rapport.depassements.map(\.budget.cle) == [.defilementDeLaGrille])
    }

    @Test("Un budget qui cesse d etre mesure ne passe pas pour tenu")
    func budgetDisparu() {
        let lignes = BudgetDePerformance.section12
            .filter { $0.cle != .memoireAuRepos }
            .map(ligne(tenue:))

        let rapport = RapportDeBudgets(lignes: lignes)

        #expect(rapport.depassements.isEmpty)
        #expect(rapport.nonMesures == [.memoireAuRepos])
        #expect(rapport.completEtTenu == false)
    }

    @Test("La ligne de rapport nomme la mesure, sa valeur et sa borne")
    func texteDeLaLigne() throws {
        let budget = try #require(BudgetDePerformance.pour(.memoireEnLecture))
        let ligne = LigneDeRapport(
            budget: budget,
            metrique: 512,
            detail: "mesure de controle"
        )

        #expect(ligne.texte.contains("DEPASSE"))
        #expect(ligne.texte.contains("512.0 Mo"))
        #expect(ligne.texte.contains("budget 400.0 Mo"))
    }

    /// Une ligne dont la mesure tient confortablement sa borne.
    private func ligne(tenue budget: BudgetDePerformance) -> LigneDeRapport {
        let valeur = switch budget.sens {
        case .auPlus: budget.borne / 2
        case .auMoins: budget.borne * 2
        }

        return LigneDeRapport(budget: budget, metrique: valeur, detail: "mesure de controle")
    }
}

extension LigneDeRapport {
    /// Raccourci de construction, la cle de la mesure suivant toujours celle du
    /// budget dans ces tests.
    fileprivate init(budget: BudgetDePerformance, metrique: Double, detail: String) {
        self.init(
            budget: budget,
            mesure: MesureDeBudget(cle: budget.cle, valeur: metrique, detail: detail)
        )
    }
}
