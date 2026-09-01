import Core
import Foundation
import Storage

//
// OuvertureDeChapitre
//
// Ouvre un chapitre de la bibliotheque dans le lecteur.
//
// Trois couches se rencontrent ici, et aucune ne connait les deux autres. La
// base sait de quelle source vient un chapitre et sous quel identifiant, la
// source sait ou ce chapitre vit, et le lecteur sait ouvrir un fichier. Ce type
// est le seul endroit qui les traverse, ce qui evite de faire dependre le
// lecteur de la base ou la base des sources.
//
// Le sens de lecture est lu avant l ouverture, jamais apres. Le poser une fois
// le lecteur ouvert ferait paginer le chapitre dans le mauvais sens le temps
// d une image, ce qui est visible et faux.
//

@MainActor
final class OuvertureDeChapitre {
    /// Ce qui empeche un chapitre de s ouvrir.
    enum Refus: Equatable {
        /// La base ne connait pas ce chapitre.
        case chapitreInconnu

        /// La source n a pas de fichier a ouvrir pour ce chapitre.
        ///
        /// C est le cas de toute source a serveur : son chapitre se lit page
        /// par page par le reseau, ce que le lecteur ne sait pas encore faire.
        case pasDeFichierLocal
    }

    private let resolution: MagasinDeResolutionDeChapitre?
    private let sensDeLecture: MagasinDeSensDeLecture?
    private let sources: RegistreDesSourcesVivantes
    private let lecture: SessionDeLecture

    init(
        resolution: MagasinDeResolutionDeChapitre?,
        sensDeLecture: MagasinDeSensDeLecture?,
        sources: RegistreDesSourcesVivantes,
        lecture: SessionDeLecture
    ) {
        self.resolution = resolution
        self.sensDeLecture = sensDeLecture
        self.sources = sources
        self.lecture = lecture
    }

    /// Ouvre un chapitre, et dit ce qui l en a empeche.
    @discardableResult
    func ouvrir(_ chapitre: UUID) async -> Refus? {
        guard let resolution,
              let adresse = try? resolution.adresse(deChapitre: chapitre)
        else {
            return .chapitreInconnu
        }

        guard let fichier = await sources.fichier(de: adresse) else {
            return .pasDeFichierLocal
        }

        lecture.ouvrir(
            fichier,
            sens: sens(pourSerie: adresse.serieInterne),
            chapitre: chapitre
        )

        return nil
    }

    /// Sens de lecture de la serie, celui du reglage general a defaut.
    ///
    /// Une lecture impossible ne doit pas empecher l ouverture : le sens par
    /// defaut est un choix discutable, un chapitre qui ne s ouvre pas n en est
    /// pas un.
    private func sens(pourSerie serie: UUID) -> SensDeLecture {
        (try? sensDeLecture?.sens(pourSerie: serie)) ?? .parDefaut
    }
}
