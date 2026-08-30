import Core
import SwiftUI

//
// Ligne de reglage, section 4.1 de DESIGN-SPEC.md.
//
// Composant le plus utilise du produit. Sa geometrie est entierement chiffree :
// 52 de haut, 76 avec un curseur, marge de 20, icone de 22, libelle a 58 du
// bord gauche.
//
// Au dela de la taille de texte dynamique `large`, la ligne passe en
// disposition verticale. Ce n est pas une adaptation cosmetique : a la taille
// accessibilite extra extra large, un libelle comme
// `Tourner avec les touches de volume` et son interrupteur ne tiennent pas cote
// a cote sur 580, et l un des deux disparaitrait.
//

/// Une ligne de la carte de section.
public struct VueDeLigneDeReglage: View {
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var tailleDeTexte
    @Environment(\.accessibilityReduceMotion) private var animationsReduites
    @State private var survolee = false
    @FocusState private var focalisee: Bool

    private let ligne: LigneDeReglage
    private let presentation: PresentationDeReglages
    private let libelles: LibellesDeReglages
    private let commandes: CommandesDeReglages

    /// Construit la ligne.
    ///
    /// - Parameters:
    ///   - ligne: ligne du catalogue, variante et bornes comprises.
    ///   - presentation: valeurs courantes et etat de l abonnement.
    ///   - libelles: textes pris dans le catalogue de chaines.
    ///   - commandes: ce que la ligne declenche.
    public init(
        ligne: LigneDeReglage,
        presentation: PresentationDeReglages,
        libelles: LibellesDeReglages,
        commandes: CommandesDeReglages
    ) {
        self.ligne = ligne
        self.presentation = presentation
        self.libelles = libelles
        self.commandes = commandes
    }

