import Core
import SwiftUI

//
// Carte de section, section 4.2 de DESIGN-SPEC.md.
//
// Une ou plusieurs lignes empilees dans un conteneur de rayon 12. Le separateur
// est encastre de 20 a gauche et affleure a droite, et il n y en a jamais un
// apres la derniere ligne.
//

/// Composition des textes chiffres d un reglage.
public enum TexteDeReglage {
    /// Valeur numerique posee a droite d une ligne a curseur.
    ///
    /// Les curseurs du produit vont tous de 0 a 100. La valeur s affiche donc
    /// en entier, sans decimale qui n apporterait rien.
    public static func valeurDuCurseur(_ valeur: Double) -> String {
        String(Int(valeur.rounded()))
    }
}

/// Une section de l ecran Reglages : en tete, carte, description.
public struct VueDeCarteDeSection: View {
    @Environment(\.palette) private var palette

    private let section: SectionDeReglages
    private let presentation: PresentationDeReglages
    private let libelles: LibellesDeReglages
    private let commandes: CommandesDeReglages

    /// Construit la section.
    public init(
        section: SectionDeReglages,
        presentation: PresentationDeReglages,
        libelles: LibellesDeReglages,
        commandes: CommandesDeReglages
    ) {
        self.section = section
        self.presentation = presentation
        self.libelles = libelles
        self.commandes = commandes
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            enTete
            carte
            description
        }
    }

    private var enTete: some View {
        Text(libelles.titre(de: section))
            .style(Jetons.CarteDeReglages.enTete)
            .foregroundStyle(palette.textes.primary.couleur)
            .padding(.bottom, Jetons.CarteDeReglages.ecartApresLEnTete)
            .accessibilityAddTraits(.isHeader)
    }

    private var carte: some View {
        VStack(spacing: 0) {
            ForEach(Array(section.lignes.enumerated()), id: \.element.id) { rang, ligne in
                VueDeLigneDeReglage(
                    ligne: ligne,
                    presentation: presentation,
                    libelles: libelles,
                    commandes: commandes
                )

                if rang < section.lignes.count - 1 {
                    separateur
                }
            }
        }
        .background(palette.surfaces.card.couleur)
        .clipShape(RoundedRectangle(cornerRadius: Jetons.CarteDeReglages.rayon, style: .continuous))
    }

    /// Filet de 1 px encastre de 20 a gauche, affleurant a droite.
    private var separateur: some View {
        Rectangle()
            .fill(palette.semantiques.separator.couleur)
            .frame(height: Jetons.CarteDeReglages.epaisseurDuSeparateur)
            .padding(.leading, Jetons.CarteDeReglages.encastrementDuSeparateur)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var description: some View {
        if let texte = libelles.description(de: section) {
            Text(texte)
                .style(Jetons.CarteDeReglages.description)
                .foregroundStyle(palette.textes.tertiary.couleur)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Jetons.CarteDeReglages.ecartAvantLaDescription)
        }
    }
}

/// Squelette d une section pendant le chargement, section 5.5.
///
/// Les en tetes restent lisibles, seules les lignes deviennent des squelettes
/// aux hauteurs reelles du contenu attendu.
struct SqueletteDeSection: View {
    @Environment(\.palette) private var palette

    let section: SectionDeReglages
    let libelles: LibellesDeReglages

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(libelles.titre(de: section))
                .style(Jetons.CarteDeReglages.enTete)
                .foregroundStyle(palette.textes.primary.couleur)
                .padding(.bottom, Jetons.CarteDeReglages.ecartApresLEnTete)
                .accessibilityAddTraits(.isHeader)

            VueDeSquelette()
                .frame(height: hauteurDesLignes)
        }
    }

    /// Hauteur cumulee des lignes de la section, curseurs compris.
    private var hauteurDesLignes: Double {
        section.lignes.reduce(0) { total, ligne in
            total + (
                ligne.variante == .curseur
                    ? Jetons.LigneDeReglage.hauteurAvecDescription
                    : Jetons.LigneDeReglage.hauteur
            )
        }
    }
}
