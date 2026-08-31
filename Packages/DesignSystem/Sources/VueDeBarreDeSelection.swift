import Core
import Foundation
import SwiftUI

//
// Barre d actions de selection multiple, section 4.5 de DESIGN-SPEC.md.
//
// Hauteur 52, rayon 12, fond `surface.menu`, elevation 1, ancree en bas de la
// zone de liste. Compteur `N selectionnes` a gauche, puis Marquer lu,
// Telecharger, Supprimer, cette derniere en `danger`.
//
// La barre n existe pas tant que la selection est vide. Ce n est pas une
// decision de mise en page : c est la definition meme de la selection multiple,
// portee par `SelectionDeChapitres.barreEstOuverte`.
//

/// Libelles de la barre de selection, pris dans le catalogue de chaines.
public struct LibellesDeSelectionDeChapitres: Sendable, Equatable {
    /// Motif du compteur, `%lld selectionnes`.
    public let compteur: String

    /// Libelle de l action Marquer lu.
    public let marquerLu: String

    /// Libelle de l action Telecharger.
    public let telecharger: String

    /// Libelle de l action Supprimer.
    public let supprimer: String

    /// Libelle de la fermeture de la barre.
    public let fermer: String

    /// Commande de menu qui retient un chapitre, equivalent atteignable du clic
    /// maintenu decrit par la section 4.5.
    public let selectionner: String

    /// Commande de menu qui etend la selection depuis son ancre, equivalent
    /// atteignable du Maj clic.
    public let etendreLaSelection: String

    public init(
        compteur: String,
        marquerLu: String,
        telecharger: String,
        supprimer: String,
        fermer: String,
        selectionner: String,
        etendreLaSelection: String
    ) {
        self.compteur = compteur
        self.marquerLu = marquerLu
        self.telecharger = telecharger
        self.supprimer = supprimer
        self.fermer = fermer
        self.selectionner = selectionner
        self.etendreLaSelection = etendreLaSelection
    }

    /// Libelle d une action, dans l ordre du document.
    public func libelle(de action: ActionDeSelectionDeChapitres) -> String {
        switch action {
        case .marquerLu: marquerLu
        case .telecharger: telecharger
        case .supprimer: supprimer
        }
    }
}

/// Barre d actions ouverte par la selection multiple.
public struct VueDeBarreDeSelection: View {
    @Environment(\.palette) private var palette

    private let selection: SelectionDeChapitres
    private let libelles: LibellesDeSelectionDeChapitres
    private let executer: (ActionDeSelectionDeChapitres) -> Void
    private let fermer: () -> Void

    /// Construit la barre.
    ///
    /// - Parameters:
    ///   - selection: chapitres retenus. Une selection vide ne rend rien.
    ///   - libelles: libelles pris dans le catalogue de chaines.
    ///   - executer: lance l action demandee sur la selection.
    ///   - fermer: vide la selection et referme la barre.
    public init(
        selection: SelectionDeChapitres,
        libelles: LibellesDeSelectionDeChapitres,
        executer: @escaping (ActionDeSelectionDeChapitres) -> Void,
        fermer: @escaping () -> Void
    ) {
        self.selection = selection
        self.libelles = libelles
        self.executer = executer
        self.fermer = fermer
    }

    public var body: some View {
        if selection.barreEstOuverte {
            barre
        }
    }

    private var barre: some View {
        HStack(spacing: Jetons.BarreDeSelection.ecartEntreActions) {
            // Chiffres tabulaires : le compteur change en place a chaque clic,
            // section 1.5.
            Text(String(format: libelles.compteur, selection.nombre))
                .style(Jetons.BarreDeSelection.compteur, chiffresTabulaires: true)
                .foregroundStyle(palette.textes.primary.couleur)

            Spacer(minLength: 0)

            ForEach(selection.actionsDisponibles, id: \.self) { action in
                Button(libelles.libelle(de: action)) { executer(action) }
                    .buttonStyle(.plain)
                    .style(Jetons.FicheDeSerie.actionDeListe)
                    .foregroundStyle(couleur(de: action))
            }

            Button(libelles.fermer, action: fermer)
                .buttonStyle(.plain)
                .style(Jetons.FicheDeSerie.actionDeListe)
                .foregroundStyle(palette.lisible(palette.textes.tertiary, sur: [fondDeLaBarre]).couleur)
        }
        .padding(.horizontal, Jetons.BarreDeSelection.margeLaterale)
        .frame(height: Jetons.BarreDeSelection.hauteur)
        .frame(maxWidth: .infinity)
        .background(fond)
        .elevation(
            Jetons.BarreDeSelection.elevation,
            rayon: Jetons.BarreDeSelection.rayon,
            palette: palette
        )
        .accessibilityElement(children: .contain)
    }

    private var fond: some View {
        RoundedRectangle(cornerRadius: Jetons.BarreDeSelection.rayon, style: .continuous)
            .fill(fondDeLaBarre.couleur)
    }

    /// La barre repose sur `surface.menu`, tableau 4.5.
    private var fondDeLaBarre: CouleurHexadecimale {
        palette.surfaces.menu
    }

    /// Supprimer est la seule action en `danger`, tableau 4.5.
    ///
    /// Sur `surface.menu`, `danger` mesure 4.1:1 et `accent.text` 3.8:1 en
    /// variante sombre, tous deux sous le seuil de la section 7. Les deux sont
    /// derives, voir `Lisibilite`.
    private func couleur(de action: ActionDeSelectionDeChapitres) -> Color {
        let jeton = action.estDestructive
            ? palette.semantiques.danger
            : palette.semantiques.accentText

        return palette.lisible(jeton, sur: [fondDeLaBarre]).couleur
    }
}
