import DesignSystem
import Foundation

//
// Libelles des notifications de nouveaux chapitres, F060.
//
// La section 6 de DESIGN-SPEC.md ne dessine pas de notification. Les deux
// libelles suivent donc ses regles d ecriture : voix active, la phrase dit ce
// qui vient de se passer, aucun point d exclamation, aucun tiret cadratin.
//
// Le motif du numero est celui du tableau 4.5, `Chapitre %@`, et non une
// seconde formulation : c est le meme objet nomme du meme mot, de la ligne de
// chapitre jusqu a l ecran de verrouillage.
//

extension Chaines {
    /// Notifications de nouveaux chapitres, section 9, ligne General.
    enum Notifications {
        static let unChapitre = String(localized: "notifications.chapitres.un")
        static let plusieursChapitres = String(localized: "notifications.chapitres.plusieurs")
    }
}

extension LibellesDeNotificationsDeChapitres {
    /// Textes des notifications, pris dans le catalogue de chaines.
    static var duCatalogue: LibellesDeNotificationsDeChapitres {
        LibellesDeNotificationsDeChapitres(
            unChapitre: Chaines.Notifications.unChapitre,
            plusieursChapitres: Chaines.Notifications.plusieursChapitres
        )
    }
}
