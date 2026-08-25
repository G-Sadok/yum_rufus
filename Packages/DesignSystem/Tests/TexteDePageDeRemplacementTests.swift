import Core
import Foundation
import Testing
@testable import DesignSystem

//
// Couvre la composition des textes de la page de remplacement, tableau 6.4.
//
// La regle de fin de section 6.4 est la seule chose qui compte ici : le nom
// cite dans une erreur est toujours la valeur reelle. Un titre qui annonce la
// page 1 pour la page 14, ou une phrase qui nomme JPEG pour un fichier WebP,
// envoie l utilisateur chercher au mauvais endroit.
//

struct TexteDePageDeRemplacementTests {
    private let libelles = LibellesDePageDeRemplacement(
        pageIllisible: "La page %lld est illisible",
        formatInconnu: "Le fichier contient une image que Yum ne sait pas ouvrir.",
        formatNonPrisEnCharge: "Le fichier est une image %@ que cet appareil ne sait pas ouvrir.",
        contenuIllisible: "Le fichier est une image %@ incomplete ou abimee.",
        sauterLaPage: "Sauter la page",
        signalerLeFichier: "Signaler le fichier"
    )

    @Test("Le titre nomme la page reellement en cause")
    func titreNommeLaPage() {
        let page = PageDeRemplacement(numeroDePage: 14, nomDeLEntree: "p14.jxl", cause: .formatInconnu)

        #expect(TexteDePageDeRemplacement.titre(de: page, libelles: libelles) == "La page 14 est illisible")
    }

    @Test("La phrase nomme le format quand l appareil ne sait pas le lire")
    func phraseNommeLeFormat() {
        let page = PageDeRemplacement(
            numeroDePage: 2,
            nomDeLEntree: "p2.jxl",
            cause: .formatNonPrisEnCharge(.jpegXL)
        )

        #expect(
            TexteDePageDeRemplacement.phrase(de: page, libelles: libelles)
                == "Le fichier est une image JPEG XL que cet appareil ne sait pas ouvrir."
        )
    }

    @Test("La phrase distingue un contenu abime d un format inconnu")
    func phraseDistingueLesCauses() {
        let abimee = PageDeRemplacement(numeroDePage: 3, nomDeLEntree: "p3.webp", cause: .contenuIllisible(.webp))
        let inconnue = PageDeRemplacement(numeroDePage: 4, nomDeLEntree: "p4.bin", cause: .formatInconnu)

        #expect(
            TexteDePageDeRemplacement.phrase(de: abimee, libelles: libelles)
                == "Le fichier est une image WebP incomplete ou abimee."
        )
        #expect(TexteDePageDeRemplacement.phrase(de: inconnue, libelles: libelles) == libelles.formatInconnu)
    }

    @Test("Un contenu abime dont le format est inconnu ne laisse pas de trou dans la phrase")
    func phraseSansFormat() {
        let page = PageDeRemplacement(numeroDePage: 5, nomDeLEntree: "p5.bin", cause: .contenuIllisible(nil))

        #expect(TexteDePageDeRemplacement.phrase(de: page, libelles: libelles) == libelles.formatInconnu)
    }

    @Test("Des dimensions illisibles nomment aussi le format")
    func dimensionsIllisibles() {
        let page = PageDeRemplacement(
            numeroDePage: 6,
            nomDeLEntree: "p6.svg",
            cause: .dimensionsIllisibles(.svg)
        )

        #expect(
            TexteDePageDeRemplacement.phrase(de: page, libelles: libelles)
                == "Le fichier est une image SVG incomplete ou abimee."
        )
    }
}
