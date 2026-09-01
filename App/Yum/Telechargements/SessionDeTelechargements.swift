import Core
import DesignSystem
import Foundation
import Storage

//
// SessionDeTelechargements
//
// Porte la file de telechargement, ouverte depuis la ligne de navigation de la
// section Telechargements.
//
// Passer une tache en premier ne la demarre pas : la file garde son ordre de
// service, et c est le moteur qui decide quand la prendre. Relever sa priorite
// suffit a la faire remonter.
//

@MainActor
@Observable
final class SessionDeTelechargements {
    private(set) var etat: EtatDeFileDeTelechargements = .chargement

    private let magasin: MagasinDeTelechargements?

    init(magasin: MagasinDeTelechargements?) {
        self.magasin = magasin
    }

    func recharger() {
        guard let magasin else {
            etat = .erreur(erreurDeLecture())

            return
        }

        do {
            etat = try .chargee(magasin.taches())
        } catch {
            etat = .erreur(erreurDeLecture())

            NSLog("Telechargements : %@", String(describing: error))
        }
    }

    func commandes(ouvrirLaBibliotheque: @escaping @MainActor () -> Void) -> CommandesDeTelechargements {
        CommandesDeTelechargements(
            mettreEnPause: { [weak self] identifiant in
                self?.agir { try $0.suspendre(identifiant) }
            },
            reprendre: { [weak self] identifiant in
                self?.agir { try $0.remettreEnAttente(identifiant) }
            },
            passerEnPremier: { [weak self] identifiant in
                self?.agir { try $0.definirLaPriorite(.haute, de: identifiant) }
            },
            annuler: { [weak self] identifiant in
                self?.agir { try $0.annuler(identifiant) }
            },
            ouvrirLaBibliotheque: ouvrirLaBibliotheque
        )
    }

    private func erreurDeLecture() -> EtatDeContenu {
        .erreur(
            titre: Chaines.Erreur.reglagesTitre,
            phrase: Chaines.Erreur.reglagesPhrase,
            reessayer: ActionDEtat(libelle: Chaines.Erreur.reessayer) { [weak self] in
                self?.recharger()
            },
            repli: nil
        )
    }

    private func agir(_ operation: (MagasinDeTelechargements) throws -> Void) {
        guard let magasin else { return }

        do {
            try operation(magasin)
            recharger()
        } catch {
            NSLog("Telechargements : %@", String(describing: error))
        }
    }
}
