import DesignSystem
import Foundation

//
// Libelles de la traduction des bulles, section 8 du cahier de developpement.
//
// Trois libelles sont ecrits, aucun n est invente au hasard.
//
// Le titre de la mention reprend le nom du moteur tel que le menu des reglages
// l ecrit, `IA dans le nuage`, ramene a la forme d un titre. Le meme mot pour la
// meme chose d un bout a l autre du parcours, regle d ecriture de la section 6
// de DESIGN-SPEC.md.
//
// La phrase dit ce qui sort, et elle nomme la chose exactement : ce qui part
// n est pas la page, c est le texte lu dans les bulles. Une formulation plus
// large ferait croire a l envoi de l image, une formulation plus vague ne
// dirait rien du tout, et la section 8 promet precisement que l image ne part
// pas.
//
// L etiquette d accessibilite porte les deux, parce que la section 7 interdit de
// transmettre une information par le seul glyphe et que la mention est lue comme
// un seul element.
//

extension Chaines {
    /// Traduction des bulles, section 8 du cahier de developpement.
    enum Traduction {
        static let nuageTitre = String(localized: "traduction.nuage.titre")
        static let nuagePhrase = String(localized: "traduction.nuage.phrase")
        static let nuageEtiquette = String(localized: "traduction.nuage.etiquette")
    }

    /// Textes de la traduction, dans la forme que le systeme de design attend.
    static var libellesDeTraduction: LibellesDeTraduction {
        LibellesDeTraduction(
            titreDuNuage: Traduction.nuageTitre,
            phraseDuNuage: Traduction.nuagePhrase,
            etiquetteDuNuage: Traduction.nuageEtiquette
        )
    }
}
