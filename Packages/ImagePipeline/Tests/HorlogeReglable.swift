import Foundation
@testable import ImagePipeline

//
// HorlogeReglable
//
// Horloge que le test avance a la main.
//
// La purge du cache disque trie par date d acces. S appuyer sur l horloge de la
// machine rendrait ce tri dependant de sa resolution : deux depots successifs
// peuvent porter la meme date, et le test verifierait alors un ordre que rien
// ne garantit. Ici chaque avance est explicite, l ordre attendu est donc l ordre
// reellement produit.
//

final class HorlogeReglable: @unchecked Sendable {
    // Verrou plutot qu acteur : l horloge est lue depuis l interieur de
    // l acteur du cache, par une fermeture synchrone qui ne peut pas attendre.
    private let verrou = NSLock()
    private var instant: Date

    init(depart: Date = Date(timeIntervalSinceReferenceDate: 0)) {
        instant = depart
    }

    /// Horloge a passer au cache disque.
    var horloge: HorlogeDAcces {
        HorlogeDAcces { self.maintenant() }
    }

    /// Avance l horloge, par defaut d une seconde.
    func avancer(de secondes: TimeInterval = 1) {
        verrou.lock()
        instant = instant.addingTimeInterval(secondes)
        verrou.unlock()
    }

    private func maintenant() -> Date {
        verrou.lock()
        defer { verrou.unlock() }

        return instant
    }
}
