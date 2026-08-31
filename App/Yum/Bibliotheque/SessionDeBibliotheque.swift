import Core
import DesignSystem
import Foundation
import Storage

//
// SessionDeBibliotheque
//
// Porte l ecran Bibliotheque : les series rangees, categorie par categorie.
//
// Le compteur de chapitres non lus vient de la base, ou un declencheur le tient
// a jour. Il n est jamais recompte ici : c est l erreur numero cinq du cahier
// de developpement, celle qui fait ramer la grille des qu une bibliotheque
// depasse quelques centaines de series.
//

@MainActor
@Observable
final class SessionDeBibliotheque {
    private(set) var etat: EtatDeBibliotheque = .chargement

    private let magasin: MagasinDeCategories?

    init(magasin: MagasinDeCategories?) {
        self.magasin = magasin
    }

    func recharger() {
        guard let magasin else {
            etat = .erreur(erreurDeLecture())

            return
        }

        do {
            etat = .chargee(
                try magasin.series(dans: .tout).map {
                    SerieDeGrille(id: $0.id, titre: $0.titre, chapitresNonLus: $0.chapitresNonLus)
                }
            )
        } catch {
            etat = .erreur(erreurDeLecture())

            NSLog("Bibliotheque : %@", String(describing: error))
        }
    }

    func commandes(ajouterUneSource: @escaping @MainActor () -> Void) -> CommandesDeBibliotheque {
        CommandesDeBibliotheque(
            ouvrir: { _ in
                // La fiche de serie existe, mais la navigation vers elle
                // appartient a la coquille, qui ne la pose pas encore.
            },
            ajouterUneSource: ajouterUneSource
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
}
