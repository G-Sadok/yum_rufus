import Core
import DesignSystem
import SwiftUI

//
// Assemblage de la coquille.
//
// L application ne fournit que ce qu elle est seule a connaitre : les libelles
// du catalogue de chaines et le contenu de chaque destination. Toute la
// geometrie et toutes les couleurs viennent du paquet DesignSystem.
//

/// Racine de l interface.
struct CoquilleDeLApplication: View {
    /// Etat de la navigation principale.
    let etat: EtatDeCoquille

    /// Etat de l ecran Historique, partage entre sa zone de contenu et la
    /// commande d effacement de la barre d outils.
    let historique: EtatDHistorique

    var body: some View {
        VueDeCoquille(
            etat: etat,
            entrees: entrees,
            appelPremium: appelPremium,
            libelleDuRepli: Chaines.Navigation.repli,
            actions: commandes(de:),
            contenu: contenu(de:)
        )
        .palette(theme: .defaut, apparence: .defaut)
        .modifier(TailleMinimaleDeFenetre())
    }

    private func contenu(de destination: DestinationPrincipale) -> some View {
        VueDeDestination(destination: destination, historique: historique) { cible in
            etat.selectionner(cible)
        }
    }

    /// Commandes de barre d outils de la destination affichee.
    ///
    /// La section 5.2 pose `Effacer l historique` dans la barre d outils. Le
    /// bouton disparait quand l historique est deja vide : une commande qui n a
    /// rien a effacer n a rien a faire la, et l etat vide invite deja a agir
    /// ailleurs.
    @ViewBuilder
    private func commandes(de destination: DestinationPrincipale) -> some View {
        if destination == .historique, historique.porteDesEntrees {
            CommandeDeBarreDOutils(
                libelle: Chaines.Historique.effacer,
                symbole: Jetons.IconeDHistorique.effacer
            ) {
                historique.demanderLEffacement()
            }
        }
    }

    private var entrees: [EntreeDeNavigation] {
        DestinationPrincipale.allCases.map { destination in
            EntreeDeNavigation(destination: destination, libelle: Chaines.navigation(destination))
        }
    }

    private var appelPremium: AppelPremium {
        AppelPremium(titre: Chaines.Premium.titre, sousTitre: Chaines.Premium.sousTitre)
    }
}

/// Taille minimale de la fenetre, section 2.1.
///
/// La contrainte n a de sens que sur macOS. Sur iPhone et iPad la scene prend
/// la taille de l ecran, et imposer 1024 par 720 la rendrait defilante.
private struct TailleMinimaleDeFenetre: ViewModifier {
    func body(content: Content) -> some View {
        #if os(macOS)
            content.frame(
                minWidth: Jetons.Fenetre.largeurMinimale,
                minHeight: Jetons.Fenetre.hauteurMinimale
            )
        #else
            content
        #endif
    }
}
