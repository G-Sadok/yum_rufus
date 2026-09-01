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
    private let couverture: @MainActor (UUID) -> ImageDeLecteur?
    private let analyseEnCours: Bool

    /// Construit l ecran.
    ///
    /// - Parameters:
    ///   - etat: chargement, grille ou erreur.
    ///   - libelles: libelles pris dans le catalogue de chaines.
    ///   - commandes: ce que les cartes declenchent.
    ///   - couverture: couverture deja decodee d une serie, nulle tant qu elle
    ///     ne l est pas. La fonction est appelee pendant le rendu et ne doit
    ///     rien decoder : le decodage vit dans l application, qui le fait hors
    ///     du fil principal et previent par observation quand il a abouti.
    ///   - analyseEnCours: vrai pendant qu une source est lue. La grille dit
    ///     alors qu elle attend, au lieu d afficher un etat vide qui laisserait
    ///     croire que l analyse a echoue.
    public init(
        etat: EtatDeBibliotheque,
        libelles: LibellesDeBibliotheque,
        commandes: CommandesDeBibliotheque,
        couverture: @escaping @MainActor (UUID) -> ImageDeLecteur? = { _ in nil },
        analyseEnCours: Bool = false
    ) {
        self.etat = etat
        self.libelles = libelles
        self.commandes = commandes
        self.couverture = couverture
        self.analyseEnCours = analyseEnCours
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

        case let .chargee(series) where series.isEmpty && analyseEnCours:
            // Une source est en train d etre lue. Montrer l etat vide ici
            // ferait croire qu elle n a rien rendu, alors qu elle n a pas
            // encore fini.
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
                .overlay(alignment: .top) {
                    if analyseEnCours {
                        indicateurDAnalyse
                    }
                }

        case let .erreur(contenu):
            VueDEtatDeContenu(contenu)
        }
    }

    /// Bandeau discret pendant qu une source est relue.
    ///
    /// Pose par dessus la grille et non a sa place : les series deja rangees
    /// restent lisibles et ouvrables pendant que les nouvelles arrivent.
    private var indicateurDAnalyse: some View {
        ProgressView()
            .controlSize(.small)
            .padding(Jetons.Espace.x3)
            .background(.regularMaterial, in: Capsule())
            .padding(.top, Jetons.Espace.x3)
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
                    CarteDeSerie(serie: serie, couverture: couverture(serie.id)) {
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

    /// Couverture decodee, nulle tant qu elle ne l est pas.
    let couverture: ImageDeLecteur?

    let ouvrir: () -> Void

    var body: some View {
        Button(action: ouvrir) {
            VStack(alignment: .leading, spacing: Jetons.CarteDeSerie.gouttiereDuTitre) {
                vignette

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
    /// arrivent saute sous le doigt pendant le defilement. L image est donc
    /// rognee pour remplir le cadre, jamais le cadre ajuste a l image.
    private var vignette: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: Jetons.CarteDeSerie.rayon)
                .fill(palette.surfaces.card.couleur)
                .aspectRatio(Jetons.CarteDeSerie.ratio, contentMode: .fit)
                .overlay {
                    if let couverture {
                        Image(decorative: couverture.image, scale: 1)
                            .resizable()
                            .scaledToFill()
                            .clipShape(
                                RoundedRectangle(cornerRadius: Jetons.CarteDeSerie.rayon)
                            )
                    }
                }
                .clipped()

            if serie.chapitresNonLus > 0 {
                pastilleDeNonLus
            }
        }
    }

    private var pastilleDeNonLus: some View {
        Text("\(serie.chapitresNonLus)")
            .style(Jetons.CarteDeSerie.pastille)
            .monospacedDigit()
            // Le chiffre est pose sur l aplat d accent, pas a cote : c est
            // `text.onAccent` qu il lui faut. `accent.text` est la couleur d un
            // texte accentue sur un fond neutre, et sur l aplat elle donnait du
            // bleu sur du bleu, donc une pastille vide.
            .foregroundStyle(palette.textes.onAccent.couleur)
            .padding(.horizontal, Jetons.Espace.x2)
            .padding(.vertical, Jetons.Espace.x1)
            .background(
                Capsule().fill(palette.semantiques.accent.couleur)
            )
            .padding(Jetons.Espace.x2)
    }
}
