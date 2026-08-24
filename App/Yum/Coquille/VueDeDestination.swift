import Core
import DesignSystem
import SwiftUI

//
// Contenu affiche pour chaque destination.
//
// Les ecrans eux memes arrivent avec leurs fonctionnalites. Ce que la coquille
// montre aujourd hui n est pas un bouchon : c est l etat reel de chaque ecran
// sur une installation neuve, avec les libelles exacts du tableau 6.3.
//
// Reglages fait exception. La section 5.5 dit que sa colonne est toujours
// complete, meme sur une installation neuve, ou seules les valeurs disent
// l absence. Cet ecran n a donc pas d etat vide a montrer, et sa zone reste
// nue tant que l ecran Reglages n est pas livre.
//

/// Zone de contenu d une destination.
struct VueDeDestination: View {
    /// Destination affichee.
    let destination: DestinationPrincipale

    /// Ouvre une autre destination, pour les actions des etats vides.
    let ouvrir: (DestinationPrincipale) -> Void

    var body: some View {
        switch destination {
        case .bibliotheque:
            VueDEtatDeContenu(
                .vide(
                    symbole: Jetons.icone(de: destination),
                    titre: Chaines.EtatVide.bibliothequeTitre,
                    phrase: Chaines.EtatVide.bibliothequePhrase,
                    action: ActionDEtat(libelle: Chaines.EtatVide.bibliothequeAction) {
                        ouvrir(.parcourir)
                    }
                )
            )

        case .historique:
            VueDEtatDeContenu(
                .vide(
                    symbole: Jetons.icone(de: destination),
                    titre: Chaines.EtatVide.historiqueTitre,
                    phrase: Chaines.EtatVide.historiquePhrase,
                    action: ActionDEtat(libelle: Chaines.EtatVide.historiqueAction) {
                        ouvrir(.bibliotheque)
                    }
                )
            )

        case .parcourir:
            // Le tableau 6.3 propose Ajouter une source. Le menu d ajout arrive
            // avec l ecran Parcourir. Un bouton sans destination vaut moins
            // qu un etat vide sans bouton, la section 4.10 rend l action
            // facultative.
            VueDEtatDeContenu(
                .vide(
                    symbole: Jetons.icone(de: destination),
                    titre: Chaines.EtatVide.parcourirTitre,
                    phrase: Chaines.EtatVide.parcourirPhrase,
                    action: nil
                )
            )

        case .rechercher:
            VueDEtatDeContenu(
                .vide(
                    symbole: Jetons.icone(de: destination),
                    titre: Chaines.EtatVide.rechercherTitre,
                    phrase: Chaines.EtatVide.rechercherPhrase,
                    action: nil
                )
            )

        case .reglages:
            EmptyView()
        }
    }
}
