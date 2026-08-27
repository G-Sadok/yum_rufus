import Core
import Foundation
@testable import ReaderEngine

//
// ChargeurDeTest
//
// Chargeur de chapitre que le test ouvre, ferme et fait echouer a la main.
//
// Ferme, il retient la demande sans rendre le segment, ce qui laisse observer
// l etat de chargement du lecteur. L attente est une boucle de sommeil courte
// plutot qu une continuation, pour la meme raison que dans FournisseurDeTest :
// elle doit rester annulable.
//

/// Erreur de source simulee.
struct SourceInjoignable: Error, Equatable {}

/// Chargeur qui rend des segments prepares d avance.
actor ChargeurDeTest: ChargeurDeChapitre {
    private var segments: [UUID: SegmentDeChapitre]
    private var ouvert: Bool
    private var refuse: Bool
    private var demandesInternes: [UUID] = []

    init(segments: [SegmentDeChapitre] = [], ouvert: Bool = true, refuse: Bool = false) {
        self.segments = Dictionary(uniqueKeysWithValues: segments.map { ($0.chapitreId, $0) })
        self.ouvert = ouvert
        self.refuse = refuse
    }

    /// Chapitres demandes depuis l ouverture, dans l ordre.
    var demandes: [UUID] {
        demandesInternes
    }

    /// Laisse passer les segments, et les demandes en attente avec eux.
    func ouvrir() {
        ouvert = true
    }

    /// Fait echouer chaque demande.
    func refuser() {
        refuse = true
    }

    /// Accepte de nouveau les demandes.
    func accepter() {
        refuse = false
    }

    func segment(pourChapitre chapitreId: UUID) async throws -> SegmentDeChapitre {
        demandesInternes.append(chapitreId)

        while ouvert == false {
            try Task.checkCancellation()
            try await Task.sleep(for: .milliseconds(2))
        }

        guard refuse == false, let segment = segments[chapitreId] else {
            throw SourceInjoignable()
        }

        return segment
    }
}

/// Marqueur qui consigne les chapitres au lieu de les ecrire.
actor MarqueurEspion: MarqueurDeChapitreLu {
    /// Erreur d ecriture simulee.
    struct MarquageRefuse: Error, Equatable {}

    /// Chapitres marques lus, dans l ordre.
    private(set) var marques: [UUID] = []

    private var refuse: Bool

    init(refuse: Bool = false) {
        self.refuse = refuse
    }

    var nombreDeMarquages: Int {
        marques.count
    }

    func accepterDeNouveau() {
        refuse = false
    }

    func marquerLu(_ chapitreId: UUID) async throws {
        guard refuse == false else {
            throw MarquageRefuse()
        }

        marques.append(chapitreId)
    }
}
