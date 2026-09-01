import Core
import DesignSystem
import SwiftUI

//
// Assemblage de la coquille.
//
// L application ne fournit que ce qu elle est seule a connaitre : les libelles
// du catalogue de chaines et le contenu de chaque destination. Toute la
// geometrie et toutes les couleurs viennent du paquet DesignSystem.
//

/// Racine de l interface.
struct CoquilleDeLApplication: View {
    @Environment(\.scenePhase) private var phaseDeScene

    /// Etat de la navigation principale.
    let etat: EtatDeCoquille

    /// Etat de l ecran Historique, partage entre sa zone de contenu et la
    /// commande d effacement de la barre d outils.
    let historique: EtatDHistorique

    /// Mode incognito et verrouillage de l app, section 11.
    let confidentialite: SessionDeConfidentialite

    /// Parcours de premiere ouverture, section 5.10.
    let premiereOuverture: SessionDePremiereOuverture

    /// Colonne de reglages, section 5.5.
    let reglages: SessionDeReglages

    /// Ecrans ouverts depuis les lignes de navigation des reglages.
    let statistiques: SessionDeStatistiques
    let stockage: SessionDeStockage
    let prereglages: SessionDePrereglages

    /// Lecteur, pose par dessus la coquille quand un fichier est ouvert.
    let lecture: SessionDeLecture

    /// Ecran Parcourir, section 5.3.
    let parcourir: SessionDeParcourir

    /// Ecran Bibliotheque, section 5.1.
    let bibliotheque: SessionDeBibliotheque

    /// Couvertures des series, decodees a la demande.
    let couvertures: ChargeurDeCouvertures

    /// Ecran Rechercher, section 5.4.
    ///
    /// Liee : le champ de la barre d outils vit ici, pas dans l ecran, et il
    /// ecrit dans la session.
    @Bindable var recherche: SessionDeRecherche

    /// Ouvre un chapitre de la bibliotheque dans le lecteur.
    let ouverture: OuvertureDeChapitre

    /// Fiche de serie ouverte, section 5.6.
    let serie: SessionDeNavigationDeSerie

    var body: some View {
        VueDeCoquille(
            etat: etat,
            entrees: entrees,
            libelleDuRepli: Chaines.Navigation.repli,
            actions: commandes(de:),
            contenu: contenu(de:)
        )
        .banniereDIncognito(confidentialite.banniere, etiquette: Chaines.Incognito.etiquette)
        // Le parcours d accueil se pose sous le verrou, qui passe avant tout le
        // reste, section 11.
        .premiereOuverture(
            premiereOuverture.parcours,
            libelles: .duCatalogue,
            commandes: premiereOuverture.commandes
        )
        // L ecran de verrouillage est pose en dernier, donc au dessus de tout le
        // reste. Une feuille qui resterait lisible par dessus le verrou
        // annulerait le verrou.
        .verrouillageDeLApp(
            confidentialite.verrou.etat,
            ecran: confidentialite.ecranDeVerrouillage,
            libelles: .duCatalogue,
            deverrouiller: deverrouiller
        )
        .overlay {
            if let fiche = serie.fiche {
                EcranDeFicheDeSerie(
                    etat: fiche,
                    ouvrirLeChapitre: { [ouverture] chapitre in
                        Task { await ouverture.ouvrir(chapitre) }
                    },
                    revenir: { serie.fermer() }
                )
                .transition(.opacity)
            }
        }
        // Le lecteur couvre la coquille entiere : la these de la section 5.7
        // veut que rien d autre ne reste visible pendant la lecture.
        .overlay {
            if lecture.estOuvert {
                VueDeLecteur(
                    etat: lecture.etat,
                    libelles: lecture.libelles,
                    commandes: lecture.commandes
                )
                .transition(.opacity)
            }
        }
        .palette(theme: .defaut, apparence: .defaut)
        .modifier(TailleMinimaleDeFenetre())
        .task { ouvrirLeParcoursDAccueil() }
        .task { reglages.recharger() }
        .onChange(of: phaseDeScene) { _, nouvelle in
            suivreLaPhase(nouvelle)
        }
    }

    /// Cycle de vie de la scene, section 11.
    ///
    /// La regle des trente secondes vit dans `Core`. L application ne fait que
    /// lui dire quand elle part et quand elle revient, avec l heure.
    private func suivreLaPhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            confidentialite.revenirAuPremierPlan()

        case .inactive, .background:
            confidentialite.passerEnArrierePlan()

        @unknown default:
            break
        }
    }

    private func deverrouiller() {
        Task { await confidentialite.deverrouiller() }
    }

    /// Ouvre le parcours d accueil, au premier lancement et a lui seul.
    private func ouvrirLeParcoursDAccueil() {
        premiereOuverture.ouvrirAuLancement()
    }

    private func contenu(de destination: DestinationPrincipale) -> some View {
        VueDeDestination(
            destination: destination,
            historique: historique,
            parcourir: parcourir,
            bibliotheque: bibliotheque,
            couvertures: couvertures,
            recherche: recherche,
            ouverture: ouverture,
            serie: serie,
            reglages: reglages,
            statistiques: statistiques,
            stockage: stockage,
            prereglages: prereglages
        ) { cible in
            etat.selectionner(cible)
        }
    }

    /// Commandes de barre d outils de la destination affichee.
    ///
    /// Toutes passent par ici, et aucune par `.toolbar`. La coquille dessine sa
    /// propre barre : une commande posee dans la barre native de la fenetre
    /// atterrirait a cote des feux de circulation et y resterait visible
    /// pendant la lecture, ce que la section 5.7 interdit.
    ///
    /// La section 5.2 pose `Effacer l historique` dans la barre d outils. Le
    /// bouton disparait quand l historique est deja vide : une commande qui n a
    /// rien a effacer n a rien a faire la, et l etat vide invite deja a agir
    /// ailleurs.
    @ViewBuilder
    private func commandes(de destination: DestinationPrincipale) -> some View {
        switch destination {
        case .historique:
            if historique.porteDesEntrees {
                CommandeDeBarreDOutils(
                    libelle: Chaines.Historique.effacer,
                    symbole: Jetons.IconeDHistorique.effacer
                ) {
                    historique.demanderLEffacement()
                }
            }

        case .parcourir:
            MenuDAjoutDeSourceBouton(libelles: .duCatalogue) { type in
                parcourir.commandes.ajouter(type)
            }

        case .rechercher:
            ChampDeRecherche(
                texte: $recherche.terme,
                espaceReserve: Chaines.Recherche.espaceReserve,
                etiquette: Chaines.Recherche.etiquetteDuChamp,
                libelleDEffacement: Chaines.Recherche.effacer
            )

        case .bibliotheque, .reglages:
            EmptyView()
        }
    }

    private var entrees: [EntreeDeNavigation] {
        DestinationPrincipale.allCases.map { destination in
            EntreeDeNavigation(destination: destination, libelle: Chaines.navigation(destination))
        }
    }
}

/// Taille minimale de la fenetre, section 2.1.
///
/// La contrainte n a de sens que sur macOS. Sur iPhone et iPad la scene prend
/// la taille de l ecran, et imposer 1024 par 720 la rendrait defilante.
private struct TailleMinimaleDeFenetre: ViewModifier {
    func body(content: Content) -> some View {
        #if os(macOS)
            content.frame(
                minWidth: Jetons.Fenetre.largeurMinimale,
                minHeight: Jetons.Fenetre.hauteurMinimale
            )
        #else
            content
        #endif
    }
}
