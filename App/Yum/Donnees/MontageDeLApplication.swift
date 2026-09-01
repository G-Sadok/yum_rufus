import Foundation

//
// MontageDeLApplication
//
// Construit une fois, au lancement, tout ce dont l interface a besoin.
//
// Le montage vit ici et non dans le point d entree parce qu il porte l ordre
// des dependances, qui est la seule chose difficile de cette construction : un
// ecran qui en previent un autre doit etre construit apres lui, et une source
// ajoutee doit devenir interrogeable sans relancer l application.
//
// Rien n est reconstruit ensuite. Un ecran qui rouvrirait la base a chaque
// apparition paierait la migration a chaque aller retour.
//

@MainActor
struct MontageDeLApplication {
    let services: ServicesDeLApplication
    let historique: EtatDHistorique
    let confidentialite: SessionDeConfidentialite
    let premiereOuverture: SessionDePremiereOuverture
    let reglages: SessionDeReglages
    let statistiques: SessionDeStatistiques
    let stockage: SessionDeStockage
    let prereglages: SessionDePrereglages
    let bibliotheque: SessionDeBibliotheque
    let sourcesVivantes: RegistreDesSourcesVivantes
    let serie: SessionDeNavigationDeSerie
    let couvertures: ChargeurDeCouvertures
    let parcourir: SessionDeParcourir
    let recherche: SessionDeRecherche
    let lecture: SessionDeLecture
    let ouverture: OuvertureDeChapitre

    init() {
        let services = ServicesDeLApplication()
        let contenu = Self.contenu(de: services)
        let lecture = Self.lecture(de: services, contenu: contenu)

        self.services = services
        historique = EtatDHistorique(magasin: services.historique)
        confidentialite = SessionDeConfidentialite(registre: services.incognito)
        premiereOuverture = SessionDePremiereOuverture(base: services.base)
        reglages = SessionDeReglages(magasin: services.reglages)
        statistiques = SessionDeStatistiques(magasin: services.statistiques)
        stockage = SessionDeStockage(emplacements: services.emplacementsDuStockage)
        prereglages = SessionDePrereglages(magasin: services.prereglages)
        bibliotheque = contenu.bibliotheque
        sourcesVivantes = contenu.sourcesVivantes
        serie = contenu.serie
        couvertures = contenu.couvertures
        parcourir = contenu.parcourir
        recherche = contenu.recherche
        self.lecture = lecture.session
        ouverture = lecture.ouverture
    }

    // MARK: Ecrans de contenu

    /// Les ecrans qui se previennent les uns les autres.
    struct Contenu {
        let bibliotheque: SessionDeBibliotheque
        let sourcesVivantes: RegistreDesSourcesVivantes
        let serie: SessionDeNavigationDeSerie
        let couvertures: ChargeurDeCouvertures
        let parcourir: SessionDeParcourir
        let recherche: SessionDeRecherche
    }

    /// Monte les ecrans de contenu dans l ordre de leurs dependances.
    ///
    /// L ecran Parcourir previent la bibliotheque, le registre et les
    /// couvertures : il est donc construit apres eux. Une source ajoutee
    /// devient interrogeable, et ses series montrent leur couverture, sans
    /// relancer l application.
    private static func contenu(de services: ServicesDeLApplication) -> Contenu {
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
        // Le type est ecrit : sans lui la fermeture est deduite sans isolement,
        // et la passer la ou un @MainActor est attendu devient une conversion
        // que la concurrence stricte refuse.
        let rafraichir: @MainActor () -> Void = {
            bibliotheque.recharger()
            couvertures.vider()
        }

        return Contenu(
            bibliotheque: bibliotheque,
            sourcesVivantes: sourcesVivantes,
            serie: serie,
            couvertures: couvertures,
            parcourir: SessionDeParcourir(
                magasin: services.sourcesInstallees,
                importateur: services.importateur,
                sources: sourcesVivantes,
                apresImport: rafraichir,
                sourcesOntChange: {
                    Task {
                        await sourcesVivantes.reconstruire()
                        couvertures.vider()
                    }
                }
            ),
            // Un resultat de recherche est range en bibliotheque avant que sa
            // fiche s ouvre : la fiche ne sait lire que la base.
            recherche: SessionDeRecherche(
                registre: sourcesVivantes,
                importateur: services.importateur,
                ouvrirLaFiche: { serie.ouvrir($0) },
                apresImport: rafraichir
            )
        )
    }

    // MARK: Lecture

    /// Le lecteur et ce qui lui ouvre un chapitre.
    struct Lecture {
        let session: SessionDeLecture
        let ouverture: OuvertureDeChapitre
    }

    /// Monte le lecteur, qui previent la grille et la fiche en se refermant.
    private static func lecture(
        de services: ServicesDeLApplication,
        contenu: Contenu
    ) -> Lecture {
        let session = SessionDeLecture(
            progression: services.progression,
            reglages: services.reglages
        ) {
            contenu.bibliotheque.recharger()
            contenu.serie.fiche?.charger()
        }

        return Lecture(
            session: session,
            ouverture: OuvertureDeChapitre(
                resolution: services.resolutionDeChapitre,
                sensDeLecture: services.sensDeLecture,
                sources: contenu.sourcesVivantes,
                lecture: session
            )
        )
    }
}
