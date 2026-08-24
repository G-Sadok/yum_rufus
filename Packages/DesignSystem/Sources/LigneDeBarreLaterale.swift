import Core
import SwiftUI

//
// Une entree de la barre laterale, section 2.2 de DESIGN-SPEC.md.
//
// Hauteur 40, rayon 10, icone a 14 du bord gauche de la ligne, libelle a 40.
// Trois etats de fond : actif, repos, survol. Le focus clavier ajoute un
// contour de 2 en accent avec un decalage de 2, et ne remplace jamais l etat.
//

/// Une entree de la barre laterale.
struct LigneDeBarreLaterale: View {
    @Environment(\.palette) private var palette
    @State private var survolee = false

    let entree: EntreeDeNavigation
    let estActive: Bool
    let estFocalisee: Bool
    let estRepliee: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            contenu
                .frame(
                    maxWidth: .infinity,
                    minHeight: Jetons.BarreLaterale.hauteurDeLigne,
                    alignment: .leading
                )
                .background(fond)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .overlay(contourDeFocus)
        .keyboardShortcut(
            Jetons.RaccourciDeNavigation.touche(pour: entree.destination),
            modifiers: Jetons.RaccourciDeNavigation.modificateur
        )
        .onHover { survolee = $0 }
        .animation(Jetons.Mouvement.survol.animation, value: survolee)
        .help(entree.libelle)
        .accessibilityLabel(entree.libelle)
        .accessibilityAddTraits(estActive ? .isSelected : [])
    }

    @ViewBuilder
    private var contenu: some View {
        if estRepliee {
            icone.frame(maxWidth: .infinity)
        } else {
            ZStack(alignment: .leading) {
                icone.padding(.leading, Jetons.BarreLaterale.decalageDIcone)
                libelle
                    .padding(.leading, Jetons.BarreLaterale.decalageDeLibelle)
                    .padding(.trailing, Jetons.BarreLaterale.decalageDIcone)
            }
        }
    }

    private var icone: some View {
        Image(systemName: entree.symbole)
            .imageScale(.medium)
            .frame(
                width: Jetons.BarreLaterale.tailleDIcone,
                height: Jetons.BarreLaterale.tailleDIcone
            )
            .foregroundStyle(couleurDIcone)
    }

    private var libelle: some View {
        Text(entree.libelle)
            .style(estActive ? Jetons.BarreLaterale.libelleActif : Jetons.BarreLaterale.libelle)
            .foregroundStyle(couleurDeLibelle)
            .lineLimit(1)
    }

    private var fond: some View {
        RoundedRectangle(cornerRadius: Jetons.BarreLaterale.rayonDeLigne, style: .continuous)
            .fill(couleurDeFond)
    }

    @ViewBuilder
    private var contourDeFocus: some View {
        if estFocalisee {
            RoundedRectangle(
                cornerRadius: Jetons.BarreLaterale.rayonDeLigne + Jetons.Focus.decalage,
                style: .continuous
            )
            .strokeBorder(palette.semantiques.focusRing.couleur, lineWidth: Jetons.Focus.epaisseur)
            .padding(-Jetons.Focus.decalage)
        }
    }

    private var couleurDeFond: Color {
        if estActive {
            palette.surfaces.selected.couleur
        } else if survolee {
            palette.surfaces.card.couleur
        } else {
            .clear
        }
    }

    private var couleurDeLibelle: Color {
        estActive ? palette.textes.primary.couleur : palette.textes.secondary.couleur
    }

    private var couleurDIcone: Color {
        estActive ? palette.textes.primary.couleur : palette.textes.tertiary.couleur
    }
}
