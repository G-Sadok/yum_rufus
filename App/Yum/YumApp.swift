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
    @State private var premium = SessionPremium()
    @State private var confidentialite: SessionDeConfidentialite
    @State private var premiereOuverture: SessionDePremiereOuverture

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
    }

    var body: some Scene {
        WindowGroup {
            CoquilleDeLApplication(
                etat: etat,
                historique: historique,
                premium: premium,
                confidentialite: confidentialite,
                premiereOuverture: premiereOuverture
            )
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
