import DesignSystem
import SwiftUI

//
// Point d entree de l application.
//
// La barre de titre native est masquee sur macOS : la section 2.1 demande une
// barre de titre unifiee avec la barre d outils, de 60 de haut, ce que la barre
// standard de 28 ne sait pas donner. Les feux de circulation restent natifs et
// a leur place, la coquille dessine le reste.
//

@main
struct YumApp: App {
    @State private var etat = EtatDeCoquille()
    @State private var services: ServicesDeLApplication
    @State private var historique: EtatDHistorique
    @State private var confidentialite: SessionDeConfidentialite
    @State private var premiereOuverture: SessionDePremiereOuverture
    @State private var reglages: SessionDeReglages
    @State private var statistiques: SessionDeStatistiques
    @State private var stockage: SessionDeStockage
    @State private var prereglages: SessionDePrereglages
    @State private var lecture: SessionDeLecture
    @State private var parcourir: SessionDeParcourir
    @State private var bibliotheque: SessionDeBibliotheque
    @State private var serie: SessionDeNavigationDeSerie
    @State private var sourcesVivantes: RegistreDesSourcesVivantes
    @State private var recherche: SessionDeRecherche
    @State private var ouverture: OuvertureDeChapitre
    @State private var couvertures: ChargeurDeCouvertures

    /// La base est ouverte une fois, au lancement, et les etats d ecran qui en
    /// dependent sont construits avec elle. Le montage porte l ordre de leurs
    /// dependances, qui est la seule chose difficile de cette construction.
    init() {
        let montage = MontageDeLApplication()

        _services = State(initialValue: montage.services)
        _historique = State(initialValue: montage.historique)
        _confidentialite = State(initialValue: montage.confidentialite)
        _premiereOuverture = State(initialValue: montage.premiereOuverture)
        _reglages = State(initialValue: montage.reglages)
        _statistiques = State(initialValue: montage.statistiques)
        _stockage = State(initialValue: montage.stockage)
        _prereglages = State(initialValue: montage.prereglages)
        _bibliotheque = State(initialValue: montage.bibliotheque)
        _sourcesVivantes = State(initialValue: montage.sourcesVivantes)
        _serie = State(initialValue: montage.serie)
        _couvertures = State(initialValue: montage.couvertures)
        _parcourir = State(initialValue: montage.parcourir)
        _recherche = State(initialValue: montage.recherche)
        _lecture = State(initialValue: montage.lecture)
        _ouverture = State(initialValue: montage.ouverture)
    }

    var body: some Scene {
        WindowGroup {
            CoquilleDeLApplication(
                etat: etat,
                historique: historique,
                confidentialite: confidentialite,
                premiereOuverture: premiereOuverture,
                reglages: reglages,
                statistiques: statistiques,
                stockage: stockage,
                prereglages: prereglages,
                lecture: lecture,
                parcourir: parcourir,
                bibliotheque: bibliotheque,
                couvertures: couvertures,
                recherche: recherche,
                ouverture: ouverture,
                serie: serie
            )
            // Ce que le systeme envoie quand on ouvre un fichier avec Yum,
            // depuis le clic droit ou par glisser sur l icone. Un dossier de
            // pages se lit, un dossier de series s installe comme source.
            .onOpenURL { url in
                OuvertureDeFichierDuSysteme(
                    lecture: lecture,
                    parcourir: parcourir,
                    ouvrirLaDestination: { etat.selectionner($0) }
                )
                .ouvrir(url)
            }
            // Les sources se reconstruisent une fois, au lancement. Les rebatir
            // a chaque requete relirait le trousseau a chaque frappe.
            //
            // Les couvertures sont oubliees ensuite, et pas avant : la grille
            // se dessine avant que les sources soient pretes, et une couverture
            // demandee a ce moment la ne trouve pas son fichier.
            .task {
                await sourcesVivantes.reconstruire()
                couvertures.vider()
            }
        }
        #if os(macOS)
        .defaultSize(
            width: Jetons.Fenetre.largeurParDefaut,
            height: Jetons.Fenetre.hauteurParDefaut
        )
        .windowStyle(.hiddenTitleBar)
        #endif
    }
}
