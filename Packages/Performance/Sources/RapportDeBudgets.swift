import Foundation

//
// RapportDeBudgets
//
// Ce qu une campagne rend, et le verdict qui en decoule.
//

/// Une mesure, telle qu un processus de mesure la rend.
public struct MesureDeBudget: Sendable, Hashable, Codable {
    public let cle: CleDeBudget

    /// Valeur mesuree, dans l unite du budget.
    public let valeur: Double

    /// Ce qui a ete mesure, en une phrase, pour que le rapport se lise sans le
    /// code sous les yeux.
    public let detail: String

    public init(cle: CleDeBudget, valeur: Double, detail: String) {
        self.cle = cle
        self.valeur = valeur
        self.detail = detail
    }
}

/// Une mesure confrontee a son budget.
public struct LigneDeRapport: Sendable, Hashable, Codable {
    public let budget: BudgetDePerformance
    public let mesure: MesureDeBudget

    public init(budget: BudgetDePerformance, mesure: MesureDeBudget) {
        self.budget = budget
        self.mesure = mesure
    }

    /// Vrai quand la mesure tient le budget.
    public var tenu: Bool {
        budget.tenuPar(mesure.valeur)
    }

    /// Ligne lisible par un humain, telle qu elle sort dans la sortie standard.
    public var texte: String {
        let etat = tenu ? "OK     " : "DEPASSE"
        let borne = budget.sens == .auPlus ? "budget \(nombre(budget.borne))" : "plancher \(nombre(budget.borne))"

        return "\(etat)  \(budget.libelle) : "
            + "\(nombre(mesure.valeur)) \(budget.unite.suffixe), \(borne) \(budget.unite.suffixe)"
    }

    private func nombre(_ valeur: Double) -> String {
        String(format: "%.1f", valeur)
    }
}

/// Le resultat complet d une campagne.
public struct RapportDeBudgets: Sendable, Hashable, Codable {
    public let lignes: [LigneDeRapport]

    public init(lignes: [LigneDeRapport]) {
        self.lignes = lignes
    }

    /// Budgets depasses, dans l ordre du cahier.
    public var depassements: [LigneDeRapport] {
        lignes.filter { $0.tenu == false }
    }

    /// Vrai quand les sept budgets sont mesures et tenus.
    ///
    /// Une campagne incomplete n est pas une campagne reussie. Sans cette
    /// condition, un budget qu on cesserait de mesurer disparaitrait du rapport
    /// sans jamais faire rougir personne.
    public var completEtTenu: Bool {
        let mesures = Set(lignes.map(\.budget.cle))

        return mesures == Set(CleDeBudget.allCases) && depassements.isEmpty
    }

    /// Budgets de la section 12 qu aucune ligne ne couvre.
    public var nonMesures: [CleDeBudget] {
        let mesures = Set(lignes.map(\.budget.cle))

        return CleDeBudget.allCases.filter { mesures.contains($0) == false }
    }
}
