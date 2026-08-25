import Core
import Testing
@testable import ImagePipeline

/// Couvre le calcul du plafond, independamment d Image I/O. Ce calcul decide
/// seul de la memoire consommee par page, une erreur de racine ou d alignement
/// s y verrait multipliee par le nombre de pages en cache.
struct BudgetDeDecodageTests {
    private let pageDeReference = TailleEnPixels(largeur: 3000, hauteur: 4500)

    @Test("Le cote retenu tient sous le plafond, alignement compris")
    func coteSousLePlafond() {
        let budget = BudgetDeDecodage.parDefaut
        let cote = budget.coteMaximal(pour: pageDeReference, sansDepasser: 10000)

        #expect(BudgetDeDecodage.octetsOccupes(cote: cote, page: pageDeReference) < budget.octetsParPage)
    }

    @Test("Un pixel de plus depasserait le plafond")
    func coteMaximalEtNonPrudent() {
        let budget = BudgetDeDecodage.parDefaut
        let cote = budget.coteMaximal(pour: pageDeReference, sansDepasser: 10000)

        // Sans cette verification, un budget qui renverrait systematiquement un
        // cote minuscule passerait le test precedent tout en ruinant l image.
        #expect(BudgetDeDecodage.octetsOccupes(cote: cote + 1, page: pageDeReference) >= budget.octetsParPage)
    }

    @Test("Le budget ne remonte jamais au dessus du cote demande")
    func jamaisAuDessusDeLaZone() {
        let budget = BudgetDeDecodage.parDefaut

        #expect(budget.coteMaximal(pour: pageDeReference, sansDepasser: 600) == 600)
        #expect(budget.coteMaximal(pour: pageDeReference, sansDepasser: 1) == 1)
    }

    @Test("Un cote nul ou negatif est ramene a un pixel")
    func coteDegenere() {
        let budget = BudgetDeDecodage.parDefaut

        #expect(budget.coteMaximal(pour: pageDeReference, sansDepasser: 0) == 1)
        #expect(budget.coteMaximal(pour: pageDeReference, sansDepasser: -40) == 1)
    }

    @Test("Une page sans dimensions laisse passer le cote demande")
    func pageVide() {
        let budget = BudgetDeDecodage.parDefaut

        #expect(budget.coteMaximal(pour: .nulle, sansDepasser: 1200) == 1200)
    }

    @Test("Un plafond plus petit qu une vignette est releve")
    func plancherDuPlafond() {
        #expect(BudgetDeDecodage(octetsParPage: 10).octetsParPage == 64 * 64 * 4)
    }

    @Test("Un plafond plus serre donne un cote plus petit")
    func plafondPlusServreDonneCotePlusPetit() {
        let large = BudgetDeDecodage.parDefaut.coteMaximal(pour: pageDeReference, sansDepasser: 10000)
        let serre = BudgetDeDecodage(octetsParPage: 3_000_000)
            .coteMaximal(pour: pageDeReference, sansDepasser: 10000)

        #expect(serre < large)
    }

    @Test("La reduction conserve le ratio et le plus grand cote")
    func reductionCoherente() {
        let reduite = BudgetDeDecodage.reduction(de: pageDeReference, vers: 1500)

        #expect(reduite.hauteur == 1500)
        #expect(reduite.largeur == 1000)
    }

    @Test("Une page couchee est bornee par sa largeur")
    func pageCouchee() {
        let couchee = TailleEnPixels(largeur: 4500, hauteur: 3000)
        let budget = BudgetDeDecodage.parDefaut
        let cote = budget.coteMaximal(pour: couchee, sansDepasser: 10000)
        let reduite = BudgetDeDecodage.reduction(de: couchee, vers: cote)

        #expect(reduite.largeur == cote)
        #expect(BudgetDeDecodage.octetsOccupes(cote: cote, page: couchee) < budget.octetsParPage)
    }
}
