import Core
import Foundation
import SwiftUI

//
// Barre de categories, section 5.1 de DESIGN-SPEC.md.
//
// Onglets textuels avec compteur, sous la barre d outils de la bibliotheque.
// L onglet actif porte un fond `surface.menu` de rayon 8, jamais une capsule,
// jamais un aplat accent : la section 1.3 reserve l accent a ce sur quoi on
// peut agir, et un onglet deja actif n est plus une action.
//
// Tout est le premier onglet et ne porte aucun menu contextuel. La regle vaut
// pour l interface comme pour la base : il n y a rien a renommer, a deplacer ni
// a supprimer derriere lui.
//

/// Barre de categories de la bibliotheque.
public struct BarreDeCategories: View {
    @Environment(\.accessibilityReduceMotion) private var animationsReduites
    @FocusState private var ongletFocalise: SelectionDeCategorie?

    private let onglets: [OngletDeCategorie]
    private let selection: SelectionDeCategorie
    private let commandes: CommandesDeCategorie?
    private let selectionner: (SelectionDeCategorie) -> Void

    /// Construit la barre.
    ///
    /// - Parameters:
    ///   - onglets: onglets produits par `OngletDeCategorie.barre`, Tout en
    ///     tete.
    ///   - selection: onglet actif.
    ///   - commandes: menu contextuel des categories, absent quand l ecran
    ///     n ouvre pas la gestion des categories.
    ///   - selectionner: appele quand l utilisateur change d onglet.
    public init(
        onglets: [OngletDeCategorie],
        selection: SelectionDeCategorie,
        commandes: CommandesDeCategorie? = nil,
        selectionner: @escaping (SelectionDeCategorie) -> Void
    ) {
        self.onglets = onglets
        self.selection = selection
        self.commandes = commandes
        self.selectionner = selectionner
    }

    public var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Jetons.BarreDeCategories.espaceEntreOnglets) {
                ForEach(onglets) { onglet in
                    ongletAffiche(onglet)
                }
            }
        }
        .scrollIndicators(.hidden)
        .frame(height: Jetons.BarreDeCategories.hauteur)
        .padding(.bottom, Jetons.BarreDeCategories.margeBasse)
        .accessibilityElement(children: .contain)
    }

    private func ongletAffiche(_ onglet: OngletDeCategorie) -> some View {
        OngletDeCategorieVue(
            onglet: onglet,
            estActif: onglet.selection == selection,
            estFocalise: ongletFocalise == onglet.selection,
            animationsReduites: animationsReduites
        ) {
            selectionner(onglet.selection)
            ongletFocalise = onglet.selection
        }
        .focused($ongletFocalise, equals: onglet.selection)
        .contextMenu { menu(de: onglet) }
    }

    /// Menu contextuel d un onglet.
    ///
    /// Vide sur Tout, et vide quand l ecran n a pas passe de commandes. Un
    /// menu vide n apparait pas.
    @ViewBuilder
    private func menu(de onglet: OngletDeCategorie) -> some View {
        if let commandes, let identifiant = onglet.selection.identifiant {
            let rang = rangDeLaCategorie(onglet.selection)

            Button(commandes.libelleRenommer) { commandes.renommer(identifiant) }

            Button(commandes.libelleDeplacerAvant) { commandes.deplacer(identifiant, rang - 1) }
                .disabled(rang <= 0)

            Button(commandes.libelleDeplacerApres) { commandes.deplacer(identifiant, rang + 1) }
                .disabled(rang >= nombreDeCategories - 1)

            Divider()

            Button(commandes.libelleSupprimer, role: .destructive) {
                commandes.supprimer(identifiant)
            }
        }
    }

    /// Rang d une categorie parmi les seules categories enregistrees.
    ///
    /// Tout occupe la premiere place de la barre sans occuper de rang en base.
    /// Le rang passe aux commandes est donc celui de la table, pas celui de
    /// l affichage.
    private func rangDeLaCategorie(_ selection: SelectionDeCategorie) -> Int {
        onglets
            .filter(\.estModifiable)
            .firstIndex { $0.selection == selection } ?? 0
    }

    private var nombreDeCategories: Int {
        onglets.count { $0.estModifiable }
    }
}

/// Un onglet de la barre de categories.
private struct OngletDeCategorieVue: View {
    @Environment(\.palette) private var palette
    @State private var survole = false

    let onglet: OngletDeCategorie
    let estActif: Bool
    let estFocalise: Bool
    let animationsReduites: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            contenu
                .padding(.horizontal, Jetons.BarreDeCategories.remplissageHorizontal)
                .frame(height: Jetons.BarreDeCategories.hauteur)
                .background(fond)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .overlay(contourDeFocus)
        .onHover { survole = $0 }
        .animation(animation, value: survole)
        .help(onglet.libelle)
        .accessibilityLabel(onglet.libelle)
        .accessibilityValue(Text(compteur))
        .accessibilityAddTraits(estActif ? [.isButton, .isSelected] : .isButton)
    }

    /// Libelle et compteur, separes de 7 comme l impose la section 5.1.
    private var contenu: some View {
        HStack(spacing: Jetons.BarreDeCategories.ecartDuCompteur) {
            Text(onglet.libelle)
                .style(Jetons.BarreDeCategories.libelle)
                .foregroundStyle(couleurDeLibelle)

            // Chiffres tabulaires : le compteur change en place quand une serie
            // entre ou sort de la categorie, section 1.5.
            Text(compteur)
                .style(Jetons.BarreDeCategories.libelle, chiffresTabulaires: true)
                .foregroundStyle(palette.textes.tertiary.couleur)
        }
        .lineLimit(1)
    }

    private var compteur: String {
        onglet.compteur.formatted()
    }

    private var fond: some View {
        RoundedRectangle(
            cornerRadius: Jetons.BarreDeCategories.rayonDeLOngletActif,
            style: .continuous
        )
        .fill(couleurDeFond)
    }

    @ViewBuilder
    private var contourDeFocus: some View {
        if estFocalise {
            RoundedRectangle(
                cornerRadius: Jetons.BarreDeCategories.rayonDeLOngletActif + Jetons.Focus.decalage,
                style: .continuous
            )
            .strokeBorder(palette.semantiques.focusRing.couleur, lineWidth: Jetons.Focus.epaisseur)
            .padding(-Jetons.Focus.decalage)
        }
    }

    private var couleurDeFond: Color {
        if estActif {
            palette.surfaces.menu.couleur
        } else if survole {
            palette.surfaces.card.couleur
        } else {
            .clear
        }
    }

    private var couleurDeLibelle: Color {
        estActif ? palette.textes.primary.couleur : palette.textes.secondary.couleur
    }

    private var animation: Animation? {
        animationsReduites ? nil : Jetons.Mouvement.survol.animation
    }
}
