import Core
import SwiftUI

//
// Une ligne d un ecran de detail du stockage.
//
// Elle vit dans son propre fichier et non dans celui de l ecran, pour la meme
// raison que la ligne de reglage vit hors de la carte de section : c est un
// composant a part entiere, avec ses etats de survol et de focus, et le
// regrouper avec l ecran melangerait la mise en page d une liste et le
// comportement d une de ses lignes.
//
// La ligne ne supprime rien elle meme. Son bouton pose une demande, que l ecran
// range dans sa garde et que la modale de la section 4.8 confirme.
//

/// Une ligne de poste, sur le modele de la ligne de reglage a description.
struct LigneDePosteDeStockage: View {
    @Environment(\.palette) private var palette
    @State private var survolee = false
    @FocusState private var focalisee: Bool

    let poste: PosteDeStockage
    let categorie: CategorieDeStockage
    let retenu: Bool
    let libelles: LibellesDeStockage
    let basculer: () -> Void
    let supprimer: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            caseDeSelection

            textes
                .padding(.leading, Jetons.Stockage.gouttiereApresLIcone)

            Spacer(minLength: Jetons.Stockage.ecartAvantLaTaille)

            taille
            commande
                .padding(.leading, Jetons.Stockage.ecartAvantLaTaille)
        }
        .padding(.horizontal, Jetons.Stockage.margeLaterale)
        .frame(minHeight: Jetons.Stockage.hauteurDePoste)
        .background(survolee ? palette.surfaces.cardHover.couleur : Color.clear)
        .overlay(contourDeFocus)
        .onHover { survolee = $0 }
    }

    /// Case de selection, equivalent atteignable du clic maintenu de la section
    /// 4.5.
    ///
    /// Une case et non un clic maintenu seul : l ecran vit aussi au clavier, et
    /// un geste de souris n a pas d equivalent au clavier tant qu il n a pas de
    /// cible focalisable.
    private var caseDeSelection: some View {
        Button(action: basculer) {
            Image(systemName: retenu ? Jetons.Stockage.symboleCoche : Jetons.Stockage.symboleNonCoche)
                .font(.system(size: Jetons.Stockage.tailleDuSymboleDeSelection))
                .foregroundStyle(
                    retenu ? palette.semantiques.accent.couleur : palette.textes.tertiary.couleur
                )
                .frame(
                    width: Jetons.Stockage.coteDeLaSelection,
                    height: Jetons.Stockage.coteDeLaSelection
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .focused($focalisee)
        .accessibilityLabel(libelles.selectionner)
        .accessibilityValue(TexteDeStockage.etiquette(de: poste, categorie: categorie, libelles: libelles))
        .accessibilityAddTraits(retenu ? .isSelected : [])
    }

    private var textes: some View {
        VStack(alignment: .leading, spacing: Jetons.Stockage.ecartApresLeTitre) {
            Text(TexteDeStockage.titre(de: poste, categorie: categorie, libelles: libelles))
                .style(Jetons.Stockage.titreDePoste)
                .foregroundStyle(palette.textes.primary.couleur)

            Text(TexteDeStockage.sousLigne(de: poste, libelles: libelles))
                .style(Jetons.Stockage.sousLigneDePoste)
                .foregroundStyle(palette.textes.tertiary.couleur)
        }
        .lineLimit(1)
        .accessibilityHidden(true)
    }

    /// Poids reel du poste. Chiffres tabulaires, section 1.5.
    private var taille: some View {
        Text(TexteDeStockage.taille(poste.octets, libelles: libelles))
            .style(Jetons.Stockage.taille, chiffresTabulaires: true)
            .foregroundStyle(palette.textes.secondary.couleur)
            .accessibilityHidden(true)
    }

    /// Suppression d un poste seul, sans passer par la selection.
    private var commande: some View {
        Button(libelles.supprimer, action: supprimer)
            .buttonStyle(.plain)
            .style(Jetons.FicheDeSerie.actionDeListe)
            .foregroundStyle(palette.semantiques.danger.couleur)
    }

    @ViewBuilder
    private var contourDeFocus: some View {
        if focalisee {
            RoundedRectangle(cornerRadius: Jetons.Focus.decalage, style: .continuous)
                .strokeBorder(palette.semantiques.focusRing.couleur, lineWidth: Jetons.Focus.epaisseur)
                .padding(-Jetons.Focus.decalage)
        }
    }
}
