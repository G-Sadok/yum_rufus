import Core
import SwiftUI

//
// VueDeRecherche
//
// L ecran Rechercher de la section 5.4, assemble a partir des pieces que la
// fonctionnalite avait deja posees : le champ de la barre d outils, la rangee
// d une source, sa ligne d erreur et ses squelettes.
//
// Rien ici ne retient rien. Chaque rangee lit son seul groupe, et le modele de
// Core garantit qu une reponse ne touche que sa rangee. L ecran n a donc aucun
// etat commun ou une source lente pourrait retenir les autres, ce qui est le
// premier critere de la section 5.4.
//
// Le lien Tout voir remplace les rangees par la grille complete d une seule
// source. Il ne pousse pas une vue par dessus : la liste depliee est le meme
// ecran dans un autre etat, et le retour se fait par un bouton qui nomme ce
// vers quoi il revient.
//

/// Ce que l ecran Rechercher affiche.
///
/// Non `Sendable`, comme `EtatDeContenu` qu il porte.
public enum EtatDeRecherche {
    /// Rien n a encore ete cherche. L ecran invite a taper.
    case invitation(EtatDeContenu)

    /// Une recherche court ou a rendu, avec une rangee par source.
    case resultats(ResultatsDeRecherche)
}

/// Ce que l ecran Rechercher declenche.
public struct CommandesDeRecherche {
    /// Ouvre la liste complete d une source, lien Tout voir.
    public let deplier: @MainActor (SourceID) -> Void

    /// Referme la liste complete et revient aux rangees.
    public let replier: @MainActor () -> Void

    /// Relance la seule source dont la rangee a echoue.
    public let reessayer: @MainActor (SourceID) -> Void

    /// Ouvre la fiche d une serie, nulle tant qu aucune fiche n est
    /// atteignable depuis cet ecran.
    ///
    /// La source voyage avec la serie. Un resultat ne porte que l identifiant
    /// que sa source lui donne, et deux sources peuvent rendre le meme : sans
    /// la source, la fiche ouverte serait celle d une autre serie.
    public let ouvrirLaSerie: (@MainActor (SourceID, MangaDistant) -> Void)?

    public init(
        deplier: @escaping @MainActor (SourceID) -> Void,
        replier: @escaping @MainActor () -> Void,
        reessayer: @escaping @MainActor (SourceID) -> Void,
        ouvrirLaSerie: (@MainActor (SourceID, MangaDistant) -> Void)?
    ) {
        self.deplier = deplier
        self.replier = replier
        self.reessayer = reessayer
        self.ouvrirLaSerie = ouvrirLaSerie
    }
}

/// Ecran Rechercher, section 5.4.
public struct VueDeRecherche: View {
    @Environment(\.palette) private var palette

    @Binding private var terme: String

    private let etat: EtatDeRecherche
    private let libelles: LibellesDeRecherche
    private let delaiEnSecondes: Int
    private let commandes: CommandesDeRecherche

    /// Construit l ecran.
    ///
    /// - Parameters:
    ///   - terme: texte du champ de la barre d outils, pilote par la session.
    ///   - etat: invitation ou resultats.
    ///   - libelles: libelles pris dans le catalogue de chaines.
    ///   - delaiEnSecondes: delai accorde a une source, ecrit dans la ligne
    ///     d erreur quand c est lui qui a expire. Il vient du registre, pas
    ///     d une constante posee ici : un message qui annoncerait un delai
    ///     different de celui applique serait pire que pas de message.
    ///   - commandes: ce que les liens de l ecran declenchent.
    public init(
        terme: Binding<String>,
        etat: EtatDeRecherche,
        libelles: LibellesDeRecherche,
        delaiEnSecondes: Int,
        commandes: CommandesDeRecherche
    ) {
        _terme = terme
        self.etat = etat
        self.libelles = libelles
        self.delaiEnSecondes = delaiEnSecondes
        self.commandes = commandes
    }

