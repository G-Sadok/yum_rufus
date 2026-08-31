import Core
import SwiftUI

//
// Les controles des cinq variantes de ligne de reglage, section 4.1 de
// DESIGN-SPEC.md.
//
// Chaque controle est bati sur le controle du systeme qui porte le meme role,
// jamais sur un rectangle cliquable : le focus clavier, la navigation au
// tabulateur et VoiceOver viennent alors sans etre reecrits, et la section 7 les
// exige tous les trois.
//

/// Commutateur 48 par 28, variante 1 de la section 4.1.
struct StyleDInterrupteur: ToggleStyle {
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var animationsReduites
    @Environment(\.isEnabled) private var actif

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            piste(allume: configuration.isOn)
        }
        .buttonStyle(.plain)
        .animation(animation, value: configuration.isOn)
        // Le dessin est le notre, la representation offerte aux technologies
        // d assistance reste celle d un interrupteur du systeme, avec son
        // libelle et son etat. Le style rendu est celui du systeme pour eviter
        // que la representation ne rappelle ce style ci.
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
                .toggleStyle(.switch)
        }
    }

    private func piste(allume: Bool) -> some View {
        Capsule()
            .fill(couleurDeLaPiste(allume: allume))
            .frame(width: Jetons.Interrupteur.largeur, height: Jetons.Interrupteur.hauteur)
            .overlay(alignment: allume ? .trailing : .leading) {
                Circle()
                    .fill(palette.textes.onAccent.couleur)
                    .frame(
                        width: Jetons.Interrupteur.diametreDeLaPastille,
                        height: Jetons.Interrupteur.diametreDeLaPastille
                    )
                    .padding(.horizontal, Jetons.Interrupteur.jeu)
            }
    }

    private func couleurDeLaPiste(allume: Bool) -> Color {
        guard actif else {
            return palette.surfaces.cardHover.couleur
        }

        return allume
            ? palette.semantiques.accent.couleur
            : palette.surfaces.selected.couleur
    }

    private var animation: Animation? {
        animationsReduites ? nil : Jetons.Mouvement.survol.animation
    }
}

/// Valeur et chevron double, variante 2 de la section 4.1.
struct MenuDeReglage: View {
    @Environment(\.palette) private var palette
    @Environment(\.isEnabled) private var actif

    let ligne: LigneDeReglage
    let valeurRetenue: String
    let libelles: LibellesDeReglages
    let choisir: (String) -> Void

    var body: some View {
        Menu {
            ForEach(ligne.choix, id: \.self) { choix in
                Button(libelles.valeur(choix)) { choisir(choix) }
            }
        } label: {
            valeurEtChevron
        }
        .modifier(MenuSansBordure())
        .fixedSize()
        .accessibilityLabel(libelles.libelle(de: ligne.id))
        .accessibilityValue(libelles.valeur(valeurRetenue))
    }

    private var valeurEtChevron: some View {
        HStack(spacing: Jetons.LigneDeReglage.ecartAvantLeChevron) {
            Text(libelles.valeur(valeurRetenue))
                .style(Jetons.LigneDeReglage.valeur)
                .foregroundStyle(couleurDeLaValeur)

            // Le chevron dit qu un menu s ouvre, ce que le trait de bouton du
            // menu porte deja. Masque a VoiceOver.
            Image(systemName: Jetons.IconeDeReglage.chevronDeMenu)
                .font(.system(size: Jetons.LigneDeReglage.tailleDuChevron))
                .foregroundStyle(palette.textes.tertiary.couleur)
                .accessibilityHidden(true)
        }
    }

    /// La valeur passe en accent quand elle designe un choix herite du systeme,
    /// comme la section 5.5 le montre sur Langue.
    ///
    /// La ligne pose sa valeur sur `surface.card` au repos et sur
    /// `surface.cardHover` au survol. `accent.text` tombe a 4.1:1 sur la
    /// seconde en variante sombre, il est donc derive, voir `Lisibilite`.
    private var couleurDeLaValeur: Color {
        guard actif else {
            return palette.textes.disabled.couleur
        }

        guard ValeurHeriteeDuSysteme.concerne(valeurRetenue) else {
            return palette.textes.secondary.couleur
        }

        return palette.lisible(
            palette.semantiques.accentText,
            sur: [palette.surfaces.card, palette.surfaces.cardHover]
        ).couleur
    }
}

