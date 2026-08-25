import Core
import SwiftUI

//
// Entree de l historique, section 5.2 de DESIGN-SPEC.md.
//
// Hauteur 80, vignette 44 par 66 rayon 6, titre de serie en `body` graisse 600,
// chapitre en `footnote` `text.tertiary`, heure en `footnote` `text.quaternary`
// et chiffres tabulaires, bouton de suppression de 26 au survol.
//
// L heure emploie `text.quaternary`, que la section 7 reserve au texte
// redondant. Elle l est : l etiquette d accessibilite de la ligne porte deja la
// serie, le chapitre et l heure, et le jour est ecrit dans l en tete au dessus.
//

/// Une entree de la liste de l historique.
public struct VueDeLigneDHistorique<Vignette: View>: View {
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var animationsReduites
    @State private var survolee = false

    private let entree: EntreeDHistorique
    private let libelles: LibellesDHistorique
    private let ouvrir: (() -> Void)?
    private let supprimer: () -> Void
    private let vignette: () -> Vignette

    /// Construit l entree.
    ///
    /// - Parameters:
    ///   - entree: lecture consignee.
    ///   - libelles: libelles pris dans le catalogue de chaines.
    ///   - ouvrir: rouvre le chapitre dans le lecteur. Nul tant qu aucun
    ///     lecteur ne peut l accueillir, auquel cas la ligne n est pas un
    ///     bouton et ne promet rien.
    ///   - supprimer: retire cette entree de l historique.
    ///   - vignette: couverture de la serie, fournie par l appelant.
    public init(
        entree: EntreeDHistorique,
        libelles: LibellesDHistorique,
        ouvrir: (() -> Void)?,
        supprimer: @escaping () -> Void,
        @ViewBuilder vignette: @escaping () -> Vignette
    ) {
        self.entree = entree
        self.libelles = libelles
        self.ouvrir = ouvrir
        self.supprimer = supprimer
        self.vignette = vignette
    }

    public var body: some View {
        ligne
            .onHover { survolee = $0 }
            .animation(animation, value: survolee)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(etiquette)
    }

    @ViewBuilder
    private var ligne: some View {
        if let ouvrir {
            Button(action: ouvrir) { cadre }
                .buttonStyle(.plain)
                .accessibilityAddTraits(.isButton)
        } else {
            cadre
        }
    }

    private var cadre: some View {
        contenu
            .padding(.horizontal, Jetons.Historique.margeLaterale)
            .frame(height: Jetons.Historique.hauteurDEntree)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fond)
            .contentShape(Rectangle())
    }

    private var contenu: some View {
        HStack(spacing: Jetons.Historique.ecartApresLaVignette) {
            couverture

            VStack(alignment: .leading, spacing: 0) {
                Text(entree.titreDeLaSerie)
                    .style(Jetons.Historique.titreDeSerie)
                    .foregroundStyle(palette.textes.primary.couleur)

                Text(TexteDHistorique.chapitre(de: entree, libelles: libelles))
                    .style(Jetons.Historique.chapitre)
                    .foregroundStyle(palette.textes.tertiary.couleur)
            }
            .lineLimit(1)

            Spacer(minLength: Jetons.Historique.ecartApresLaVignette)

            heure
            boutonDeSuppression
        }
    }

    private var couverture: some View {
        vignette()
            .frame(
                width: Jetons.Historique.largeurDeVignette,
                height: Jetons.Historique.hauteurDeVignette
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: Jetons.Historique.rayonDeVignette,
                    style: .continuous
                )
            )
            .accessibilityHidden(true)
    }

    /// Chiffres tabulaires : l heure change d une ligne a l autre, section 1.5.
    private var heure: some View {
        Text(TexteDHistorique.heure(de: entree))
            .style(Jetons.Historique.heure, chiffresTabulaires: true)
            .foregroundStyle(palette.textes.quaternary.couleur)
            .accessibilityHidden(true)
    }

    /// Bouton de suppression, visible au survol et atteignable au clavier.
    ///
    /// La section 5.2 le fait apparaitre au survol. Le retirer de l arbre hors
    /// survol le rendrait inatteignable au clavier et invisible de VoiceOver :
    /// il reste donc en place, et c est son opacite qui change.
    private var boutonDeSuppression: some View {
        Button(action: supprimer) {
            Image(systemName: Jetons.IconeDHistorique.supprimer)
                .font(policeDuSymbole)
                .foregroundStyle(palette.textes.tertiary.couleur)
                .frame(
                    width: Jetons.Historique.coteDuBoutonDeSuppression,
                    height: Jetons.Historique.coteDuBoutonDeSuppression
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(survolee ? 1 : 0)
        .accessibilityLabel(libelles.supprimerLEntree)
    }

    /// La taille de rendu d un symbole est une geometrie de composant, pas un
    /// role de l echelle typographique, section 1.10.
    private var policeDuSymbole: Font {
        .system(size: Jetons.Historique.tailleDuSymboleDeSuppression)
    }

    private var fond: some View {
        RoundedRectangle(cornerRadius: Jetons.Historique.rayonDEntree, style: .continuous)
            .fill(survolee ? palette.surfaces.cardHover.couleur : palette.surfaces.card.couleur)
    }

    /// Etiquette lue par VoiceOver, qui porte les trois informations de la
    /// ligne, heure comprise.
    private var etiquette: String {
        TexteDeChapitre.joindre([
            entree.titreDeLaSerie,
            TexteDHistorique.chapitre(de: entree, libelles: libelles),
            TexteDHistorique.heure(de: entree),
        ])
    }

    private var animation: Animation? {
        animationsReduites ? nil : Jetons.Mouvement.survol.animation
    }
}