    public var body: some View {
        contenu
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                ToolbarItem {
                    ChampDeRecherche(
                        texte: $terme,
                        espaceReserve: libelles.espaceReserve,
                        etiquette: libelles.etiquetteDuChamp,
                        libelleDEffacement: libelles.effacerLaRecherche
                    )
                }
            }
    }

    @ViewBuilder
    private var contenu: some View {
        switch etat {
        case let .invitation(vide):
            VueDEtatDeContenu(vide)

        case let .resultats(resultats):
            resultat(resultats)
        }
    }

    @ViewBuilder
    private func resultat(_ resultats: ResultatsDeRecherche) -> some View {
        if resultats.aucuneSourceInterrogee {
            VueDEtatDeContenu(
                .vide(
                    symbole: Jetons.Icone.parcourir,
                    titre: libelles.aucuneSourceTitre,
                    phrase: libelles.aucuneSourcePhrase,
                    action: nil
                )
            )
        } else if resultats.toutesLesSourcesOntEchoue {
            // Une page de lignes d erreur empilees n aide personne. L ecran
            // bascule sur un etat unique, dont la reprise relance tout.
            VueDEtatDeContenu(
                .erreur(
                    titre: libelles.toutesLesSourcesTitre,
                    phrase: libelles.toutesLesSourcesPhrase,
                    reessayer: ActionDEtat(libelle: libelles.reessayer) {
                        for groupe in resultats.groupes {
                            commandes.reessayer(groupe.source)
                        }
                    },
                    repli: nil
                )
            )
        } else if resultats.aucunResultat {
            VueDEtatDeContenu(
                .vide(
                    symbole: Jetons.Icone.rechercher,
                    titre: libelles.aucunResultatTitre,
                    phrase: libelles.aucunResultatPhrase,
                    action: nil
                )
            )
        } else if let deplie = resultats.groupeDeplie {
            listeComplete(deplie)
        } else {
            rangees(resultats)
        }
    }

    // MARK: Rangees

    private func rangees(_ resultats: ResultatsDeRecherche) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Jetons.Recherche.ecartEntreGroupes) {
                ForEach(resultats.groupes) { groupe in
                    VueDeRangeeDeRecherche(
                        groupe: groupe,
                        libelles: libelles,
                        delaiEnSecondes: delaiEnSecondes,
                        toutVoir: { commandes.deplier(groupe.source) },
                        reessayer: { commandes.reessayer(groupe.source) },
                        ouvrirLaSerie: commandes.ouvrirLaSerie.map { ouvrir in
                            { serie in ouvrir(groupe.source, serie) }
                        },
                        vignette: { _ in VignetteDeResultat() }
                    )
                }
            }
            .padding(Jetons.Recherche.margeLaterale)
        }
    }

    // MARK: Liste complete d une source

    /// La grille complete d une source, ouverte par le lien Tout voir.
    private func listeComplete(_ groupe: GroupeDeRecherche) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            enTeteDeListeComplete(groupe)

            ScrollView {
                LazyVGrid(columns: colonnes, spacing: Jetons.Recherche.ecartEntreGroupes) {
                    ForEach(groupe.resultats, id: \.identifiant) { serie in
                        VueDeCarteDeResultat(
                            serie: serie,
                            ouvrir: commandes.ouvrirLaSerie.map { ouvrir in
                                { ouvrir(groupe.source, serie) }
                            },
                            vignette: { VignetteDeResultat() }
                        )
                    }
                }
                .padding(Jetons.Recherche.margeLaterale)
            }
        }
    }

    private func enTeteDeListeComplete(_ groupe: GroupeDeRecherche) -> some View {
        HStack(spacing: Jetons.Recherche.ecartAvantLeCompteur) {
            Button {
                commandes.replier()
            } label: {
                Label(
                    libelles.retourAuxResultats,
                    systemImage: Jetons.IconeDeRecherche.retour
                )
            }
            .buttonStyle(BoutonDiscret(style: Jetons.Recherche.lienToutVoir))

            Text(groupe.nom)
                .style(Jetons.Recherche.nomDeSource)
                .foregroundStyle(palette.textes.primary.couleur)
                .accessibilityAddTraits(.isHeader)

            if let compteur = TexteDeRecherche.compteur(de: groupe, libelles: libelles) {
                Text(compteur)
                    .style(Jetons.Recherche.compteurDeResultats, chiffresTabulaires: true)
                    .foregroundStyle(palette.textes.tertiary.couleur)
            }

            Spacer(minLength: 0)
        }
        .lineLimit(1)
        .padding(.horizontal, Jetons.Recherche.margeLaterale)
        .padding(.vertical, Jetons.Espace.x3)
    }

    /// Colonnes de la grille depliee, a la largeur d une vignette.
    private var colonnes: [GridItem] {
        [
            GridItem(
                .adaptive(minimum: Jetons.Recherche.largeurDeVignette),
                spacing: Jetons.Recherche.gouttiereEntreVignettes,
                alignment: .topLeading
            ),
        ]
    }
}

/// Couverture d un resultat, en attendant que les vignettes soient chargees.
///
/// Le meme aplat que les cartes de la bibliotheque, et pour la meme raison :
/// une grille dont les cartes changent de taille quand les images arrivent
/// saute sous le doigt pendant le defilement.
struct VignetteDeResultat: View {
    @Environment(\.palette) private var palette

    var body: some View {
        Rectangle()
            .fill(palette.surfaces.card.couleur)
    }
}
