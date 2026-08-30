import Foundation

//
// Attente
//
// Attend qu une condition devienne vraie, sans jamais bloquer indefiniment.
//
// Les tests de precharge observent un travail de fond dont l instant de fin
// n est pas connu. Un sommeil fixe rendrait la suite lente et fragile, une
// attente sans borne la ferait pendre a la moindre regression. Ici le test
// recoit un verdict, vrai ou faux, qu il transforme en attente explicite.
//

enum Attente {
    /// Attend que la condition soit vraie, et dit si elle l a ete a temps.
    /// Le delai est une borne contre un test pendu, pas un budget de
    /// performance. Il etait de dix secondes, ce qui suffisait quand la suite
    /// etait plus petite : le processus de test fait tourner deux cent
    /// cinquante suites de front, dont plusieurs saturent le processeur pendant
    /// plusieurs secondes, et une cadence de vingt millisecondes peut alors
    /// n avoir aucune occasion de tomber pendant tout ce temps. Une soixantaine
    /// de secondes met la borne hors de portee de cette contention sans rien
    /// relacher : une cadence reellement cassee ne verifie jamais la condition,
    /// quel que soit le delai accorde, et une cadence saine sort des la
    /// premiere echeance.
    static func jusqua(
        delaiMax: Duration = .seconds(60),
        _ condition: @Sendable () async -> Bool
    ) async -> Bool {
        let echeance = ContinuousClock.now.advanced(by: delaiMax)

        while ContinuousClock.now < echeance {
            if await condition() {
                return true
            }

            try? await Task.sleep(for: .milliseconds(2))
        }

        return await condition()
    }
}
