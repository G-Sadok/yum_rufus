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
    static func jusqua(
        delaiMax: Duration = .seconds(10),
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
