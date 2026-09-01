import Core
import Foundation
import Sources

//
// OuvertureDeFichierDuSysteme
//
// Ce que Yum fait de ce que le systeme lui pose : un clic droit, un glisser sur
// l icone, un double clic sur un fichier associe.
//
// Un fichier se lit. Un dossier depend de ce qu il contient. Un dossier de
// pages est un chapitre et se lit comme tel ; un dossier de series est une
// bibliotheque et s installe comme source.
//
// La distinction compte parce que le second cas est le plus courant. Un lecteur
// qui vient de decouvrir l application designe son dossier de mangas, pas un
// chapitre. Tout ouvrir dans le lecteur lui repondait que le dossier ne
// contenait aucune page, ce qui est vrai et inutile.
//

@MainActor
struct OuvertureDeFichierDuSysteme {
    /// Le lecteur, pour ce qui se lit.
    let lecture: SessionDeLecture

    /// L ecran Parcourir, pour ce qui s installe.
    let parcourir: SessionDeParcourir

    /// Ouvre une destination, pour montrer ou le contenu vient d arriver.
    let ouvrirLaDestination: (DestinationPrincipale) -> Void

    /// Traite ce que le systeme vient de poser.
    func ouvrir(_ url: URL) {
        guard estUnDossier(url) else {
            lecture.ouvrir(url)

            return
        }

        if LecteurDeConteneur.porteDesPages(url) {
            lecture.ouvrir(url)
        } else {
            parcourir.ajouterLeDossier(url)

            // La bibliotheque est ou le contenu arrive. Rester sur l ecran
            // courant laisserait croire que rien ne s est passe, l analyse
            // pouvant durer plusieurs secondes sans rien afficher ailleurs.
            ouvrirLaDestination(.bibliotheque)
        }
    }

    private func estUnDossier(_ url: URL) -> Bool {
        var estDossier: ObjCBool = false
        let existe = FileManager.default.fileExists(atPath: url.path, isDirectory: &estDossier)

        return existe && estDossier.boolValue
    }
}
