import Foundation

//
// Chronometre
//
// Comment une duree se mesure ici, et pourquoi une passe ne suffit pas.
//
// La machine d integration continue est partagee. Une preemption de
// l ordonnanceur au mauvais moment suffit a faire deborder une mesure sans que
// rien du code ait bouge, et un budget qui rougit une fois sur dix pour cette
// raison la finit par etre elargi ou ignore, ce qui est pire que pas de budget
// du tout.
//
// La reponse retenue est celle deja employee par WebtoonAuBudgetTests : on
// repete la passe et on garde la meilleure. Ce qui est accorde n est pas une
// mesure plus lente, c est une seconde chance quand la machine a vole du temps
// a la premiere. Le budget, lui, ne bouge pas, et un code reellement trop lent
// deborde a toutes les passes.
//

/// Repetition d une mesure de duree, jusqu a la meilleure passe.
public struct Chronometre: Sendable {
    /// Nombre de passes accordees avant de rendre le meilleur resultat.
    public let passes: Int

    public init(passes: Int = 5) {
        self.passes = max(1, passes)
    }

    /// Deroule une passe autant de fois qu il faut et rend la meilleure.
    ///
    /// La meilleure passe est celle dont la mesure est la plus basse : c est la
    /// moins perturbee par le reste de la machine, donc celle qui dit le plus
    /// honnetement ce que le code coute. La repetition s arrete des qu une passe
    /// tient le budget, pour ne pas payer cinq passes quand une suffit.
    ///
    /// - Parameters:
    ///   - budget: budget contre lequel la passe est jugee.
    ///   - passe: la mesure a repeter, rendue dans l unite du budget.
    public func meilleure(
        sous budget: BudgetDePerformance,
        passe: () throws -> Double
    ) rethrows -> Double {
        var meilleure = try passe()

        for _ in 1..<passes where budget.tenuPar(meilleure) == false {
            let autre = try passe()

            meilleure = Self.plusFavorable(meilleure, autre, sens: budget.sens)
        }

        return meilleure
    }

    /// La plus favorable de deux mesures, selon le sens du budget.
    static func plusFavorable(_ premiere: Double, _ seconde: Double, sens: SensDuBudget) -> Double {
        switch sens {
        case .auPlus: min(premiere, seconde)
        case .auMoins: max(premiere, seconde)
        }
    }

    /// Duree d un bloc, en millisecondes.
    public static func millisecondes(_ bloc: () throws -> Void) rethrows -> Double {
        let debut = ContinuousClock.now
        try bloc()

        return duree(depuis: debut)
    }

    /// Millisecondes ecoulees depuis un instant.
    public static func duree(depuis debut: ContinuousClock.Instant) -> Double {
        let ecart = ContinuousClock.now - debut
        let composantes = ecart.components

        return Double(composantes.seconds) * 1000
            + Double(composantes.attoseconds) / 1_000_000_000_000_000
    }

    /// Cadence soutenue deduite de l image la plus lente d un defilement.
    ///
    /// C est bien la pire image et non la moyenne. Une moyenne de cent vingt
    /// images par seconde avec une image a quarante millisecondes donne un a
    /// coup parfaitement visible, et le budget de la section 12 parle d une
    /// cadence soutenue.
    public static func cadenceSoutenue(pireImage: Double) -> Double {
        guard pireImage > 0 else {
            return .infinity
        }

        return 1000 / pireImage
    }
}