/// Menu pose dans une ligne, sans le cadre que macOS ajoute par defaut.
///
/// La section 4.1 ne dessine qu une valeur et un chevron double. Sur macOS, un
/// `Menu` non style prend le cadre d un bouton et ajoute son propre indicateur,
/// ce qui donnerait deux chevrons dans la meme ligne.
private struct MenuSansBordure: ViewModifier {
    func body(content: Content) -> some View {
        #if os(macOS)
            content
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
        #else
            content.menuIndicator(.hidden)
        #endif
    }
}

/// Valeur montree sans menu, pour Version et Dernier envoi.
///
/// La section 4.1 interdit un chevron double a cote d une valeur qui n ouvre
/// rien. La ligne se reduit donc a son texte.
struct ValeurEnLectureSeule: View {
    @Environment(\.palette) private var palette

    let texte: String

    var body: some View {
        Text(texte)
            .style(Jetons.LigneDeReglage.valeur)
            .foregroundStyle(palette.textes.secondary.couleur)
    }
}

/// Compteur, variante 5 de la section 4.1.
///
/// Le conteneur de 30 par 28 est celui du document. Il reste sous la cible de
/// 44 imposee au doigt par la section 7, aussi la ligne entiere expose une
/// action ajustable a VoiceOver : le reglage se change alors sans viser les
/// chevrons, qui restent la pour le pointeur.
///
/// La valeur affichee est un texte et non le nombre lui meme. Un compteur du
/// tableau 5.5 montre son entier, celui de l objectif quotidien montre
/// `Desactive` a son cran le plus bas : le controle ne decide pas comment se lit
/// ce qu il compte, son appelant le lui dit.
struct CompteurDeReglage: View {
    @Environment(\.palette) private var palette
    @Environment(\.isEnabled) private var actif

    let valeur: Int
    let texte: String
    let bornes: BornesDeReglage
    let etiquetteDAugmentation: String
    let etiquetteDeDiminution: String
    let changer: (Int) -> Void

    var body: some View {
        HStack(spacing: Jetons.CompteurDeReglage.ecartApresLaValeur) {
            Text(texte)
                .style(Jetons.LigneDeReglage.valeur, chiffresTabulaires: true)
                .foregroundStyle(actif ? palette.textes.secondary.couleur : palette.textes.disabled.couleur)

            conteneurDesChevrons
        }
        .accessibilityElement(children: .ignore)
        .accessibilityValue(texte)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: augmenter()
            case .decrement: diminuer()
            @unknown default: break
            }
        }
    }

    private var conteneurDesChevrons: some View {
        VStack(spacing: 0) {
            chevron(
                Jetons.IconeDeReglage.chevronDAugmentation,
                libelle: etiquetteDAugmentation,
                action: augmenter
            )
            chevron(
                Jetons.IconeDeReglage.chevronDeDiminution,
                libelle: etiquetteDeDiminution,
                action: diminuer
            )
        }
        .frame(
            width: Jetons.CompteurDeReglage.largeur,
            height: Jetons.CompteurDeReglage.hauteur
        )
        .background(
            RoundedRectangle(cornerRadius: Jetons.CompteurDeReglage.rayon, style: .continuous)
                .fill(palette.surfaces.menu.couleur)
        )
    }

    private func chevron(_ symbole: String, libelle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbole)
                .font(.system(size: Jetons.LigneDeReglage.tailleDuChevron))
                .foregroundStyle(palette.textes.secondary.couleur)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(libelle)
    }

    private func augmenter() {
        changer(Int(bornes.contraindre(Double(valeur) + bornes.pas)))
    }

    private func diminuer() {
        changer(Int(bornes.contraindre(Double(valeur) - bornes.pas)))
    }
}

/// Valeurs de menu qui designent un choix herite du systeme.
///
/// La section 4.1 les veut en accent plutot qu en `text.secondary`. Le cas
/// n existe que pour les reglages qui proposent de suivre le systeme.
enum ValeurHeriteeDuSysteme {
    static func concerne(_ valeurBrute: String) -> Bool {
        valeurBrute == ChoixDeLangue.systeme.rawValue
            || valeurBrute == ChoixDApparence.systeme.rawValue
    }
}
