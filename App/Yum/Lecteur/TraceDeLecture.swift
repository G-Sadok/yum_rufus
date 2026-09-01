import Core
import Foundation
import Storage

//
// TraceDeLecture
//
// Ce que la lecture laisse derriere elle : la page atteinte, le chapitre
// marque lu, la ligne d historique et le comptage des statistiques.
//
// Elle vit a part de la session parce que ce sont deux sujets. La session
// decide ce qui s affiche, la trace decide ce qui se souvient, et le lecteur
// n a pas a savoir qu ecrire une position touche quatre tables.
//
// Un chapitre qui ne vient pas de la bibliotheque ne laisse rien. Un fichier
// pose par le systeme n a pas de ligne en base, donc rien a mettre a jour, et
// ce n est pas une erreur.
//

@MainActor
struct TraceDeLecture {
    private let progression: MagasinDeProgression?

    init(progression: MagasinDeProgression?) {
        self.progression = progression
    }

    /// Page ou reprendre, la premiere quand le chapitre est neuf ou inconnu.
    func pageDeReprise(_ chapitre: UUID?) -> Int {
        guard let chapitre, let progression else { return 0 }

        return (try? progression.position(duChapitre: chapitre))?.pageIndex ?? 0
    }

    /// Ecrit la position courante, quand il y a un chapitre a mettre a jour.
    ///
    /// Une page nulle n ecrit rien. C est le cas d un document qui n a pas pu
    /// s ouvrir : enregistrer la page zero y effacerait la progression reelle
    /// du chapitre, qui est ce que l utilisateur a de plus precieux.
    ///
    /// Un echec n interrompt pas la lecture et ne remonte a personne. La
    /// sauvegarde revient a chaque page, et une alerte a chaque echeance
    /// mettrait un message par dessus la page de manga.
    func enregistrer(chapitre: UUID?, page: Int?) {
        guard let chapitre, let page, let progression else { return }

        do {
            try progression.enregistrer(
                PositionDeLecture(chapitreId: chapitre, pageIndex: page)
            )
        } catch {
            NSLog("Progression : %@", String(describing: error))
        }
    }
}
