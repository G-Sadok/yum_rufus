import Core
import SwiftUI

//
// Ecran Reglages, section 5.5 de DESIGN-SPEC.md.
//
// Colonne de 580 centree, dix sept sections dans l ordre exact du catalogue,
// 32 entre deux sections. La colonne ne s etire jamais : la contrainte de la
// section 2.3 est stricte, et une carte de reglages large de mille pixels
// rendrait ses lignes illisibles.
//
// L ecran n a pas d etat vide. Sur une installation neuve la colonne est
// complete, et seules les valeurs disent l absence.
//

/// Colonne de reglages complete.
public struct VueDeReglages: View {
    @Environment(\.palette) private var palette

    private let etat: EtatDeReglages
    private let banniere: BanniereDErreurDeReglages?
    private let libelles: LibellesDeReglages
    private let commandes: CommandesDeReglages

    /// Construit l ecran.
    ///
    /// - Parameters:
    ///   - etat: chargement ou valeurs reelles.
    ///   - banniere: erreur posee en haut de colonne, nulle le reste du temps.
    ///   - libelles: textes pris dans le catalogue de chaines.
    ///   - commandes: ce que les lignes declenchent.
    public init(
        etat: EtatDeReglages,
        banniere: BanniereDErreurDeReglages? = nil,
        libelles: LibellesDeReglages,
        commandes: CommandesDeReglages
    ) {
        self.etat = etat
        self.banniere = banniere
        self.libelles = libelles
        self.commandes = commandes
    }

    public var body: some View {
        ScrollView {
            colonne
                .frame(maxWidth: Jetons.CarteDeReglages.largeurDeColonne)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Jetons.Contenu.margeLaterale)
                .padding(.vertical, Jetons.CarteDeReglages.margeVerticale)
        }
        .background(palette.surfaces.canvas.couleur)
    }

    private var colonne: some View {
        VStack(alignment: .leading, spacing: Jetons.CarteDeReglages.espaceEntreSections) {
            if let banniere {
                VueDeBanniereDeReglages(banniere: banniere)
            }

            sections

            note
        }
    }

    private var sections: some View {
        ForEach(SectionDeReglages.allCases, id: \.self) { section in
            switch etat {
            case .chargement:
                SqueletteDeSection(section: section, libelles: libelles)

            case let .chargee(presentation):
                VueDeCarteDeSection(
                    section: section,
                    presentation: presentation,
                    libelles: libelles,
                    commandes: commandes
                )
            }
        }
    }

    /// Note de provenance qui ferme la section A propos, tableau 6.8.
    ///
    /// Elle est alignee a gauche, sous la carte, et n appartient a aucune ligne.
    private var note: some View {
        Text(libelles.noteDeFin)
            .style(Jetons.CarteDeReglages.note)
            .foregroundStyle(palette.textes.quaternary.couleur)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Banniere d erreur posee en haut de la colonne, section 5.5.
struct VueDeBanniereDeReglages: View {
    @Environment(\.palette) private var palette

    let banniere: BanniereDErreurDeReglages

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(banniere.titre)
                .style(Jetons.BanniereDeReglages.titre)
                .foregroundStyle(palette.textes.primary.couleur)
                .padding(.bottom, Jetons.BanniereDeReglages.ecartApresLeTitre)

            Text(banniere.phrase)
                .style(Jetons.BanniereDeReglages.phrase)
                .foregroundStyle(palette.textes.tertiary.couleur)
                .fixedSize(horizontal: false, vertical: true)

            boutons
                .padding(.top, Jetons.BanniereDeReglages.ecartAvantLesBoutons)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Jetons.BanniereDeReglages.remplissage)
        .background(
            RoundedRectangle(cornerRadius: Jetons.BanniereDeReglages.rayon, style: .continuous)
                .fill(palette.surfaces.card.couleur)
        )
        .overlay(contour)
    }

    private var boutons: some View {
        HStack(spacing: Jetons.BanniereDeReglages.ecartEntreLesBoutons) {
            Button(banniere.reessayer.libelle, action: banniere.reessayer.action)
                .buttonStyle(style)

            Button(
                banniere.ouvrirLesReglagesDuSysteme.libelle,
                action: banniere.ouvrirLesReglagesDuSysteme.action
            )
            .buttonStyle(style)
        }
    }

    private var style: BoutonSecondaire {
        BoutonSecondaire(
            hauteur: Jetons.Bouton.hauteurEnEtat,
            rayon: Jetons.Bouton.rayonEnEtat
        )
    }

    private var contour: some View {
        RoundedRectangle(cornerRadius: Jetons.BanniereDeReglages.rayon, style: .continuous)
            .strokeBorder(
                palette.semantiques.warning.couleur,
                lineWidth: Jetons.BanniereDeReglages.epaisseurDuContour
            )
    }
}
