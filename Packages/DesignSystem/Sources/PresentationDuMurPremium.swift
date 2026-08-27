import Core
import SwiftUI

//
// Presentation du mur premium, sections 5.9 et 10 du cahier de developpement.
//
// La feuille et sa presentation vivent dans deux fichiers, parce qu elles
// repondent a deux questions distinctes. `VueDuMurPremium` dit a quoi le mur
// ressemble. Ce fichier ci dit quand il a le droit de paraitre, et la reponse
// n est pas un booleen.
//
// Le modificateur prend une demande, jamais un indicateur de visibilite. La
// garde de `Core` en tire sa decision, et une demande refusee ne pose rien. Il
// n existe donc aucun appel qui affiche le mur en contournant la regle : le mur
// ne surgit jamais pendant la lecture, et jamais sans geste de l utilisateur.
//

extension View {
    /// Presente le mur premium au dessus de cette vue, sur demande acceptee.
    ///
    /// - Parameters:
    ///   - demande: demande en cours, nulle quand personne n a rien demande.
    ///   - etat: chargement, offre ou erreur.
    ///   - libelles: textes pris dans le catalogue de chaines.
    ///   - commandes: ce que les boutons declenchent.
    public func murPremium(
        demande: DemandeDuMurPremium?,
        etat: EtatDuMurPremium,
        libelles: LibellesDuMurPremium,
        commandes: CommandesDuMurPremium
    ) -> some View {
        modifier(
            MurPremiumPresente(
                demande: demande,
                etat: etat,
                libelles: libelles,
                commandes: commandes
            )
        )
    }
}

/// Voile et feuille poses au dessus d une vue.
private struct MurPremiumPresente: ViewModifier {
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var animationsReduites

    let demande: DemandeDuMurPremium?
    let etat: EtatDuMurPremium
    let libelles: LibellesDuMurPremium
    let commandes: CommandesDuMurPremium

    func body(content: Content) -> some View {
        content
            .overlay { superposition }
            .animation(animation, value: presente)
    }

    /// Vrai quand la garde a accepte la demande en cours.
    private var presente: Bool {
        demande?.estAcceptee == true
    }

    @ViewBuilder
    private var superposition: some View {
        if presente {
            ZStack {
                voile
                VueDuMurPremium(etat: etat, libelles: libelles, commandes: commandes)
            }
            .transition(.opacity)
        }
    }

    /// Voile `scrim` du niveau d elevation 2, section 1.8.
    ///
    /// Le clic hors de la feuille vaut Plus tard, comme le clic hors d une
    /// modale courte vaut Annuler, section 4.8.
    private var voile: some View {
        palette.semantiques.scrim.couleur
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture(perform: commandes.plusTard)
            .accessibilityHidden(true)
    }

    private var animation: Animation? {
        animationsReduites
            ? Jetons.Mouvement.animationsReduites.animation
            : Jetons.Mouvement.modale.animation
    }
}
