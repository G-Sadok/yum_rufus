import Core
import SwiftUI

//
// Bloc affiche a la place d une page illisible, sections 4.10 et 5.7.
//
// La section 5.7 veut un etat d erreur dans le lecteur, la section 4.10 en fixe
// la forme : glyphe de 52 en `warning`, titre qui nomme la cause reelle, phrase
// qui indique la sortie. Les deux actions sont secondaires, comme le Reessayer
// de l etat d erreur ordinaire, parce qu aucune ne doit attirer le pouce plus
// que la lecture elle meme.
//
// Le bloc est pose sur le fond du lecteur par l ecran qui l emploie. Il n en
// peint aucun : une page de remplacement occupe la place d une page, et les
// quatre fonds de lecteur de la section 1.4 restent ceux du lecteur.
//

/// Page de remplacement affichee a la place d une page que Yum n a pas su lire.
public struct VueDePageDeRemplacement: View {
    @Environment(\.palette) private var palette

    private let page: PageDeRemplacement
    private let libelles: LibellesDePageDeRemplacement
    private let sauter: () -> Void
    private let signaler: () -> Void

    public init(
        page: PageDeRemplacement,
        libelles: LibellesDePageDeRemplacement,
        sauter: @escaping () -> Void,
        signaler: @escaping () -> Void
    ) {
        self.page = page
        self.libelles = libelles
        self.sauter = sauter
        self.signaler = signaler
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Le glyphe illustre le titre pose sous lui. Masque a VoiceOver,
            // qui lit le titre puis la phrase.
            Image(systemName: Jetons.Icone.erreurDeContenu)
                .font(.system(size: Jetons.EtatDeContenu.tailleDuGlyphe, weight: .light))
                .foregroundStyle(palette.semantiques.warning.couleur)
                .padding(.bottom, Jetons.EtatDeContenu.ecartApresLeGlyphe)
                .accessibilityHidden(true)

            Text(TexteDePageDeRemplacement.titre(de: page, libelles: libelles))
                .style(Jetons.Typo.title1)
                .foregroundStyle(palette.textes.primary.couleur)
                .padding(.bottom, Jetons.EtatDeContenu.ecartApresLeTitre)

            Text(TexteDePageDeRemplacement.phrase(de: page, libelles: libelles))
                .style(Jetons.Typo.callout)
                .foregroundStyle(palette.textes.tertiary.couleur)

            actions
                .padding(.top, Jetons.EtatDeContenu.ecartAvantLAction)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: Jetons.EtatDeContenu.largeurMaximale)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Jetons.Contenu.margeLaterale)
    }

    private var actions: some View {
        HStack(spacing: Jetons.Espace.x3) {
            Button(libelles.sauterLaPage, action: sauter)
                .buttonStyle(styleDAction)

            Button(libelles.signalerLeFichier, action: signaler)
                .buttonStyle(styleDAction)
        }
    }

    private var styleDAction: BoutonSecondaire {
        BoutonSecondaire(
            hauteur: Jetons.Bouton.hauteurEnEtat,
            rayon: Jetons.Bouton.rayonEnEtat
        )
    }
}
