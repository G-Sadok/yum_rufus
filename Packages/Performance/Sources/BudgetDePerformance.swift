import Foundation

//
// BudgetDePerformance
//
// Les sept budgets de la section 12 du cahier de developpement, ecrits une
// seule fois.
//
// Ils sont ici et nulle part ailleurs. Une valeur recopiee dans un test finit
// par diverger de celle du cahier, et le jour ou elle diverge personne ne le
// voit : la suite reste verte parce qu elle se compare a sa propre copie. La
// suite `BudgetsDeLaSection12Tests` verrouille les sept valeurs contre le texte
// du cahier, et elle echoue si l une d elles est elargie.
//

/// Sens dans lequel une mesure doit se comparer a son budget.
public enum SensDuBudget: String, Sendable, Hashable, Codable {
    /// La mesure doit rester sous le budget. Les durees et les empreintes.
    case auPlus

    /// La mesure doit rester au dessus du budget. Les cadences d images.
    case auMoins
}

/// Unite dans laquelle une mesure et son budget s expriment.
public enum UniteDeBudget: String, Sendable, Hashable, Codable {
    case millisecondes
    case imagesParSeconde
    case megaOctets

    /// Suffixe affiche dans le rapport.
    public var suffixe: String {
        switch self {
        case .millisecondes: "ms"
        case .imagesParSeconde: "i/s"
        case .megaOctets: "Mo"
        }
    }
}

/// Les sept mesures de la section 12, designees par une cle stable.
///
/// La cle sert d argument de ligne de commande et de champ du rapport. Elle ne
/// change pas sans changer le rapport de toutes les executions passees, ce qui
/// est voulu : une cle stable rend deux campagnes comparables.
public enum CleDeBudget: String, Sendable, CaseIterable, Codable {
    case lancementAFroid
    case ouvertureDeChapitreLocal
    case tourneDePage
    case defilementDeLaGrille
    case defilementWebtoon
    case memoireEnLecture
    case memoireAuRepos
}

/// Un budget de la section 12 : ce qui est mesure, et la borne a tenir.
public struct BudgetDePerformance: Sendable, Hashable, Codable {
    /// Cle stable de la mesure.
    public let cle: CleDeBudget

    /// Libelle repris du tableau de la section 12.
    public let libelle: String

    /// Borne a tenir, dans l unite du budget.
    public let borne: Double

    public let unite: UniteDeBudget
    public let sens: SensDuBudget

    public init(cle: CleDeBudget, libelle: String, borne: Double, unite: UniteDeBudget, sens: SensDuBudget) {
        self.cle = cle
        self.libelle = libelle
        self.borne = borne
        self.unite = unite
        self.sens = sens
    }

    /// Vrai quand la valeur mesuree tient le budget.
    public func tenuPar(_ mesure: Double) -> Bool {
        switch sens {
        case .auPlus: mesure < borne
        case .auMoins: mesure >= borne
        }
    }
}

extension BudgetDePerformance {
    /// Les sept budgets du tableau de la section 12, dans l ordre du cahier.
    public static let section12: [BudgetDePerformance] = [
        BudgetDePerformance(
            cle: .lancementAFroid,
            libelle: "Lancement a froid jusqu a la bibliotheque affichee",
            borne: 900,
            unite: .millisecondes,
            sens: .auPlus
        ),
        BudgetDePerformance(
            cle: .ouvertureDeChapitreLocal,
            libelle: "Ouverture d un chapitre local jusqu a la premiere page",
            borne: 350,
            unite: .millisecondes,
            sens: .auPlus
        ),
        BudgetDePerformance(
            cle: .tourneDePage,
            libelle: "Tourne de page en local",
            borne: 80,
            unite: .millisecondes,
            sens: .auPlus
        ),
        BudgetDePerformance(
            cle: .defilementDeLaGrille,
            libelle: "Defilement de la grille de bibliotheque",
            borne: 120,
            unite: .imagesParSeconde,
            sens: .auMoins
        ),
        BudgetDePerformance(
            cle: .defilementWebtoon,
            libelle: "Defilement webtoon",
            borne: 120,
            unite: .imagesParSeconde,
            sens: .auMoins
        ),
        BudgetDePerformance(
            cle: .memoireEnLecture,
            libelle: "Memoire en lecture",
            borne: 400,
            unite: .megaOctets,
            sens: .auPlus
        ),
        BudgetDePerformance(
            cle: .memoireAuRepos,
            libelle: "Memoire au repos, bibliotheque de 5000 series",
            borne: 200,
            unite: .megaOctets,
            sens: .auPlus
        ),
    ]

    /// Le budget associe a une cle.
    public static func pour(_ cle: CleDeBudget) -> BudgetDePerformance? {
        section12.first { $0.cle == cle }
    }
}
