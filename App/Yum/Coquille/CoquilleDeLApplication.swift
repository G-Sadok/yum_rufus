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

    /// Abonnement et mur premium.
    let premium: SessionPremium

    /// Mode incognito et verrouillage de l app, section 11.
    let confidentialite: SessionDeConfidentialite

    /// Parcours de premiere ouverture, section 5.10.
    let premiereOuverture: SessionDePremiereOuverture

    var body: some View {
        VueDeCoquille(
            etat: etat,
            entrees: entrees,
            appelPremium: appelPremium,
            ouvrirLeMurPremium: ouvrirLeMurPremium,
            libelleDuRepli: Chaines.Navigation.repli,
            actions: commandes(de:),
            contenu: contenu(de:)
        )
        .banniereDIncognito(confidentialite.banniere, etiquette: Chaines.Incognito.etiquette)
        // Le parcours d accueil se pose sous le mur premium et sous le verrou.
        // Sa troisieme etape peut ouvrir le mur, et le verrou passe avant tout
        // le reste, section 11.
        .premiereOuverture(
            premiereOuverture.parcours,
            libelles: .duCatalogue,
            libellesPremium: .duCatalogue,
            commandes: premiereOuverture.commandes
        )
        .murPremium(
            demande: premium.demande,
            etat: premium.mur,
            libelles: .duCatalogue,
            commandes: premium.commandes
        )
        // L ecran de verrouillage est pose en dernier, donc au dessus de tout le
        // reste, mur premium compris. Une feuille qui resterait lisible par
        // dessus le verrou annulerait le verrou.
        .verrouillageDeLApp(
            confidentialite.verrou.etat,
            ecran: confidentialite.ecranDeVerrouillage,
            libelles: .duCatalogue,
            deverrouiller: deverrouiller
        )
        .palette(theme: .defaut, apparence: .defaut)
        .modifier(TailleMinimaleDeFenetre())
        .task { await premium.rafraichirLAbonnement() }
        .task { ouvrirLeParcoursDAccueil() }
        .onChange(of: premiereOuverture.essaiDemande) { _, demande in
            if demande {
                premium.demander(.premiereOuverture)
            }
        }
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
    ///
    /// La demande d essai de la troisieme etape ouvre le mur premium par la
    /// meme porte que le bloc de la barre laterale. Le parcours ne vend rien
    /// lui meme, et la garde de `Core` reste seule a decider.
    private func ouvrirLeParcoursDAccueil() {
        premiereOuverture.ouvrirAuLancement()
    }

    /// Ouverture du mur depuis le bloc de la barre laterale, section 2.2.
    ///
    /// C est aujourd hui le seul point d entree du produit vers l achat. La
    /// section Abonnement de l ecran Reglages en ouvrira un second quand cet
    /// ecran sera livre, et passera par la meme demande.
    private func ouvrirLeMurPremium() {
        premium.demander(.appelDeLaBarreLaterale)
    }

    private func contenu(de destination: DestinationPrincipale) -> some View {
        VueDeDestination(destination: destination, historique: historique) { cible in
            etat.selectionner(cible)
        }
    }

    /// Commandes de barre d outils de la destination affichee.
    ///
    /// La section 5.2 pose `Effacer l historique` dans la barre d outils. Le
    /// bouton disparait quand l historique est deja vide : une commande qui n a
    /// rien a effacer n a rien a faire la, et l etat vide invite deja a agir
    /// ailleurs.
    @ViewBuilder
    private func commandes(de destination: DestinationPrincipale) -> some View {
        if destination == .historique, historique.porteDesEntrees {
            CommandeDeBarreDOutils(
                libelle: Chaines.Historique.effacer,
                symbole: Jetons.IconeDHistorique.effacer
            ) {
                historique.demanderLEffacement()
            }
        }
    }

    private var entrees: [EntreeDeNavigation] {
        DestinationPrincipale.allCases.map { destination in
            EntreeDeNavigation(destination: destination, libelle: Chaines.navigation(destination))
        }
    }

    private var appelPremium: AppelPremium {
        AppelPremium(titre: Chaines.Premium.titre, sousTitre: Chaines.Premium.sousTitre)
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
