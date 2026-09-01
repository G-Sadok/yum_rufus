import Core
import DesignSystem
import Foundation
import Storage

//
// SessionDePrereglages
//
// Porte l ecran de gestion des prereglages de lecture, ouvert depuis la ligne
// de navigation de la section Prereglages.
//
// Appliquer un prereglage ecrit dans les reglages de l application, pas
// seulement dans cet ecran : c est ce que fait `MagasinDePrereglages
// .appliquer`, et la colonne des reglages relit derriere.
//

@MainActor
@Observable
final class SessionDePrereglages {
    private(set) var etat: EtatDeGestionDesPrereglages = .chargement

    private let magasin: MagasinDePrereglages?

    /// Relit la colonne de reglages apres un prereglage applique.
    private let apresApplication: @MainActor () -> Void

    init(magasin: MagasinDePrereglages?, apresApplication: @escaping @MainActor () -> Void = {}) {
        self.magasin = magasin
        self.apresApplication = apresApplication
    }

    func recharger() {
        guard let magasin else {
            etat = .erreur(erreurDeLecture())

            return
        }

        do {
            etat = try .chargee(
                magasin.prereglages().map {
                    PrereglageAffiche(
                        id: $0.id,
                        nom: $0.nom,
                        contenu: try? ContenuDePrereglage(donnees: $0.donneesReglages)
                    )
                }
            )
        } catch {
            etat = .erreur(erreurDeLecture())

            NSLog("Prereglages : %@", String(describing: error))
        }
    }

    var commandes: CommandesDePrereglages {
        CommandesDePrereglages(
            enregistrerLActuel: { [weak self] in
                self?.agir { _ in
                    // La capture depuis les reglages courants appartient a
                    // l ecran de lecture, qui connait le chapitre ouvert. Rien
                    // a enregistrer tant qu aucun lecteur n est pose.
                }
            },
            appliquer: { [weak self] identifiant in
                self?.agir { magasin in
                    _ = try magasin.appliquer(identifiant)
                    self?.apresApplication()
                }
            },
            renommer: { _ in
                // Le renommage passe par une saisie que cette version ne pose
                // pas encore. La ligne reste inerte plutot que de renommer
                // sans demander le nouveau nom.
            },
            remplacerParLActuel: { _ in
                // Meme raison que l enregistrement : il faut un lecteur ouvert.
            },
            supprimer: { [weak self] identifiant in
                self?.agir { try $0.supprimer(identifiant) }
            }
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

    private func agir(_ operation: (MagasinDePrereglages) throws -> Void) {
        guard let magasin else { return }

        do {
            try operation(magasin)
            recharger()
        } catch {
            NSLog("Prereglages : %@", String(describing: error))
        }
    }
}
