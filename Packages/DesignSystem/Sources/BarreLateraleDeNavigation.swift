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
    let appelPremium: AppelPremium?
    let ouvrirLeMurPremium: (@MainActor () -> Void)?

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

            if let appelPremium {
                BlocPremium(
                    appel: appelPremium,
                    estRepliee: etat.barreLateraleRepliee,
                    ouvrir: ouvrirLeMurPremium
                )
            }
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

/// Bloc d appel a l abonnement, cale en bas de la barre laterale.
private struct BlocPremium: View {
    @Environment(\.palette) private var palette

    @FocusState private var focalise: Bool

    let appel: AppelPremium
    let estRepliee: Bool

    /// Ouvre le mur premium, nul tant qu aucun ecran ne sait le presenter.
    ///
    /// Un bloc sans action reste un bloc, pas un bouton : une cible qui ne
    /// repond pas au clic coute plus cher qu une cible absente.
    let ouvrir: (@MainActor () -> Void)?

    var body: some View {
        Group {
            if let ouvrir {
                Button(action: ouvrir) { bloc }
                    .buttonStyle(.plain)
                    .focusEffectDisabled()
                    .focused($focalise)
                    .overlay(contourDeFocus)
                    .accessibilityAddTraits(.isButton)
            } else {
                bloc
            }
        }
        .help(appel.titre)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(appel.titre)
        .accessibilityValue(appel.sousTitre)
    }

    private var bloc: some View {
        contenu
            .frame(maxWidth: .infinity, minHeight: Jetons.BarreLaterale.hauteurDuBlocPremium)
            .background(fond)
            .contentShape(Rectangle())
    }

    @ViewBuilder
    private var contourDeFocus: some View {
        if focalise {
            RoundedRectangle(
                cornerRadius: Jetons.BarreLaterale.rayonDuBlocPremium,
                style: .continuous
            )
            .strokeBorder(palette.semantiques.focusRing.couleur, lineWidth: Jetons.Focus.epaisseur)
            .padding(-Jetons.Focus.decalage)
        }
    }

    @ViewBuilder
    private var contenu: some View {
        if estRepliee {
            couronne
        } else {
            HStack(spacing: Jetons.Espace.x3) {
                couronne
                VStack(alignment: .leading, spacing: 0) {
                    Text(appel.titre)
                        .style(Jetons.BarreLaterale.libelleActif)
                        .foregroundStyle(palette.semantiques.accentText.couleur)
                    Text(appel.sousTitre)
                        .style(Jetons.Typo.footnote)
                        .foregroundStyle(palette.textes.tertiary.couleur)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Jetons.BarreLaterale.decalageDIcone)
        }
    }

    private var couronne: some View {
        Image(systemName: Jetons.Icone.premium)
            .imageScale(.medium)
            .frame(
                width: Jetons.BarreLaterale.tailleDIcone,
                height: Jetons.BarreLaterale.tailleDIcone
            )
            .foregroundStyle(palette.semantiques.accent.couleur)
    }

    private var fond: some View {
        RoundedRectangle(cornerRadius: Jetons.BarreLaterale.rayonDuBlocPremium, style: .continuous)
            .fill(palette.surfaces.premium.couleur)
    }
}
