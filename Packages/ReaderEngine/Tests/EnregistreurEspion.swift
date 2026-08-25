import Core
import Foundation

//
// EnregistreurEspion
//
// Enregistreur de position qui garde tout ce qu on lui donne, et qui sait
// echouer sur commande.
//
// Il remplace la base dans les tests du moteur. Le protocole vient de Core,
// donc ReaderEngine se teste sans dependre de Storage ni de GRDB.
//

/// Erreur d ecriture simulee.
struct EcritureRefusee: Error, Equatable {}

/// Espion qui consigne les positions au lieu de les ecrire.
actor EnregistreurEspion: EnregistreurDePosition {
    /// Positions recues, dans l ordre.
    private(set) var recues: [PositionDeLecture] = []

    /// Quand il est vrai, chaque ecriture echoue.
    private var refuse: Bool

    init(refuse: Bool = false) {
        self.refuse = refuse
    }

    var nombreDEcritures: Int {
        recues.count
    }

    var derniere: PositionDeLecture? {
        recues.last
    }

    func accepterDeNouveau() {
        refuse = false
    }

    func enregistrer(_ position: PositionDeLecture) async throws {
        guard refuse == false else {
            throw EcritureRefusee()
        }

        recues.append(position)
    }
}
