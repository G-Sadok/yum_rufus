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

    var body: some Scene {
        WindowGroup {
            CoquilleDeLApplication(etat: etat)
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
