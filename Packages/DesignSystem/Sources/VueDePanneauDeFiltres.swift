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
// Un traitement reserve a l abonnement porte une couronne a la place de son
// interrupteur, comme la variante premium de la section 4.1. La section 5.7 ne
// le dit que de la colorisation, mais la matrice de la section 10 du cahier de
// developpement place aussi l amelioration par IA derriere l abonnement. Les
// deux portent donc la couronne : afficher un interrupteur qui ne peut pas
// s armer serait mentir sur ce que l utilisateur peut faire.
//

/// Panneau de filtres du lecteur, section 5.7.
public struct VueDePanneauDeFiltres: View {
    @Environment(\.palette) private var palette

    private let reglages: ReglagesDeFiltres
    private let abonnement: EtatDePremium
    private let libelles: LibellesDePanneauDeFiltres
    private let commandes: CommandesDePanneauDeFiltres

    /// Construit le panneau.
    ///
    /// - Parameters:
    ///   - reglages: valeurs courantes des cinq curseurs et des trois
    ///     interrupteurs.
    ///   - abonnement: etat de l abonnement. Il ouvre les traitements par IA,
    ///     la couronne tombe alors et l interrupteur revient.
    ///   - libelles: textes pris dans le catalogue de chaines.
    ///   - commandes: ce que les lignes declenchent.
    public init(
        reglages: ReglagesDeFiltres,
        abonnement: EtatDePremium = .gratuit,
        libelles: LibellesDePanneauDeFiltres,
        commandes: CommandesDePanneauDeFiltres
    ) {
        self.reglages = reglages
        self.abonnement = abonnement
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
                    verrouille: estVerrouille(traitement),
                    libelle: libelles.libelle(de: traitement),
                    etiquetteDeLaCouronne: libelles.etiquetteDeLaCouronne,
                    basculer: { commandes.basculer(traitement, $0) },
                    ouvrirLeMurPremium: commandes.ouvrirLeMurPremium
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

    /// Vrai quand ce traitement demande un abonnement que l utilisateur n a pas.
    ///
    /// La reponse vient de la matrice de la section 10 et non d une condition
    /// ecrite ici. Le panneau n a pas a savoir lesquels des trois traitements
    /// sont payants, il a a savoir lesquels sont ouverts maintenant.
    func estVerrouille(_ traitement: TraitementDImage) -> Bool {
        MatriceDeVerrouillage.acces(a: traitement, selon: abonnement) == .verrouille
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
        .overlay(contourDeFocus)
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

    @ViewBuilder
    private var contourDeFocus: some View {
        if focalisee {
            RoundedRectangle(cornerRadius: Jetons.Focus.decalage, style: .continuous)
                .strokeBorder(palette.semantiques.focusRing.couleur, lineWidth: Jetons.Focus.epaisseur)
                .padding(-Jetons.Focus.decalage)
        }
    }
}

/// Une ligne a interrupteur du panneau, variante 1 de la section 4.1.
struct LigneDeTraitement: View {
    @Environment(\.palette) private var palette
    @FocusState private var focalisee: Bool

    let traitement: TraitementDImage
    let actif: Bool
    let verrouille: Bool
    let libelle: String
    let etiquetteDeLaCouronne: String
    let basculer: (Bool) -> Void
    let ouvrirLeMurPremium: () -> Void

    var body: some View {
        HStack(spacing: Jetons.Espace.x4) {
            Text(libelle)
                .style(Jetons.PanneauDeFiltres.libelle)
                .foregroundStyle(verrouille ? palette.semantiques.accentText.couleur : palette.textes.primary.couleur)

            Spacer(minLength: Jetons.Espace.x2)

            controle
        }
        .padding(.horizontal, Jetons.PanneauDeFiltres.margeLaterale)
        .frame(minHeight: Jetons.PanneauDeFiltres.hauteurDInterrupteur)
        .overlay(contourDeFocus)
    }

    @ViewBuilder
    private var controle: some View {
        if verrouille {
            couronne
        } else {
            interrupteur
        }
    }

    private var interrupteur: some View {
        Toggle(libelle, isOn: Binding(get: { actif }, set: { basculer($0) }))
            .labelsHidden()
            .toggleStyle(StyleDInterrupteur())
            .focused($focalisee)
    }

    private var couronne: some View {
        Button(action: ouvrirLeMurPremium) {
            Image(systemName: Jetons.Icone.premium)
                .font(.system(size: Jetons.PanneauDeFiltres.tailleDeLaCouronne))
                .foregroundStyle(palette.semantiques.accent.couleur)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .focused($focalisee)
        .accessibilityLabel(etiquetteDeLaCouronne)
    }

    @ViewBuilder
    private var contourDeFocus: some View {
        if focalisee {
            RoundedRectangle(cornerRadius: Jetons.Focus.decalage, style: .continuous)
                .strokeBorder(palette.semantiques.focusRing.couleur, lineWidth: Jetons.Focus.epaisseur)
                .padding(-Jetons.Focus.decalage)
        }
    }
}
