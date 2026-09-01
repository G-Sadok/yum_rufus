import Core
import DesignSystem
import Foundation
import Storage

//
// SessionDeStatistiques
//
// Porte l ecran Statistiques : lit les journees de lecture et l objectif,
// applique ce que l utilisateur change.
//
// Les statistiques et l objectif sont lus ensemble par le magasin, dans une
// seule transaction. Les relire separement donnerait une serie de journees et
// un objectif qui ne se rapportent pas au meme instant.
//

@MainActor
@Observable
final class SessionDeStatistiques {
    private(set) var etat: EtatDeStatistiques = .chargement

    private let magasin: MagasinDeStatistiques?

    init(magasin: MagasinDeStatistiques?) {
        self.magasin = magasin
    }

    func recharger() {
        guard let magasin else {
            etat = .erreur(erreurDeLecture())

            return
        }

        do {
            etat = try .chargees(magasin.statistiques(), magasin.rappel())
        } catch {
            etat = .erreur(erreurDeLecture())

            NSLog("Statistiques : %@", String(describing: error))
        }
    }

    func commandes(ouvrirLaBibliotheque: @escaping @MainActor () -> Void) -> CommandesDeStatistiques {
        CommandesDeStatistiques(
            definirLObjectif: { [weak self] objectif in
                self?.ecrire { try $0.definirLObjectif(objectif) }
            },
            basculerLeRappel: { [weak self] actif in
                self?.ecrire { magasin in
                    // Le rappel est immuable : on le reconstruit en gardant son
                    // heure, que l utilisateur a pu regler par ailleurs.
                    let courant = try magasin.rappel()

                    try magasin.definirLeRappel(
                        RappelDObjectif(actif: actif, heure: courant.heure, minute: courant.minute)
                    )
                }
            },
            ouvrirLaBibliotheque: ouvrirLaBibliotheque
        )
    }

    /// Etat d erreur commun aux deux causes, base absente ou lecture ratee.
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

    private func ecrire(_ operation: (MagasinDeStatistiques) throws -> Void) {
        guard let magasin else { return }

        do {
            try operation(magasin)
            recharger()
        } catch {
            NSLog("Statistiques : %@", String(describing: error))
        }
    }
}
