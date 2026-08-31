import SwiftUI

//
// Etats de contenu, section 4.10 de DESIGN-SPEC.md.
//
// Un ecran sans ses etats n est pas fini. L etat vide invite a agir, l etat
// d erreur nomme sa cause et donne une sortie, l etat de chargement montre des
// squelettes aux dimensions du contenu attendu, jamais une roue seule.
//

/// Une action proposee par un etat de contenu.
public struct ActionDEtat: Identifiable {
    /// Libelle du bouton, pris dans le catalogue de chaines.
    public let libelle: String
    /// Travail declenche par le bouton.
    public let action: () -> Void

    public init(libelle: String, action: @escaping () -> Void) {
        self.libelle = libelle
        self.action = action
    }

    public var id: String {
        libelle
    }
}

/// L un des trois etats d un ecran sans contenu affichable.
public enum EtatDeContenu {
    /// Rien a montrer, mais quelque chose a faire.
    ///
    /// - Parameters:
    ///   - symbole: glyphe de 52, en `text.emptyGlyph`.
    ///   - titre: titre en `title1`.
    ///   - phrase: phrase qui dit quoi faire.
    ///   - action: action facultative, en bouton principal.
    case vide(symbole: String, titre: String, phrase: String, action: ActionDEtat?)

    /// Contenu en cours de lecture.
    case chargement

    /// Echec nomme, avec sa sortie.
    ///
    /// Le bouton Reessayer est secondaire, jamais principal.
    case erreur(titre: String, phrase: String, reessayer: ActionDEtat, repli: ActionDEtat?)
}

/// Bloc centre qui rend l un des trois etats de contenu.
public struct VueDEtatDeContenu: View {
    @Environment(\.palette) private var palette

    private let etat: EtatDeContenu

    public init(_ etat: EtatDeContenu) {
        self.etat = etat
    }

    public var body: some View {
        contenu
            .frame(maxWidth: Jetons.EtatDeContenu.largeurMaximale)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(Jetons.Contenu.margeLaterale)
    }

    @ViewBuilder
    private var contenu: some View {
        switch etat {
        case let .vide(symbole, titre, phrase, action):
            bloc(
                symbole: symbole,
                couleurDuGlyphe: palette.textes.emptyGlyph.couleur,
                titre: titre,
                phrase: phrase
            ) {
                if let action {
                    Button(action.libelle, action: action.action)
                        .buttonStyle(
                            BoutonPrincipal(
                                hauteur: Jetons.Bouton.hauteurEnEtat,
                                rayon: Jetons.Bouton.rayonEnEtat
                            )
                        )
                        .frame(minWidth: Jetons.Bouton.largeurEnEtat)
                }
            }

        case .chargement:
            VueDeSquelette()

        case let .erreur(titre, phrase, reessayer, repli):
            bloc(
                symbole: Jetons.Icone.erreurDeContenu,
                couleurDuGlyphe: palette.semantiques.warning.couleur,
                titre: titre,
                phrase: phrase
            ) {
                HStack(spacing: Jetons.Espace.x3) {
                    if let repli {
                        Button(repli.libelle, action: repli.action)
                            .buttonStyle(boutonSecondaire)
                    }
                    Button(reessayer.libelle, action: reessayer.action)
                        .buttonStyle(boutonSecondaire)
                }
            }
        }
    }

    private var boutonSecondaire: BoutonSecondaire {
        BoutonSecondaire(
            hauteur: Jetons.Bouton.hauteurEnEtat,
            rayon: Jetons.Bouton.rayonEnEtat
        )
    }

    private func bloc(
        symbole: String,
        couleurDuGlyphe: Color,
        titre: String,
        phrase: String,
        @ViewBuilder action: () -> some View
    ) -> some View {
        VStack(spacing: 0) {
            // Le glyphe illustre le titre pose sous lui, il n ajoute aucune
            // information. Masque a VoiceOver, qui lit le titre et la phrase.
            Image(systemName: symbole)
                .font(
                    .system(
                        size: Jetons.EtatDeContenu.tailleDuGlyphe,
                        weight: .light
                    )
                )
                .foregroundStyle(couleurDuGlyphe)
                .padding(.bottom, Jetons.EtatDeContenu.ecartApresLeGlyphe)
                .accessibilityHidden(true)

            Text(titre)
                .style(Jetons.Typo.title1)
                .foregroundStyle(palette.textes.primary.couleur)
                .padding(.bottom, Jetons.EtatDeContenu.ecartApresLeTitre)

            Text(phrase)
                .style(Jetons.Typo.callout)
                .foregroundStyle(palette.textes.tertiary.couleur)

            action()
                .padding(.top, Jetons.EtatDeContenu.ecartAvantLAction)
        }
        .multilineTextAlignment(.center)
    }
}

/// Squelette de chargement, fond `surface.card`, pulsation d opacite.
///
/// Les dimensions exactes du contenu attendu sont donnees par l ecran qui
/// l emploie. Sans dimension, le squelette occupe la place disponible.
public struct VueDeSquelette: View {
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var animationsReduites
    @State private var pulse = false

    public init() {}

    public var body: some View {
        RoundedRectangle(cornerRadius: Jetons.Rayon.carte, style: .continuous)
            .fill(palette.surfaces.card.couleur)
            .opacity(opacite)
            .animation(animation, value: pulse)
            .onAppear { pulse = true }
            .accessibilityHidden(true)
    }

    private var opacite: Double {
        guard !animationsReduites else { return Jetons.Mouvement.opaciteHauteDeSquelette }
        return pulse
            ? Jetons.Mouvement.opaciteHauteDeSquelette
            : Jetons.Mouvement.opaciteBasseDeSquelette
    }

    private var animation: Animation? {
        animationsReduites ? nil : Jetons.Mouvement.pulsationDeSquelette.animation
    }
}
