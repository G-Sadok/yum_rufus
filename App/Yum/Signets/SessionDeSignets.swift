import Core
import DesignSystem
import Foundation
import Storage

//
// SessionDeSignets
//
// Porte la liste des signets, ouverte depuis la ligne de navigation de la
// section Bibliotheque.
//
// Ouvrir un signet demande un lecteur, que la coquille ne pose pas encore. La
// commande reste donc nulle plutot qu inerte : la vue sait alors ne pas offrir
// un geste qui ne menerait nulle part, ce qu un bloc vide ne dirait pas.
//

@MainActor
@Observable
final class SessionDeSignets {
    private(set) var etat: EtatDeListeDeSignets = .chargement

    private let magasin: MagasinDeSignets?

    init(magasin: MagasinDeSignets?) {
        self.magasin = magasin
    }

    func recharger() {
        guard let magasin else {
            etat = .erreur(erreurDeLecture())

            return
        }

        do {
            etat = try .chargee(magasin.signets())
        } catch {
            etat = .erreur(erreurDeLecture())

            NSLog("Signets : %@", String(describing: error))
        }
    }

    func commandes(ouvrirLaBibliotheque: @escaping @MainActor () -> Void) -> CommandesDeSignets {
        CommandesDeSignets(
            ouvrir: nil,
            supprimer: { [weak self] identifiant in
                self?.agir { _ = try $0.retirer(identifiant) }
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

    private func agir(_ operation: (MagasinDeSignets) throws -> Void) {
        guard let magasin else { return }

        do {
            try operation(magasin)
            recharger()
        } catch {
            NSLog("Signets : %@", String(describing: error))
        }
    }
}
