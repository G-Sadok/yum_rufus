import Core
import SwiftUI

//
// VueDeBibliotheque
//
// L ecran Bibliotheque de la section 5.1 : la barre de categories et la grille
// de couvertures.
//
// La grille est adaptative et non a nombre de colonnes fixe. Une largeur de
// carte comprise entre 150 et 200, section 4.3, laisse le systeme choisir
// combien tiennent : la meme grille sert alors la fenetre etroite et l ecran
// large sans qu aucune valeur ne soit ecrite deux fois.
//
// Le compteur de chapitres non lus vient de la base, deja denormalise. Il n est
// jamais recalcule pendant le defilement : c est l erreur numero cinq du cahier
// de developpement, celle qui fait ramer la grille des qu une bibliotheque
// depasse quelques centaines de series.
//

/// Ce que l ecran Bibliotheque affiche.
///
/// Non `Sendable`, comme `EtatDeContenu` qu il porte.
public enum EtatDeBibliotheque {
    /// Les series ne sont pas encore lues.
    case chargement

    /// Series de la categorie choisie, eventuellement aucune.
    case chargee([SerieDeGrille])

    /// Echec nomme, avec sa sortie.
    case erreur(EtatDeContenu)
}

/// Une serie telle que la grille la montre.
public struct SerieDeGrille: Sendable, Identifiable, Equatable {
    public let id: UUID
    public let titre: String
    public let chapitresNonLus: Int

    public init(id: UUID, titre: String, chapitresNonLus: Int) {
        self.id = id
        self.titre = titre
        self.chapitresNonLus = chapitresNonLus
    }
}

/// Textes de l ecran, pris dans le catalogue de l application.
public struct LibellesDeBibliotheque: Sendable, Equatable {
    public let videTitre: String
    public let videPhrase: String
    public let ajouterUneSource: String

    public init(videTitre: String, videPhrase: String, ajouterUneSource: String) {
        self.videTitre = videTitre
        self.videPhrase = videPhrase
        self.ajouterUneSource = ajouterUneSource
    }
}

/// Ce que l ecran declenche.
public struct CommandesDeBibliotheque {
    public let ouvrir: @MainActor (UUID) -> Void
    public let ajouterUneSource: @MainActor () -> Void

    public init(
        ouvrir: @escaping @MainActor (UUID) -> Void,
        ajouterUneSource: @escaping @MainActor () -> Void
    ) {
        self.ouvrir = ouvrir
        self.ajouterUneSource = ajouterUneSource
    }
}

/// Ecran Bibliotheque, section 5.1.
public struct VueDeBibliotheque: View {
    @Environment(\.palette) private var palette

    private let etat: EtatDeBibliotheque
    private let libelles: LibellesDeBibliotheque
    private let commandes: CommandesDeBibliotheque

    public init(
        etat: EtatDeBibliotheque,
        libelles: LibellesDeBibliotheque,
        commandes: CommandesDeBibliotheque
    ) {
        self.etat = etat
        self.libelles = libelles
        self.commandes = commandes
    }

    public var body: some View {
        contenu
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var contenu: some View {
        switch etat {
        case .chargement:
            ProgressView()
                .controlSize(.large)

        case let .chargee(series) where series.isEmpty:
            VueDEtatDeContenu(
                .vide(
                    symbole: Jetons.Icone.bibliotheque,
                    titre: libelles.videTitre,
                    phrase: libelles.videPhrase,
                    action: ActionDEtat(libelle: libelles.ajouterUneSource) {
                        commandes.ajouterUneSource()
                    }
                )
            )

        case let .chargee(series):
            grille(series)

        case let .erreur(contenu):
            VueDEtatDeContenu(contenu)
        }
    }

    private func grille(_ series: [SerieDeGrille]) -> some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(
                        .adaptive(
                            minimum: Jetons.CarteDeSerie.largeurMinimale,
                            maximum: Jetons.CarteDeSerie.largeurMaximale
                        ),
                        spacing: Jetons.CarteDeSerie.gouttiere
                    ),
                ],
                spacing: Jetons.CarteDeSerie.gouttiere
            ) {
                ForEach(series) { serie in
                    CarteDeSerie(serie: serie) {
                        commandes.ouvrir(serie.id)
                    }
                }
            }
            .padding(Jetons.CarteDeSerie.gouttiere)
        }
    }
}

/// Une carte de la grille, section 4.3.
struct CarteDeSerie: View {
    @Environment(\.palette) private var palette

    let serie: SerieDeGrille
    let ouvrir: () -> Void

    var body: some View {
        Button(action: ouvrir) {
            VStack(alignment: .leading, spacing: Jetons.CarteDeSerie.gouttiereDuTitre) {
                couverture

                Text(serie.titre)
                    .style(Jetons.CarteDeSerie.titre)
                    .foregroundStyle(palette.textes.primary.couleur)
                    .lineLimit(Jetons.CarteDeSerie.lignesDuTitre)
                    .multilineTextAlignment(.leading)
            }
        }
        .buttonStyle(.plain)
    }

    /// La couverture reste un aplat tant que la vignette n est pas chargee.
    ///
    /// Le ratio deux tiers est tenu par la carte elle meme, pas par l image :
    /// une grille dont les cartes changent de hauteur quand les vignettes
    /// arrivent saute sous le doigt pendant le defilement.
    private var couverture: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: Jetons.CarteDeSerie.rayon)
                .fill(palette.surfaces.card.couleur)
                .aspectRatio(Jetons.CarteDeSerie.ratio, contentMode: .fit)

            if serie.chapitresNonLus > 0 {
                pastilleDeNonLus
            }
        }
    }

    private var pastilleDeNonLus: some View {
        Text("\(serie.chapitresNonLus)")
            .style(Jetons.CarteDeSerie.pastille)
            .monospacedDigit()
            .foregroundStyle(palette.semantiques.accentText.couleur)
            .padding(.horizontal, Jetons.Espace.x2)
            .padding(.vertical, Jetons.Espace.x1)
            .background(
                Capsule().fill(palette.semantiques.accent.couleur)
            )
            .padding(Jetons.Espace.x2)
    }
}
