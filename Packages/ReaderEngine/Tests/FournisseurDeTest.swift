import Foundation
@testable import ReaderEngine

//
// FournisseurDeTest
//
// Fournisseur d octets que le test ouvre et referme a la main.
//
// Ferme, il retient chaque demande sans jamais rendre les octets, ce qui laisse
// le temps d observer la file de precharge et de l annuler a un instant choisi.
// L attente est une boucle de sommeil courte plutot qu une continuation, parce
// qu elle doit rester annulable : c est precisement l annulation que les tests
// verifient.
//

actor FournisseurDeTest: FournisseurDeChapitre {
    nonisolated let chapitre = UUID()
    nonisolated let nombreDePages: Int

    private let octetsDUnePage: Data
    private var ouvert: Bool
    private var demandeesInternes: [Int] = []

    init(nombreDePages: Int, octets: Data = Data([0x01, 0x02, 0x03]), ouvert: Bool = true) {
        self.nombreDePages = nombreDePages
        octetsDUnePage = octets
        self.ouvert = ouvert
    }

    /// Pages demandees depuis l ouverture, dans l ordre des demandes.
    var demandees: [Int] {
        demandeesInternes
    }

    /// Laisse passer les octets, et les demandes en attente avec eux.
    func ouvrir() {
        ouvert = true
    }

    func octets(page index: Int) async throws -> DonneesDePage {
        demandeesInternes.append(index)

        while ouvert == false {
            try Task.checkCancellation()
            try await Task.sleep(for: .milliseconds(2))
        }

        return DonneesDePage(nom: "page-\(index)", donnees: octetsDUnePage)
    }
}
