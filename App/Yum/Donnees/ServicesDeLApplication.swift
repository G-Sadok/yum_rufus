import Core
import Foundation
import Observation
import Storage

//
// Ouverture de la base de donnees de l application.
//
// La base vit dans le dossier de support de l application, a cote de ce que
// l utilisateur n a pas a manipuler. Elle est ouverte une fois, au lancement,
// et migree par `BaseDeDonnees` elle meme.
//
// L echec d ouverture n est pas fatal : il devient l etat d erreur des ecrans
// qui ont besoin de la base, chacun nommant sa propre cause avec les libelles
// du tableau 6.4.
//

/// Ce que l application partage entre ses ecrans.
@MainActor
@Observable
final class ServicesDeLApplication {
    /// Base ouverte et migree, nulle quand l ouverture a echoue.
    private(set) var base: BaseDeDonnees?

    /// Nom du fichier de base, range dans le dossier de support.
    static let nomDuFichier = "bibliotheque.sqlite"

    /// Etat du mode incognito, partage avec les magasins qui ecrivent.
    ///
    /// Il est construit ici et non dans l ecran des reglages, parce que c est
    /// ici que les magasins sont construits. Un registre cree plus tard
    /// n atteindrait plus la couche qui ecrit, et le mode incognito n aurait
    /// d effet que sur la banniere.
    let incognito = RegistreDIncognito()

    /// Ouvre la base et retient l echec plutot que de le laisser remonter.
    init() {
        base = try? Self.ouvrir()
    }

    /// Construit les services autour d une base deja ouverte.
    ///
    /// Employe par les apercus et par les tests, qui travaillent en memoire.
    init(base: BaseDeDonnees?) {
        self.base = base
    }

    /// Magasin d historique, nul tant que la base n est pas ouverte.
    var historique: MagasinDHistorique? {
        base.map { MagasinDHistorique(base: $0, incognito: incognito) }
    }

    /// Magasin de progression, nul tant que la base n est pas ouverte.
    var progression: MagasinDeProgression? {
        base.map { MagasinDeProgression(base: $0, incognito: incognito) }
    }

    private static func ouvrir() throws -> BaseDeDonnees {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let dossier = support
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "Yum", isDirectory: true)

        return try BaseDeDonnees.surDisque(a: dossier.appendingPathComponent(nomDuFichier))
    }
}
