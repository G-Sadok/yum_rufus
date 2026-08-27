import Core
import SwiftUI

//
// Ecran de detail d une categorie de stockage, section 15 de la section 5.5.
//
// Un seul type sert les trois ecrans. Les trois montrent la meme chose, une
// liste de postes avec leur poids reel, et ne different que par ce qu un poste
// designe. Trois vues jumelles auraient triple le cout de la moindre correction
// de geometrie sans rien apporter a l utilisateur.
//
// Le troisieme critere de la fonctionnalite se joue ici. Aucun bouton de cet
// ecran n appelle la suppression : ils posent une demande dans la garde, et la
// suppression ne part que de la confirmation de la modale, qui est le seul
// endroit du fichier ou `commandes.supprimer` est appele. La garde refuse par
// ailleurs de rendre une cible qui n aurait pas ete demandee, ce qui ferme le
// chemin d un raccourci clavier reste actif.
//

/// Etat de la zone de contenu d un ecran de detail du stockage.
public enum EtatDeDetailDeStockage {
    /// Postes en cours de mesure.
    case chargement

    /// Postes mesures. Une liste vide donne l etat vide.
    case chargee(DetailDuStockage)

    /// Le disque n a pas pu etre mesure. L etat est compose par l appelant, qui
    /// seul connait la cause reelle.
    case erreur(EtatDeContenu)
}

/// Ce qu un ecran de detail declenche.
public struct CommandesDeDetailDeStockage {
    /// Supprime ce qu une confirmation vient d autoriser.
    ///
    /// La fermeture ne recoit jamais une selection, toujours une demande
    /// confirmee. Le type dit donc a l appel ce que la garde a verifie.
    public let supprimer: @MainActor (DemandeDeSuppression) -> Void

    public init(supprimer: @escaping @MainActor (DemandeDeSuppression) -> Void) {
        self.supprimer = supprimer
    }

    /// Commandes inertes, pour un apercu ou un ecran en lecture seule.
    ///
    /// Calculee a chaque appel : un ensemble de fermetures n est pas `Sendable`,
    /// et une constante globale ne peut pas l etre non plus.
    public static var inertes: CommandesDeDetailDeStockage {
        CommandesDeDetailDeStockage(supprimer: { _ in })
    }
}

/// Ecran de detail d une categorie de stockage.
public struct VueDeDetailDeStockage: View {
    @Environment(\.palette) private var palette
    @State private var selection = SelectionDePostes()
    @State private var garde = GardeDeSuppression()

    private let categorie: CategorieDeStockage
    private let etat: EtatDeDetailDeStockage
    private let libelles: LibellesDeStockage
    private let commandes: CommandesDeDetailDeStockage

    /// Construit l ecran.
    ///
    /// - Parameters:
    ///   - categorie: categorie montree, qui decide du titre et des libelles.
    ///   - etat: chargement, postes ou erreur.
    ///   - libelles: textes pris dans le catalogue de chaines.
    ///   - commandes: ce que la confirmation declenche.
    public init(
        categorie: CategorieDeStockage,
        etat: EtatDeDetailDeStockage,
        libelles: LibellesDeStockage,
        commandes: CommandesDeDetailDeStockage
    ) {
        self.categorie = categorie
        self.etat = etat
        self.libelles = libelles
        self.commandes = commandes
    }

    public var body: some View {
        contenu
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(palette.surfaces.canvas.couleur)
            .modaleCourte(presentee: garde.estDemandee, contenu: confirmation)
    }

    @ViewBuilder
    private var contenu: some View {
        switch etat {
        case .chargement:
            colonne { squelettes }

        case let .erreur(etatDeContenu):
            VueDEtatDeContenu(etatDeContenu)

        case let .chargee(detail):
            if detail.postes.isEmpty {
                VueDEtatDeContenu(etatVide)
            } else {
                liste(detail)
            }
        }
    }

    // MARK: Colonne

