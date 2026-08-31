import Core
import SwiftUI

//
// Detail du stockage, sous ecran de la section 5.5 de DESIGN-SPEC.md.
//
// Gabarit colonne 580, une carte de trois lignes de navigation, chacune portant
// la taille reelle de sa categorie. C est l ecran d ou partent les trois ecrans
// de detail.
//
// Cet ecran n a pas d etat vide, et ce n est pas un oubli. La section 5.5 le dit
// pour l ecran Reglages dont il herite : sur une installation neuve la colonne
// reste complete, ce sont les valeurs qui disent l absence. Les trois lignes
// affichent donc `0 o`, jamais un ecran vide qui inviterait a remplir un cache.
//

/// Etat de la zone de contenu de l ecran d ensemble du stockage.
public enum EtatDeGestionDuStockage {
    /// Tailles en cours de mesure.
    case chargement

    /// Tailles mesurees. Un inventaire a zero reste un inventaire.
    case chargee(InventaireDuStockage)

    /// Le disque n a pas pu etre mesure. L etat est compose par l appelant, qui
    /// seul connait la cause reelle.
    case erreur(EtatDeContenu)
}

/// Ce que les lignes de l ecran d ensemble declenchent.
public struct CommandesDeStockage {
    /// Ouvre l ecran de detail d une categorie.
    public let ouvrir: @MainActor (CategorieDeStockage) -> Void

    public init(ouvrir: @escaping @MainActor (CategorieDeStockage) -> Void) {
        self.ouvrir = ouvrir
    }

    /// Commandes inertes, pour un apercu ou un ecran en lecture seule.
    ///
    /// Calculee a chaque appel : un ensemble de fermetures n est pas `Sendable`,
    /// et une constante globale ne peut pas l etre non plus.
    public static var inertes: CommandesDeStockage {
        CommandesDeStockage(ouvrir: { _ in })
    }
}

/// Ecran d ensemble de la gestion du stockage.
public struct VueDeGestionDuStockage: View {
    @Environment(\.palette) private var palette

    private let etat: EtatDeGestionDuStockage
    private let libelles: LibellesDeStockage
    private let commandes: CommandesDeStockage

    /// Construit l ecran.
    ///
    /// - Parameters:
    ///   - etat: chargement, inventaire ou erreur.
    ///   - libelles: textes pris dans le catalogue de chaines.
    ///   - commandes: ce que les lignes declenchent.
    public init(
        etat: EtatDeGestionDuStockage,
        libelles: LibellesDeStockage,
        commandes: CommandesDeStockage
    ) {
        self.etat = etat
        self.libelles = libelles
        self.commandes = commandes
    }

    public var body: some View {
        contenu
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(palette.surfaces.canvas.couleur)
    }

    @ViewBuilder
    private var contenu: some View {
        switch etat {
        case .chargement:
            colonne { squelettes }

        case let .erreur(etatDeContenu):
            VueDEtatDeContenu(etatDeContenu)

        case let .chargee(inventaire):
            colonne { carte(inventaire) }
        }
    }

    // MARK: Colonne

    /// Gabarit colonne 580, celui de l ecran Reglages dont ce sous ecran part.
    private func colonne(@ViewBuilder _ interieur: () -> some View) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                enTete
                interieur()
                description
            }
            .frame(maxWidth: Jetons.Stockage.largeurDeColonne)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Jetons.Contenu.margeLaterale)
            .padding(.vertical, Jetons.CarteDeReglages.margeVerticale)
        }
    }

    private var enTete: some View {
        Text(libelles.titre)
            .style(Jetons.CarteDeReglages.enTete)
            .foregroundStyle(palette.textes.primary.couleur)
            .padding(.bottom, Jetons.CarteDeReglages.ecartApresLEnTete)
            .accessibilityAddTraits(.isHeader)
    }

    private var description: some View {
        Text(libelles.description)
            .style(Jetons.CarteDeReglages.description)
            .foregroundStyle(palette.textes.tertiary.couleur)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, Jetons.CarteDeReglages.ecartAvantLaDescription)
    }

    // MARK: Carte

    private func carte(_ inventaire: InventaireDuStockage) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(CategorieDeStockage.allCases.enumerated()), id: \.element) { rang, categorie in
                LigneDeCategorieDeStockage(
                    categorie: categorie,
                    octets: inventaire.octets(de: categorie),
                    libelles: libelles,
                    ouvrir: commandes.ouvrir
                )

                if rang < CategorieDeStockage.allCases.count - 1 {
                    separateur
                }
            }
        }
        .background(palette.surfaces.card.couleur)
        .clipShape(RoundedRectangle(cornerRadius: Jetons.Stockage.rayon, style: .continuous))
    }

    /// Filet encastre de 20 a gauche, affleurant a droite, section 4.2.
    private var separateur: some View {
        Rectangle()
            .fill(palette.semantiques.separator.couleur)
            .frame(height: Jetons.Stockage.epaisseurDuSeparateur)
            .padding(.leading, Jetons.Stockage.encastrementDuSeparateur)
            .accessibilityHidden(true)
    }

    /// Squelettes aux dimensions exactes des lignes attendues, section 4.10.
    private var squelettes: some View {
        VueDeSquelette()
            .frame(
                height: Jetons.Stockage.hauteurDeCategorie
                    * Double(CategorieDeStockage.allCases.count)
            )
            .clipShape(RoundedRectangle(cornerRadius: Jetons.Stockage.rayon, style: .continuous))
    }
}

