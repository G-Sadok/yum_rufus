import Core
import SwiftUI

//
// Panneau de filtres du lecteur, section 5.7 de DESIGN-SPEC.md.
//
// Popover ancre au bouton Filtres, largeur 300, rayon 14, elevation 1. Cinq
// curseurs, un separateur, trois interrupteurs. Chaque modification s applique
// en direct sur la page visible.
//
// Le direct n est pas une affaire de vue. La vue ne fait que remonter la
// nouvelle valeur : c est le lecteur qui refait passer la page visible dans la
// chaine de traitement, en une seule passe de rendu. La vue n a donc aucun etat
// a elle, et rien a garder entre deux deplacements de curseur. C est ce qui
// empeche l ecart classique entre ce que le panneau affiche et ce que la page
// montre.
//
// Le panneau se pose sur la planche, dans un ecran dont la these veut que
// l interface disparaisse. Il en tire deux consequences. Aucun aplat d accent
// hors des controles eux memes, et aucune icone decorative a gauche des
// libelles, voir `Jetons.PanneauDeFiltres`.
//
// Les trois traitements sont ouverts a tous. Chacun porte donc son
// interrupteur, sans condition.
//

/// Panneau de filtres du lecteur, section 5.7.
public struct VueDePanneauDeFiltres: View {
    @Environment(\.palette) private var palette

    private let reglages: ReglagesDeFiltres
    private let libelles: LibellesDePanneauDeFiltres
    private let commandes: CommandesDePanneauDeFiltres

    /// Construit le panneau.
    ///
    /// - Parameters:
    ///   - reglages: valeurs courantes des cinq curseurs et des trois
    ///     interrupteurs.
    ///   - libelles: textes pris dans le catalogue de chaines.
    ///   - commandes: ce que les lignes declenchent.
    public init(
        reglages: ReglagesDeFiltres,
        libelles: LibellesDePanneauDeFiltres,
        commandes: CommandesDePanneauDeFiltres
    ) {
        self.reglages = reglages
        self.libelles = libelles
        self.commandes = commandes
    }

    public var body: some View {
        VStack(spacing: 0) {
            curseurs
            separateur
            interrupteurs
        }
        .padding(.vertical, Jetons.PanneauDeFiltres.margeVerticale)
        .frame(width: Jetons.PanneauDeFiltres.largeur)
        .background(palette.surfaces.menu.couleur)
        .clipShape(RoundedRectangle(cornerRadius: Jetons.PanneauDeFiltres.rayon, style: .continuous))
        .elevation(
            Jetons.PanneauDeFiltres.elevation,
            rayon: Jetons.PanneauDeFiltres.rayon,
            palette: palette
        )
        .accessibilityLabel(libelles.titre)
    }

    // MARK: Groupes

    private var curseurs: some View {
        VStack(spacing: 0) {
            ForEach(FiltreDImage.ordreDuPanneau, id: \.self) { filtre in
                LigneDeFiltre(
                    filtre: filtre,
                    valeur: reglages.valeur(filtre),
                    libelle: libelles.libelle(de: filtre),
                    regler: { commandes.regler(filtre, $0) }
                )
            }
        }
    }

    private var interrupteurs: some View {
        VStack(spacing: 0) {
            ForEach(TraitementDImage.ordreDuPanneau, id: \.self) { traitement in
                LigneDeTraitement(
                    traitement: traitement,
                    actif: reglages.estActif(traitement),
                    libelle: libelles.libelle(de: traitement),
                    basculer: { commandes.basculer(traitement, $0) }
                )
            }
        }
    }

    /// Filet unique du panneau, entre les curseurs et les interrupteurs.
    private var separateur: some View {
        Rectangle()
            .fill(palette.semantiques.separator.couleur)
            .frame(height: Jetons.PanneauDeFiltres.epaisseurDuSeparateur)
            .padding(.vertical, Jetons.PanneauDeFiltres.margeVerticale)
            .accessibilityHidden(true)
    }
}

/// Une ligne a curseur du panneau, variante 4 de la section 4.1.
struct LigneDeFiltre: View {
    @Environment(\.palette) private var palette
    @FocusState private var focalisee: Bool

    let filtre: FiltreDImage
    let valeur: Double
    let libelle: String
    let regler: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Jetons.PanneauDeFiltres.ecartAvantLeControle) {
            enTete
            curseur
        }
        .padding(.horizontal, Jetons.PanneauDeFiltres.margeLaterale)
        .frame(minHeight: Jetons.PanneauDeFiltres.hauteurDeCurseur)
        .contourDeFocus(focalisee, rayonDeLElement: 0)
    }

    private var enTete: some View {
        HStack(spacing: Jetons.Espace.x4) {
            Text(libelle)
                .style(Jetons.PanneauDeFiltres.libelle)
                .foregroundStyle(palette.textes.primary.couleur)

            Spacer(minLength: Jetons.Espace.x2)

            Text(TexteDeReglage.valeurDuCurseur(valeur))
                .style(Jetons.PanneauDeFiltres.valeur, chiffresTabulaires: true)
                .foregroundStyle(palette.textes.secondary.couleur)
        }
    }

    private var curseur: some View {
        Slider(
            value: Binding(get: { valeur }, set: { regler($0) }),
            in: filtre.bornes.minimum...filtre.bornes.maximum,
            step: filtre.bornes.pas
        )
        .tint(palette.semantiques.accent.couleur)
        .focused($focalisee)
        .accessibilityLabel(libelle)
    }
}

/// Une ligne a interrupteur du panneau, variante 1 de la section 4.1.
struct LigneDeTraitement: View {
    @Environment(\.palette) private var palette
    @FocusState private var focalisee: Bool

    let traitement: TraitementDImage
    let actif: Bool
    let libelle: String
    let basculer: (Bool) -> Void

    var body: some View {
        HStack(spacing: Jetons.Espace.x4) {
            Text(libelle)
                .style(Jetons.PanneauDeFiltres.libelle)
                .foregroundStyle(couleurDuLibelle)

            Spacer(minLength: Jetons.Espace.x2)

            controle
        }
        .padding(.horizontal, Jetons.PanneauDeFiltres.margeLaterale)
        .frame(minHeight: Jetons.PanneauDeFiltres.hauteurDInterrupteur)
        .contourDeFocus(focalisee, rayonDeLElement: 0)
    }

    /// Le libelle est en `text.primary` sur `surface.menu`, couple que la
    /// section 7 garantit et que `ContrasteDesJetonsTests` mesure deja. Aucune
    /// derivation n est donc necessaire ici, contraste-ok.
    private var couleurDuLibelle: Color {
        palette.textes.primary.couleur
    }

    private var controle: some View {
        interrupteur
    }

    private var interrupteur: some View {
        Toggle(libelle, isOn: Binding(get: { actif }, set: { basculer($0) }))
            .labelsHidden()
            .toggleStyle(StyleDInterrupteur())
            .focused($focalisee)
    }
}
