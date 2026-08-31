import Core
import SwiftUI

//
// Barre laterale encastree, section 2.2 de DESIGN-SPEC.md.
//
// Largeur 196 deployee, 56 repliee, rayon 14, fond `surface.sidebar`. Les cinq
// entrees sont dans l ordre impose par `DestinationPrincipale.allCases`, jamais
// dans un ordre choisi par l appelant.
//

/// Barre laterale de la navigation principale.
struct BarreLateraleDeNavigation: View {
    @Environment(\.palette) private var palette
    @FocusState private var entreeFocalisee: DestinationPrincipale?

    let etat: EtatDeCoquille
    let entrees: [EntreeDeNavigation]

    var body: some View {
        VStack(spacing: Jetons.BarreLaterale.espaceEntreLignes) {
            ForEach(entrees) { entree in
                LigneDeBarreLaterale(
                    entree: entree,
                    estActive: entree.destination == etat.destination,
                    estFocalisee: entreeFocalisee == entree.destination,
                    estRepliee: etat.barreLateraleRepliee
                ) {
                    etat.selectionner(entree.destination)
                    entreeFocalisee = entree.destination
                }
                .focused($entreeFocalisee, equals: entree.destination)
            }

            Spacer(minLength: Jetons.Espace.x1)
        }
        .padding(.vertical, Jetons.BarreLaterale.margeVerticale)
        .padding(.horizontal, Jetons.BarreLaterale.margeLateraleDeLigne)
        .frame(width: etat.largeurDeLaBarreLaterale)
        .background(fond)
        .modifier(NavigationAuClavier(etat: etat, entreeFocalisee: $entreeFocalisee))
        .accessibilityElement(children: .contain)
    }

    private var fond: some View {
        RoundedRectangle(cornerRadius: Jetons.BarreLaterale.rayon, style: .continuous)
            .fill(palette.surfaces.sidebar.couleur)
    }
}

/// Deplacement de la selection par les fleches du clavier.
///
/// La fleche ne boucle pas, comme dans toute liste du systeme. Le deplacement
/// change la selection et le focus ensemble, sinon le contour de focus resterait
/// sur une entree qui n est plus active.
private struct NavigationAuClavier: ViewModifier {
    let etat: EtatDeCoquille
    @FocusState.Binding var entreeFocalisee: DestinationPrincipale?

    func body(content: Content) -> some View {
        #if os(macOS)
            content.onMoveCommand { direction in
                switch direction {
                case .up:
                    etat.allerALaDestinationPrecedente()
                case .down:
                    etat.allerALaDestinationSuivante()
                default:
                    return
                }
                entreeFocalisee = etat.destination
            }
        #else
            content
        #endif
    }
}
