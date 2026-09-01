import Core
import ReaderEngine
import Storage

//
// ReglageDesZonesDeToucher
//
// La disposition des zones de toucher et l option qui les echange, lues une
// fois pour toute la lecture d un chapitre.
//
// Elles sont lues a l ouverture et non a chaque appui : un reglage relu a
// chaque doigt pose ferait une lecture en base par page tournee.
//
// Le sens de lecture n est pas garde ici. Il appartient au chapitre ouvert, pas
// au reglage, et le confondre avec la disposition serait la faute que la
// section 13 nomme en premier : la direction de l interface et le sens de
// lecture du manga ne sont pas la meme chose.
//

@MainActor
struct ReglageDesZonesDeToucher {
    private let disposition: DispositionDeZones
    private let inversees: Bool

    /// Lit les deux reglages, et retombe sur la disposition standard quand la
    /// base ne repond pas.
    init(lus reglages: MagasinDeReglages?) {
        var disposition = DispositionDeZones.standard
        var inversees = false

        if case let .choix(nom) = try? reglages?.valeur(de: .zonesDeToucher),
           let choisie = DispositionDeZones(rawValue: nom) {
            disposition = choisie
        }

        if case let .booleen(actif) = try? reglages?.valeur(de: .inverserLesZones) {
            inversees = actif
        }

        self.disposition = disposition
        self.inversees = inversees
    }

    /// Intention portee par un appui, en parts de la surface de lecture.
    func intention(
        abscisse: Double,
        ordonnee: Double,
        sens: SensDeLecture
    ) -> IntentionDeNavigation {
        ZonesDeToucher.intention(
            pourAbscisse: abscisse,
            ordonnee: ordonnee,
            sens: sens,
            disposition: disposition,
            zonesInversees: inversees
        )
    }
}
