import Core
import Foundation

//
// TrousseauQuiRefuse
//
// Une trace qui echoue a chaque fois, pour eprouver ce qui arrive quand le
// trousseau du systeme refuse.
//
// Ce cas n a rien de theorique : un appareil qui n a pas ete deverrouille une
// fois depuis son demarrage refuse toute lecture, et c est precisement la
// contrepartie de l accessibilite apres premier deverrouillage exigee par la
// section 11. La suppression doit continuer son parcours malgre ce refus.
//

/// Trace qui leve l erreur qu on lui a donnee, a chaque effacement.
struct TrousseauQuiRefuse: TraceDeSource {
    let nomDeLaTrace = "trousseau"
    let erreur: any Error

    func effacer(_: SourceID) throws {
        throw erreur
    }
}
