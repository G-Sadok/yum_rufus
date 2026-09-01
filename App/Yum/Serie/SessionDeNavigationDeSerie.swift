import Core
import Foundation
import Storage

//
// SessionDeNavigationDeSerie
//
// Tient la serie ouverte, quelle que soit la porte par laquelle on y entre :
// la grille de la bibliotheque, une ligne d historique ou un resultat de
// recherche.
//
// La fiche est reconstruite a chaque ouverture plutot que gardee en cache. Une
// fiche gardee montrerait la progression telle qu elle etait a la premiere
// visite, et le compteur de chapitres lus est precisement ce que l utilisateur
// vient verifier en y revenant.
//

@MainActor
@Observable
final class SessionDeNavigationDeSerie {
    /// Fiche ouverte, nulle quand aucune serie n est affichee.
    private(set) var fiche: EtatDeFicheDeSerie?

    private let magasin: MagasinDeFicheDeSerie?

    init(magasin: MagasinDeFicheDeSerie?) {
        self.magasin = magasin
    }

    /// Ouvre la fiche d une serie.
    func ouvrir(_ serie: UUID) {
        guard let magasin else { return }

        let etat = EtatDeFicheDeSerie(serie: serie, magasin: magasin)
        etat.charger()

        fiche = etat
    }

    func fermer() {
        fiche = nil
    }
}
