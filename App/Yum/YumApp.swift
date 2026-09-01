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
    /// dependent sont construits avec elle. Un ecran qui ouvrirait la base a
    /// chaque apparition paierait la migration a chaque aller retour.
    ///
    /// La confidentialite est construite avec le registre d incognito des
    /// services, et non avec un registre neuf. C est ce qui relie l interrupteur
    /// de l ecran Reglages aux magasins qui ecrivent.
    init() {
        let services = ServicesDeLApplication()

        _services = State(initialValue: services)
        _historique = State(initialValue: EtatDHistorique(magasin: services.historique))
        _confidentialite = State(
            initialValue: SessionDeConfidentialite(registre: services.incognito)
        )
        _premiereOuverture = State(
            initialValue: SessionDePremiereOuverture(base: services.base)
        )
        _reglages = State(initialValue: SessionDeReglages(magasin: services.reglages))
        _statistiques = State(
            initialValue: SessionDeStatistiques(magasin: services.statistiques)
        )
        _stockage = State(
            initialValue: SessionDeStockage(emplacements: services.emplacementsDuStockage)
        )
        _prereglages = State(
            initialValue: SessionDePrereglages(magasin: services.prereglages)
        )
        let bibliotheque = SessionDeBibliotheque(magasin: services.categories)
        let sourcesVivantes = RegistreDesSourcesVivantes(
            magasin: services.sourcesInstallees,
            registre: services.sources
        )

        let serie = SessionDeNavigationDeSerie(magasin: services.ficheDeSerie)
        let couvertures = ChargeurDeCouvertures(
            resolution: services.resolutionDeChapitre,
            sources: sourcesVivantes
        )

        // L ordre compte : l ecran Parcourir previent la bibliotheque, le
        // registre et les couvertures, il doit donc etre construit apres eux.
        // Une source ajoutee devient interrogeable, et ses series montrent leur
        // couverture, sans relancer l application.
        _parcourir = State(
            initialValue: SessionDeParcourir(
                magasin: services.sourcesInstallees,
                importateur: services.importateur,
                sources: sourcesVivantes,
                apresImport: {
                    bibliotheque.recharger()
                    couvertures.vider()
                },
                sourcesOntChange: {
                    Task {
                        await sourcesVivantes.reconstruire()
                        couvertures.vider()
                    }
                }
            )
        )
        _bibliotheque = State(initialValue: bibliotheque)
        _serie = State(initialValue: serie)
        _sourcesVivantes = State(initialValue: sourcesVivantes)

        // Un resultat de recherche est range en bibliotheque avant que sa
        // fiche s ouvre : la fiche ne sait lire que la base.
        _recherche = State(
            initialValue: SessionDeRecherche(
                registre: sourcesVivantes,
                importateur: services.importateur,
                ouvrirLaFiche: { serie.ouvrir($0) },
                apresImport: {
                    bibliotheque.recharger()
                    couvertures.vider()
                }
            )
        )
        _couvertures = State(initialValue: couvertures)

        let lecture = SessionDeLecture(
            progression: services.progression,
            reglages: services.reglages
        ) {
            bibliotheque.recharger()
            serie.fiche?.charger()
        }

        _lecture = State(initialValue: lecture)
        _ouverture = State(
            initialValue: OuvertureDeChapitre(
                resolution: services.resolutionDeChapitre,
                sensDeLecture: services.sensDeLecture,
                sources: sourcesVivantes,
                lecture: lecture
            )
        )
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
