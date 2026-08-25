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

    /// La base est ouverte une fois, au lancement, et les etats d ecran qui en
    /// dependent sont construits avec elle. Un ecran qui ouvrirait la base a
    /// chaque apparition paierait la migration a chaque aller retour.
    init() {
        let services = ServicesDeLApplication()

        _services = State(initialValue: services)
        _historique = State(initialValue: EtatDHistorique(magasin: services.historique))
    }

    var body: some Scene {
        WindowGroup {
            CoquilleDeLApplication(etat: etat, historique: historique)
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