    /// Gabarit colonne 580, celui de l ecran Reglages dont ce sous ecran part.
    private func colonne(@ViewBuilder _ interieur: () -> some View) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                interieur()
            }
            .frame(maxWidth: Jetons.Stockage.largeurDeColonne)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Jetons.Contenu.margeLaterale)
            .padding(.vertical, Jetons.CarteDeReglages.margeVerticale)
        }
    }

    private func liste(_ detail: DetailDuStockage) -> some View {
        colonne {
            enTete(detail)
            carte(detail)
            description
            barre(detail)
        }
        // La selection ne survit pas a la disparition des lignes qu elle vise :
        // une suppression qui aboutit doit refermer la barre, pas la laisser
        // ouverte sur des postes effaces.
        .onChange(of: detail.postes) { _, postes in
            selection.restreindre(a: postes)
        }
    }

    private func enTete(_ detail: DetailDuStockage) -> some View {
        HStack(spacing: Jetons.Espace.x3) {
            Text(libelles.libelle(de: categorie))
                .style(Jetons.CarteDeReglages.enTete)
                .foregroundStyle(palette.textes.primary.couleur)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: Jetons.Espace.x3)

            Button(libelles.toutSupprimer) {
                demander(detail.postes)
            }
            .buttonStyle(.plain)
            .style(Jetons.FicheDeSerie.actionDeListe)
            .foregroundStyle(palette.semantiques.danger.couleur)
        }
        .padding(.bottom, Jetons.CarteDeReglages.ecartApresLEnTete)
    }

    private func carte(_ detail: DetailDuStockage) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(detail.postes.enumerated()), id: \.element.id) { rang, poste in
                LigneDePosteDeStockage(
                    poste: poste,
                    categorie: categorie,
                    retenu: selection.contient(poste.id),
                    libelles: libelles,
                    basculer: { selection.basculer(poste.id) },
                    supprimer: { demander([poste]) }
                )

                if rang < detail.postes.count - 1 {
                    separateur
                }
            }
        }
        .background(palette.surfaces.card.couleur)
        .clipShape(RoundedRectangle(cornerRadius: Jetons.Stockage.rayon, style: .continuous))
    }

    private var description: some View {
        Text(libelles.description)
            .style(Jetons.CarteDeReglages.description)
            .foregroundStyle(palette.textes.tertiary.couleur)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, Jetons.CarteDeReglages.ecartAvantLaDescription)
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
                height: Jetons.Stockage.hauteurDePoste * Double(Jetons.Stockage.nombreDeSquelettes)
            )
            .clipShape(RoundedRectangle(cornerRadius: Jetons.Stockage.rayon, style: .continuous))
    }

    // MARK: Barre de selection

    /// Barre d actions de la selection multiple, section 4.5.
    @ViewBuilder
    private func barre(_ detail: DetailDuStockage) -> some View {
        if selection.barreEstOuverte {
            HStack(spacing: Jetons.BarreDeSelection.ecartEntreActions) {
                // Chiffres tabulaires : le compteur change en place a chaque
                // clic, section 1.5.
                Text(String(format: libelles.compteurDeSelection, selection.nombre))
                    .style(Jetons.BarreDeSelection.compteur, chiffresTabulaires: true)
                    .foregroundStyle(palette.textes.primary.couleur)

                Spacer(minLength: 0)

                Button(libelles.supprimer) {
                    demander(selection.postesRetenus(dans: detail.postes))
                }
                .buttonStyle(.plain)
                .style(Jetons.FicheDeSerie.actionDeListe)
                .foregroundStyle(palette.semantiques.danger.couleur)

                Button(libelles.fermerLaSelection) {
                    selection.vider()
                }
                .buttonStyle(.plain)
                .style(Jetons.FicheDeSerie.actionDeListe)
                .foregroundStyle(palette.textes.tertiary.couleur)
            }
            .padding(.horizontal, Jetons.BarreDeSelection.margeLaterale)
            .frame(height: Jetons.BarreDeSelection.hauteur)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Jetons.BarreDeSelection.rayon, style: .continuous)
                    .fill(palette.surfaces.menu.couleur)
            )
            .elevation(
                Jetons.BarreDeSelection.elevation,
                rayon: Jetons.BarreDeSelection.rayon,
                palette: palette
            )
            .padding(.top, Jetons.Stockage.ecartAvantLaBarre)
            .accessibilityElement(children: .contain)
        }
    }

    // MARK: Confirmation

    /// Pose une demande de suppression. Rien n est efface a ce moment.
    private func demander(_ postes: [PosteDeStockage]) {
        garde.demander(DemandeDeSuppression(categorie: categorie, postes: postes))
    }

    /// Contenu de la modale courte, section 4.8.
    private var confirmation: ContenuDeModaleCourte {
        ContenuDeModaleCourte(
            titre: libelles.confirmationTitre,
            description: descriptionDeConfirmation,
            annuler: ActionDEtat(libelle: libelles.confirmationAnnuler) { garde.annuler() },
            confirmer: ActionDEtat(libelle: libelles.confirmationSupprimer) { confirmer() },
            confirmationEstDestructive: true
        )
    }

    private var descriptionDeConfirmation: String {
        guard let demande = garde.demande else {
            return ""
        }

        return TexteDeStockage.descriptionDeConfirmation(de: demande, libelles: libelles)
    }

    /// Seul appel de la suppression de tout l ecran.
    ///
    /// La garde rend la demande posee, ou rien. Une confirmation qui arriverait
    /// sans demande, par un raccourci laisse actif, n efface donc rien.
    private func confirmer() {
        guard let demande = garde.confirmer() else {
            return
        }

        selection.vider()
        commandes.supprimer(demande)
    }

    // MARK: Etat vide

    /// Etat vide de la section 4.10, une categorie qui n occupe aucune place.
    ///
    /// Aucun bouton. La section 4.10 rend l action facultative, et il n y a rien
    /// a proposer : un cache se remplit en lisant, pas en appuyant.
    private var etatVide: EtatDeContenu {
        .vide(
            symbole: Jetons.Stockage.symbole(de: categorie),
            titre: libelles.videTitre,
            phrase: libelles.videPhrase,
            action: nil
        )
    }
}