/// Une ligne de categorie, variante navigation de la section 4.1.
struct LigneDeCategorieDeStockage: View {
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var tailleDeTexte
    @State private var survolee = false
    @FocusState private var focalisee: Bool

    let categorie: CategorieDeStockage
    let octets: Int
    let libelles: LibellesDeStockage
    let ouvrir: @MainActor (CategorieDeStockage) -> Void

    var body: some View {
        Button {
            ouvrir(categorie)
        } label: {
            contenu
                .padding(.horizontal, Jetons.Stockage.margeLaterale)
                .frame(minHeight: Jetons.Stockage.hauteurDeCategorie)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .focused($focalisee)
        .background(survolee ? palette.surfaces.cardHover.couleur : Color.clear)
        .contourDeFocus(focalisee, rayonDeLElement: 0)
        .onHover { survolee = $0 }
        .accessibilityLabel(etiquette)
    }

    /// Au dela de la taille de texte `large`, la ligne passe en pile, section
    /// 4.1. Sans cela, un libelle de categorie et sa taille ne tiennent pas cote
    /// a cote sur 580.
    @ViewBuilder
    private var contenu: some View {
        if tailleDeTexte > .large {
            VStack(alignment: .leading, spacing: Jetons.Espace.x2) {
                enTete
                valeur
                    .padding(.leading, Jetons.LigneDeReglage.decalageDuControleEnPile)
            }
            .padding(.vertical, Jetons.Espace.x3)
        } else {
            HStack(spacing: 0) {
                enTete
                Spacer(minLength: Jetons.Stockage.ecartAvantLaTaille)
                valeur
            }
        }
    }

    private var enTete: some View {
        HStack(spacing: Jetons.Stockage.gouttiereApresLIcone) {
            Image(systemName: Jetons.Stockage.symbole(de: categorie))
                .font(.system(size: Jetons.Stockage.tailleDIcone))
                .foregroundStyle(palette.semantiques.accent.couleur)
                .frame(width: Jetons.Stockage.tailleDIcone)
                .accessibilityHidden(true)

            Text(libelles.libelle(de: categorie))
                .style(Jetons.Stockage.libelle)
                .foregroundStyle(palette.textes.primary.couleur)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
    }

    /// Taille reelle de la categorie, suivie du chevron de navigation.
    ///
    /// Chiffres tabulaires : la taille change en place des qu une suppression
    /// aboutit, section 1.5.
    private var valeur: some View {
        HStack(spacing: Jetons.Stockage.ecartAvantLeChevron) {
            Text(TexteDeStockage.taille(octets, libelles: libelles))
                .style(Jetons.Stockage.taille, chiffresTabulaires: true)
                .foregroundStyle(palette.textes.secondary.couleur)

            // Le chevron annonce une navigation, ce que le trait de bouton
            // porte deja. Masque a VoiceOver.
            Image(systemName: Jetons.IconeDeReglage.chevronDeNavigation)
                .font(.system(size: Jetons.Stockage.tailleDuChevron))
                .foregroundStyle(palette.textes.tertiary.couleur)
                .accessibilityHidden(true)
        }
    }

    /// Etiquette lue par VoiceOver, libelle et taille reunis.
    private var etiquette: String {
        TexteDeChapitre.joindre([
            libelles.libelle(de: categorie),
            TexteDeStockage.taille(octets, libelles: libelles),
        ])
    }
}
