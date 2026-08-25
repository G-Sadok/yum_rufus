import SwiftUI

//
// Commande de barre d outils, sections 2.1, 4.6 et 5.2 de DESIGN-SPEC.md.
//
// Hauteur 28, rayon 8, variante secondaire du tableau 4.6. C est la forme des
// boutons de tri et d ajout de la section 5.1, et celle du bouton
// `Effacer l historique` de la section 5.2.
//

/// Un bouton pose dans la barre d outils de la coquille.
public struct CommandeDeBarreDOutils: View {
    @Environment(\.palette) private var palette
    @FocusState private var focalisee: Bool

    private let libelle: String
    private let symbole: String
    private let action: () -> Void

    /// Construit la commande.
    ///
    /// - Parameters:
    ///   - libelle: libelle visible, pris dans le catalogue de chaines.
    ///   - symbole: symbole SF pose devant le libelle.
    ///   - action: travail declenche par le bouton.
    public init(libelle: String, symbole: String, action: @escaping () -> Void) {
        self.libelle = libelle
        self.symbole = symbole
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Jetons.BarreDOutils.ecartDansUneCommande) {
                Image(systemName: symbole)
                    .font(policeDuSymbole)

                Text(libelle)
                    .style(Jetons.BarreDOutils.libelleDeCommande)
            }
            .foregroundStyle(palette.textes.primary.couleur)
            .padding(.horizontal, Jetons.BarreDOutils.remplissageDeCommande)
            .frame(height: Jetons.BarreDOutils.hauteurDeBouton)
            .background(fond)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .focused($focalisee)
        .overlay(contourDeFocus)
    }

    /// La taille de rendu d un symbole est une geometrie de composant, pas un
    /// role de l echelle typographique, section 1.10.
    private var policeDuSymbole: Font {
        .system(size: Jetons.Icone.tailleEnBarreDOutils)
    }

    private var fond: some View {
        RoundedRectangle(cornerRadius: Jetons.BarreDOutils.rayonDeBouton, style: .continuous)
            .fill(palette.surfaces.menu.couleur)
            .overlay {
                RoundedRectangle(cornerRadius: Jetons.BarreDOutils.rayonDeBouton, style: .continuous)
                    .strokeBorder(
                        palette.semantiques.border.couleur,
                        lineWidth: Jetons.Fenetre.epaisseurDuFilet
                    )
            }
    }

    @ViewBuilder
    private var contourDeFocus: some View {
        if focalisee {
            RoundedRectangle(
                cornerRadius: Jetons.BarreDOutils.rayonDeBouton + Jetons.Focus.decalage,
                style: .continuous
            )
            .strokeBorder(palette.semantiques.focusRing.couleur, lineWidth: Jetons.Focus.epaisseur)
            .padding(-Jetons.Focus.decalage)
        }
    }
}
