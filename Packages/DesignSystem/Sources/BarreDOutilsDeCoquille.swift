import SwiftUI

//
// Barre d outils de la coquille, sections 2.1 et 5.1 de DESIGN-SPEC.md.
//
// Hauteur 60, unifiee avec la barre de titre, fond `surface.chrome`, filet de
// 1 px en dessous. Le titre de l ecran se pose a 172 du bord de la fenetre.
//
// Outre le titre et la bascule de repli, la barre accueille les commandes
// propres a l ecran affiche, comme `Effacer l historique` de la section 5.2.
// Elles arrivent avec leur ecran, sous forme de vues deja composees : la
// coquille leur donne une place, elle n en connait aucune.
//

/// Bascule de repli de la barre laterale, posee dans la barre d outils.
struct BasculeDeRepli {
    /// Libelle d accessibilite et info bulle, pris dans le catalogue.
    let libelle: String
    /// Etat courant de la barre laterale.
    let estRepliee: Bool
    /// Action a executer sur activation.
    let action: () -> Void
}

/// Barre d outils de la coquille.
struct BarreDOutilsDeCoquille<Actions: View>: View {
    @Environment(\.palette) private var palette
    @FocusState private var basculeFocalisee: Bool

    let titre: String
    let bascule: BasculeDeRepli?
    @ViewBuilder let actions: Actions

    var body: some View {
        ZStack(alignment: .leading) {
            Text(titre)
                .style(Jetons.Typo.title2)
                .foregroundStyle(palette.textes.primary.couleur)
                .padding(.leading, Jetons.BarreDOutils.decalageDuTitre)

            HStack(spacing: Jetons.BarreDOutils.ecartEntreCommandes) {
                actions

                if let bascule {
                    boutonDeBascule(bascule)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, Jetons.Contenu.margeLaterale)
        }
        .frame(maxWidth: .infinity, minHeight: Jetons.BarreDOutils.hauteur)
        .background(palette.surfaces.chrome.couleur)
        .overlay(alignment: .bottom) { filet }
        .accessibilityElement(children: .contain)
    }

    private var filet: some View {
        Rectangle()
            .fill(couleurDuFilet)
            .frame(height: Jetons.Fenetre.epaisseurDuFilet)
    }

    /// Le document ne chiffre le filet qu en apparence sombre. En apparence
    /// claire le jeton `separator` joue le meme role a la meme epaisseur.
    private var couleurDuFilet: Color {
        switch palette.apparence {
        case .sombre: Jetons.Fenetre.filetSousLaBarreDeTitre.couleur
        case .clair: palette.semantiques.separator.couleur
        }
    }

    private func boutonDeBascule(_ bascule: BasculeDeRepli) -> some View {
        Button(action: bascule.action) {
            Image(systemName: Jetons.IconeDeCoquille.replierLaBarreLaterale)
                .imageScale(.medium)
                .foregroundStyle(palette.textes.secondary.couleur)
                .frame(
                    width: Jetons.BarreDOutils.hauteurDeBouton,
                    height: Jetons.BarreDOutils.hauteurDeBouton
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .focused($basculeFocalisee)
        .overlay(contourDeFocus)
        .keyboardShortcut(
            Jetons.RaccourciDeNavigation.toucheDeRepli,
            modifiers: Jetons.RaccourciDeNavigation.modificateurDeRepli
        )
        .help(bascule.libelle)
        .accessibilityLabel(bascule.libelle)
        .accessibilityAddTraits(bascule.estRepliee ? .isSelected : [])
    }

    @ViewBuilder
    private var contourDeFocus: some View {
        if basculeFocalisee {
            RoundedRectangle(
                cornerRadius: Jetons.BarreDOutils.rayonDeBouton + Jetons.Focus.decalage,
                style: .continuous
            )
            .strokeBorder(palette.semantiques.focusRing.couleur, lineWidth: Jetons.Focus.epaisseur)
            .padding(-Jetons.Focus.decalage)
        }
    }
}
