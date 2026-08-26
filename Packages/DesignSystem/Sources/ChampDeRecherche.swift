import SwiftUI

//
// Champ de recherche de la barre d outils, sections 5.4 et 4.9 de
// DESIGN-SPEC.md.
//
// La section 5.4 donne la largeur, 440, et l espace reserve. La section 4.9
// donne les etats du champ de saisie : fond `surface.field`, contour de 1 en
// `border` au repos, contour de 2 en `accent` quand il a le focus, espace
// reserve en `text.quaternary`, texte saisi en `text.primary`.
//
// Le contour de 2 en accent de l etat actif tient lieu de contour de focus
// clavier de la section 7. Poser en plus l anneau decale de 2 doublerait le
// meme signal autour du meme element.
//

/// Champ de recherche pose dans la barre d outils.
public struct ChampDeRecherche: View {
    @Environment(\.palette) private var palette
    @FocusState private var focalise: Bool

    @Binding private var texte: String

    private let espaceReserve: String
    private let etiquette: String
    private let libelleDEffacement: String

    /// Construit le champ.
    ///
    /// - Parameters:
    ///   - texte: terme cherche, pilote par l ecran.
    ///   - espaceReserve: texte affiche quand le champ est vide, tableau 6.2.
    ///   - etiquette: etiquette d accessibilite, le champ n a pas de libelle.
    ///   - libelleDEffacement: etiquette du bouton qui vide le champ.
    public init(
        texte: Binding<String>,
        espaceReserve: String,
        etiquette: String,
        libelleDEffacement: String
    ) {
        _texte = texte
        self.espaceReserve = espaceReserve
        self.etiquette = etiquette
        self.libelleDEffacement = libelleDEffacement
    }

    public var body: some View {
        HStack(spacing: Jetons.Recherche.ecartDansLeChamp) {
            loupe
            saisie

            if texte.isEmpty == false {
                boutonDEffacement
            }
        }
        .padding(.horizontal, Jetons.Recherche.remplissageDuChamp)
        .frame(
            width: Jetons.Recherche.largeurDuChamp,
            height: Jetons.Recherche.hauteurDuChamp
        )
        .background(fond)
        .contentShape(Rectangle())
        .onTapGesture { focalise = true }
    }

    private var loupe: some View {
        Image(systemName: Jetons.Icone.rechercher)
            .font(policeDesSymboles)
            .foregroundStyle(palette.textes.tertiary.couleur)
            .accessibilityHidden(true)
    }

    private var saisie: some View {
        TextField(
            text: $texte,
            prompt: Text(espaceReserve).foregroundStyle(palette.textes.quaternary.couleur)
        ) {
            Text(etiquette)
        }
        .textFieldStyle(.plain)
        .style(Jetons.Typo.body)
        .foregroundStyle(palette.textes.primary.couleur)
        .focused($focalise)
        .focusEffectDisabled()
        .labelsHidden()
        .accessibilityLabel(etiquette)
    }

    private var boutonDEffacement: some View {
        Button {
            texte = ""
            focalise = true
        } label: {
            Image(systemName: Jetons.IconeDeRecherche.effacerLeChamp)
                .font(policeDesSymboles)
                .foregroundStyle(palette.textes.tertiary.couleur)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(libelleDEffacement)
    }

    /// La taille de rendu d un symbole est une geometrie de composant, pas un
    /// role de l echelle typographique, section 1.10.
    private var policeDesSymboles: Font {
        .system(size: Jetons.Recherche.tailleDesSymbolesDuChamp)
    }

    private var fond: some View {
        RoundedRectangle(cornerRadius: Jetons.Recherche.rayonDuChamp, style: .continuous)
            .fill(palette.surfaces.field.couleur)
            .overlay {
                RoundedRectangle(cornerRadius: Jetons.Recherche.rayonDuChamp, style: .continuous)
                    .strokeBorder(couleurDuContour, lineWidth: epaisseurDuContour)
            }
    }

    private var couleurDuContour: Color {
        focalise ? palette.semantiques.accent.couleur : palette.semantiques.border.couleur
    }

    private var epaisseurDuContour: Double {
        focalise ? Jetons.Focus.epaisseur : Jetons.Fenetre.epaisseurDuFilet
    }
}
