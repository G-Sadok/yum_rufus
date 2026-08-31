import Core
import SwiftUI

//
// Ligne de chapitre, section 4.5 de DESIGN-SPEC.md.
//
// Structure a deux lignes, toujours. La sous ligne n est jamais vide, elle est
// composee par TexteDeChapitre et porte l information que la marque de droite
// ne peut pas porter seule : aucune information du produit ne passe par la
// couleur ou par une forme seule, regle de la section 7.
//

/// Une ligne de la liste des chapitres.
public struct VueDeLigneDeChapitre: View {
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var animationsReduites
    @State private var survolee = false

    private let chapitre: ChapitreDeFiche
    private let libelles: LibellesDeChapitre
    private let estSelectionnee: Bool
    private let estFocalisee: Bool
    private let ouvrir: () -> Void

    /// Construit la ligne.
    ///
    /// - Parameters:
    ///   - chapitre: chapitre affiche, etat de telechargement compris.
    ///   - libelles: motifs pris dans le catalogue de chaines.
    ///   - estSelectionnee: vrai quand la selection multiple retient la ligne.
    ///   - estFocalisee: vrai quand le focus clavier est sur la ligne.
    ///   - ouvrir: ouvre le chapitre dans le lecteur.
    public init(
        chapitre: ChapitreDeFiche,
        libelles: LibellesDeChapitre,
        estSelectionnee: Bool = false,
        estFocalisee: Bool = false,
        ouvrir: @escaping () -> Void
    ) {
        self.chapitre = chapitre
        self.libelles = libelles
        self.estSelectionnee = estSelectionnee
        self.estFocalisee = estFocalisee
        self.ouvrir = ouvrir
    }

    /// Presentation dictee par le tableau 4.5.
    private var presentation: PresentationDeLigneDeChapitre {
        PresentationDeLigneDeChapitre(chapitre.etat)
    }

    public var body: some View {
        Button(action: ouvrir) {
            contenu
                .padding(.horizontal, Jetons.LigneDeChapitre.margeLaterale)
                .frame(height: Jetons.LigneDeChapitre.hauteur)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(fond)
                .overlay(alignment: .bottom) { filetDeProgression }
                .overlay(contourDeSelection)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .contourDeFocus(estFocalisee, rayonDeLElement: Jetons.LigneDeChapitre.rayon)
        .onHover { survolee = $0 }
        .animation(animation, value: survolee)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(estSelectionnee ? [.isButton, .isSelected] : .isButton)
    }

    private var contenu: some View {
        HStack(spacing: Jetons.LigneDeChapitre.ecartEntreMarques) {
            VStack(alignment: .leading, spacing: 0) {
                Text(TexteDeChapitre.titre(de: chapitre, libelles: libelles))
                    .style(presentation.styleDuTitre)
                    .foregroundStyle(presentation.couleurDuTitre.couleur(dans: palette).couleur)

                // Chiffres tabulaires : la page atteinte et le nombre de pages
                // changent en place, section 1.5.
                Text(TexteDeChapitre.sousLigne(de: chapitre, libelles: libelles))
                    .style(Jetons.LigneDeChapitre.sousLigne, chiffresTabulaires: true)
                    .foregroundStyle(presentation.couleurDeLaSousLigne.couleur(dans: palette).couleur)
            }
            .lineLimit(1)

            Spacer(minLength: 0)

            marques
        }
    }

    private var marques: some View {
        HStack(spacing: Jetons.LigneDeChapitre.ecartEntreMarques) {
            if presentation.porteLIconeDeTelechargement {
                Image(systemName: Jetons.Icone.telechargement)
                    .font(policeDeLIconeDeTelechargement)
                    .foregroundStyle(palette.semantiques.accent.couleur)
                    .accessibilityLabel(libelles.etiquetteDeTelechargement)
            }

            if presentation.marque == .pastille {
                Circle()
                    .fill(palette.semantiques.accent.couleur)
                    .frame(
                        width: Jetons.LigneDeChapitre.diametreDeLaPastille,
                        height: Jetons.LigneDeChapitre.diametreDeLaPastille
                    )
                    .accessibilityHidden(true)
            }
        }
    }

    /// L icone de telechargement est la seule valeur de police posee hors de
    /// l echelle typographique : le tableau 4.5 chiffre une taille de rendu de
    /// symbole, pas un role de texte.
    private var policeDeLIconeDeTelechargement: Font {
        .system(size: Jetons.LigneDeChapitre.tailleDeLIconeDeTelechargement)
    }

    @ViewBuilder
    private var filetDeProgression: some View {
        if presentation.marque == .filetDeProgression {
            GeometryReader { geometrie in
                Rectangle()
                    .fill(palette.semantiques.accent.couleur)
                    .opacity(Jetons.LigneDeChapitre.opaciteDuFilet)
                    .frame(
                        width: geometrie.size.width * TexteDeChapitre.progression(de: chapitre),
                        height: Jetons.LigneDeChapitre.epaisseurDuFilet
                    )
            }
            .frame(height: Jetons.LigneDeChapitre.epaisseurDuFilet)
            .accessibilityHidden(true)
        }
    }

    private var fond: some View {
        RoundedRectangle(cornerRadius: Jetons.LigneDeChapitre.rayon, style: .continuous)
            .fill(couleurDeFond)
    }

    /// Fond du tableau 4.5, augmente du seul etat de survol.
    ///
    /// Un chapitre lu est transparent au repos et prend `surface.cardHover` au
    /// survol, comme la derniere ligne du tableau l impose sans distinguer les
    /// etats de lecture.
    private var couleurDeFond: Color {
        if survolee {
            return palette.surfaces.cardHover.couleur
        }

        return switch presentation.fond {
        case .carte: palette.surfaces.card.couleur
        case .transparent: .clear
        }
    }

    @ViewBuilder
    private var contourDeSelection: some View {
        if estSelectionnee {
            RoundedRectangle(cornerRadius: Jetons.LigneDeChapitre.rayon, style: .continuous)
                .strokeBorder(
                    palette.semantiques.accent.couleur,
                    lineWidth: Jetons.LigneDeChapitre.epaisseurDuContourDeSelection
                )
        }
    }

    private var animation: Animation? {
        animationsReduites ? nil : Jetons.Mouvement.survol.animation
    }
}