    public var body: some View {
        contenu
            .padding(.leading, Jetons.LigneDeReglage.margeLaterale)
            .padding(.trailing, Jetons.LigneDeReglage.margeLaterale)
            .frame(minHeight: hauteur)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fond)
            .overlay(contourDeFocus)
            .onHover { survolee = $0 }
            .animation(animation, value: survolee)
    }

    // MARK: Disposition

    @ViewBuilder
    private var contenu: some View {
        if enPile {
            VStack(alignment: .leading, spacing: Jetons.Espace.x2) {
                enTete
                controle
                    .padding(.leading, Jetons.LigneDeReglage.decalageDuControleEnPile)
            }
            .padding(.vertical, Jetons.Espace.x3)
        } else if ligne.variante == .curseur {
            VStack(alignment: .leading, spacing: Jetons.Espace.x2) {
                enTeteDuCurseur
                controle
                    .padding(.leading, Jetons.LigneDeReglage.decalageDuControleEnPile)
            }
            .padding(.vertical, Jetons.Espace.x3)
        } else {
            HStack(spacing: 0) {
                enTete
                Spacer(minLength: Jetons.Espace.x4)
                controle
            }
        }
    }

    private var enTete: some View {
        HStack(spacing: Jetons.LigneDeReglage.gouttiereApresLIcone) {
            icone
            libelle
        }
    }

    /// En tete d une ligne a curseur : le libelle et sa valeur numerique.
    private var enTeteDuCurseur: some View {
        HStack(spacing: Jetons.LigneDeReglage.gouttiereApresLIcone) {
            icone
            libelle

            Spacer(minLength: Jetons.Espace.x4)

            Text(TexteDeReglage.valeurDuCurseur(presentation.reglages.curseur(ligne.id)))
                .style(Jetons.LigneDeReglage.valeurDuCurseur, chiffresTabulaires: true)
                .foregroundStyle(palette.textes.secondary.couleur)
        }
    }

    private var icone: some View {
        Image(systemName: Jetons.IconeDeReglage.pour(ligne.id))
            .font(.system(size: Jetons.LigneDeReglage.tailleDIcone))
            .foregroundStyle(couleurDeLIcone)
            .frame(width: Jetons.LigneDeReglage.tailleDIcone)
            .accessibilityHidden(true)
    }

    private var libelle: some View {
        Text(libelles.libelle(de: ligne.id))
            .style(estPremium ? Jetons.LigneDeReglage.libellePremium : Jetons.LigneDeReglage.libelle)
            .foregroundStyle(couleurDuLibelle)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)
    }

    // MARK: Controles

    @ViewBuilder
    private var controle: some View {
        if let forme = presentation.formePremium(de: ligne), forme.remplaceLeControle {
            couronne
        } else {
            switch ligne.variante {
            case .interrupteur: interrupteur
            case .valeurEtMenu: valeur
            case .navigation: chevronDeNavigation
            case .curseur: curseur
            case .compteur: compteur
            }
        }
    }

    private var interrupteur: some View {
        Toggle(
            libelles.libelle(de: ligne.id),
            isOn: Binding(
                get: { presentation.reglages.booleen(ligne.id) },
                set: { commandes.basculer(ligne.id, $0) }
            )
        )
        .labelsHidden()
        .toggleStyle(StyleDInterrupteur())
        .focused($focalisee)
    }

    @ViewBuilder
    private var valeur: some View {
        if ligne.estEnLectureSeule {
            ValeurEnLectureSeule(texte: presentation.valeursAffichees[ligne.id] ?? "")
        } else {
            MenuDeReglage(
                ligne: ligne,
                valeurRetenue: valeurRetenue,
                libelles: libelles,
                choisir: { commandes.choisir(ligne.id, $0) }
            )
            .focused($focalisee)
        }
    }

    private var chevronDeNavigation: some View {
        Button {
            commandes.ouvrir(ligne.id)
        } label: {
            HStack(spacing: Jetons.LigneDeReglage.ecartAvantLeChevron) {
                if let texte = presentation.valeursAffichees[ligne.id] {
                    Text(texte)
                        .style(Jetons.LigneDeReglage.valeur)
                        .foregroundStyle(palette.textes.secondary.couleur)
                }

                Image(systemName: Jetons.IconeDeReglage.chevronDeNavigation)
                    .font(.system(size: Jetons.LigneDeReglage.tailleDuChevron))
                    .foregroundStyle(couleurDuChevron)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .focused($focalisee)
        .accessibilityLabel(libelles.libelle(de: ligne.id))
    }

    private var curseur: some View {
        Slider(
            value: Binding(
                get: { presentation.reglages.curseur(ligne.id) },
                set: { commandes.regler(ligne.id, $0) }
            ),
            in: intervalle,
            step: ligne.bornes?.pas ?? 1
        )
        .tint(palette.semantiques.accent.couleur)
        .focused($focalisee)
        .accessibilityLabel(libelles.libelle(de: ligne.id))
    }

    @ViewBuilder
    private var compteur: some View {
        if let bornes = ligne.bornes {
            CompteurDeReglage(
                valeur: presentation.reglages.compteur(ligne.id),
                texte: String(presentation.reglages.compteur(ligne.id)),
                bornes: bornes,
                etiquetteDAugmentation: libelles.augmenter,
                etiquetteDeDiminution: libelles.diminuer,
                changer: { commandes.compter(ligne.id, $0) }
            )
            .focused($focalisee)
            .accessibilityLabel(libelles.libelle(de: ligne.id))
        }
    }

    /// Couronne d une fonction verrouillee, a droite, a la place du controle.
    private var couronne: some View {
        Button {
            commandes.ouvrir(ligne.id)
        } label: {
            Image(systemName: Jetons.IconeDeReglage.couronne)
                .font(.system(size: Jetons.LigneDeReglage.tailleDeLaCouronne))
                .foregroundStyle(palette.semantiques.accent.couleur)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .focused($focalisee)
        .accessibilityLabel(libelles.etiquetteDeLaCouronne)
    }

    // MARK: Etats

    private var fond: some View {
        Rectangle().fill(couleurDeFond)
    }

    /// Fond du tableau d etats de la section 4.1.
    private var couleurDeFond: Color {
        if estPremium {
            return palette.surfaces.premium.couleur
        }

        return survolee ? palette.surfaces.cardHover.couleur : .clear
    }

    private var couleurDuLibelle: Color {
        estPremium ? palette.semantiques.accentText.couleur : palette.textes.primary.couleur
    }

    private var couleurDeLIcone: Color {
        palette.semantiques.accent.couleur
    }

    private var couleurDuChevron: Color {
        estPremium ? palette.semantiques.accent.couleur : palette.textes.tertiary.couleur
    }

    @ViewBuilder
    private var contourDeFocus: some View {
        if focalisee {
            RoundedRectangle(cornerRadius: Jetons.Focus.decalage, style: .continuous)
                .strokeBorder(palette.semantiques.focusRing.couleur, lineWidth: Jetons.Focus.epaisseur)
                .padding(-Jetons.Focus.decalage)
        }
    }

    // MARK: Mesures

    private var estPremium: Bool {
        presentation.formePremium(de: ligne) != nil
    }

    /// Vrai au dela de la taille de texte dynamique `large`, section 4.1.
    private var enPile: Bool {
        tailleDeTexte > .large && ligne.variante != .curseur
    }

    private var hauteur: Double {
        ligne.variante == .curseur
            ? Jetons.LigneDeReglage.hauteurAvecDescription
            : Jetons.LigneDeReglage.hauteur
    }

    private var valeurRetenue: String {
        guard case let .choix(valeur) = presentation.reglages[ligne.id] else {
            return ""
        }

        return valeur
    }

    private var intervalle: ClosedRange<Double> {
        guard let bornes = ligne.bornes, bornes.minimum < bornes.maximum else {
            return 0...1
        }

        return bornes.minimum...bornes.maximum
    }

    private var animation: Animation? {
        animationsReduites ? nil : Jetons.Mouvement.survol.animation
    }
}
