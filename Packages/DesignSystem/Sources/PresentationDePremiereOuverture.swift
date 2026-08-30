import Core
import SwiftUI

//
// Presentation du parcours de premiere ouverture, section 5.10 de
// DESIGN-SPEC.md.
//
// Le parcours et sa presentation vivent dans deux fichiers, comme le mur
// premium et le sien. `VueDePremiereOuverture` dit a quoi le parcours
// ressemble, ce fichier ci dit quand il occupe l ecran.
//
// Le modificateur prend le parcours, jamais un indicateur de visibilite. Le
// parcours porte l etape affichee, et une etape nulle ne pose rien. Il n existe
// donc aucun appel qui montre l accueil a quelqu un qui l a deja vu, ni qui le
// laisse ouvert apres la derniere etape.
//
// Le parcours couvre l ecran au lieu de se poser sur un voile. Ce n est pas une
// feuille posee sur une bibliotheque qu on regardait : au premier lancement il
// n y a rien derriere, et laisser transparaitre un fond vide donnerait a lire
// un ecran vide avant meme la premiere page.
//

extension View {
    /// Presente le parcours de premiere ouverture au dessus de cette vue.
    ///
    /// - Parameters:
    ///   - parcours: etat du parcours. Une etape nulle ne pose rien.
    ///   - libelles: textes pris dans le catalogue de chaines.
    ///   - libellesPremium: textes du mur premium, pour la troisieme etape.
    ///   - commandes: ce que les boutons declenchent.
    public func premiereOuverture(
        _ parcours: ParcoursDePremiereOuverture,
        libelles: LibellesDePremiereOuverture,
        libellesPremium: LibellesDuMurPremium,
        commandes: CommandesDePremiereOuverture
    ) -> some View {
        modifier(
            PremiereOuverturePresentee(
                parcours: parcours,
                libelles: libelles,
                libellesPremium: libellesPremium,
                commandes: commandes
            )
        )
    }
}

/// Parcours pose au dessus d une vue.
private struct PremiereOuverturePresentee: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var animationsReduites

    let parcours: ParcoursDePremiereOuverture
    let libelles: LibellesDePremiereOuverture
    let libellesPremium: LibellesDuMurPremium
    let commandes: CommandesDePremiereOuverture

    func body(content: Content) -> some View {
        content
            .overlay { superposition }
            .animation(animation, value: parcours.etape)
    }

    @ViewBuilder
    private var superposition: some View {
        if let etape = parcours.etape {
            VueDePremiereOuverture(
                etape: etape,
                parcours: parcours,
                libelles: libelles,
                libellesPremium: libellesPremium,
                commandes: commandes
            )
            .ignoresSafeArea()
            .transition(.opacity)
        }
    }

    /// Le passage d une etape a l autre est un changement d ecran, pas une
    /// modale entrante. Le tableau 1.9 lui donne un fondu pur, sans glissement.
    private var animation: Animation? {
        animationsReduites
            ? Jetons.Mouvement.animationsReduites.animation
            : Jetons.Mouvement.changementDEcran.animation
    }
}
