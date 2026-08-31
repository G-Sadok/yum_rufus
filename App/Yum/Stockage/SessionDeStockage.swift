import Core
import DesignSystem
import Foundation
import Sources
import Storage

//
// SessionDeStockage
//
// Porte l ecran Gestion du stockage, ouvert depuis la ligne de navigation de
// la section Stockage.
//
// L inventaire se mesure sur le disque, pas en base : ce que pesent les
// chapitres telecharges et les deux caches ne se deduit d aucune table. La
// pesee se fait donc hors du fil principal, un parcours de dossiers pouvant
// prendre le temps qu il veut sur une bibliotheque fournie.
//

@MainActor
@Observable
final class SessionDeStockage {
    private(set) var etat: EtatDeGestionDuStockage = .chargement

    private let inspecteur: InspecteurDeStockageSurDisque

    init(emplacements: EmplacementsDuStockage) {
        inspecteur = InspecteurDeStockageSurDisque(emplacements: emplacements)
    }

    func recharger() async {
        let inspecteur = inspecteur
        let inventaire = await Task.detached { inspecteur.inventaire() }.value

        etat = .chargee(inventaire)
    }

    func commandes(ouvrir: @escaping @MainActor (CategorieDeStockage) -> Void) -> CommandesDeStockage {
        CommandesDeStockage(ouvrir: ouvrir)
    }
}
