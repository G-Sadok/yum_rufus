import Core
import Foundation
@testable import Intelligence

//
// DetecteursDeTest
//
// Detecteurs de cases synthetiques, dont la sortie exacte est connue.
//
// Aucune assertion utile ne peut porter sur un reseau entraine, et le fichier ne
// vit pas dans le depot. Les proprietes que la fonctionnalite promet ne portent
// pourtant pas sur le reseau : le seuil de confiance, la suppression des cadres
// qui se recouvrent, l ordre de lecture, le cache et la file serialisee vivent
// tous autour de lui. Ces detecteurs les rendent mesurables.
//
// Le detecteur fige compte ses appels. C est la mesure qui prouve qu une planche
// n est jamais passee deux fois dans le reseau, ce que la section 8 demande.
//

/// Detecteur qui rend toujours les memes cases, et compte ses appels.
final class DetecteurFige: ModeleDeDetectionDeCases, @unchecked Sendable {
    let identifiant: String

    /// Cases rendues a chaque appel.
    let rendues: [CaseDePage]

    private let verrou = NSLock()
    private var appels = 0

    init(identifiant: String = "detecteur-fige", rendues: [CaseDePage]) {
        self.identifiant = identifiant
        self.rendues = rendues
    }

    /// Nombre de passages reels dans le detecteur.
    var nombreDAppels: Int {
        verrou.lock()
        defer { verrou.unlock() }

        return appels
    }

    func detecter(_: MatriceDePixels) throws -> [CaseDePage] {
        verrou.lock()
        appels += 1
        verrou.unlock()

        return rendues
    }
}

/// Detecteur qui echoue toujours, comme un reseau refuse par l appareil.
struct DetecteurEnEchec: ModeleDeDetectionDeCases {
    let identifiant = "detecteur-en-echec"

    func detecter(_: MatriceDePixels) throws -> [CaseDePage] {
        throw ErreurDeTraitementIA.modeleEnEchec(identifiant: identifiant)
    }
}

/// Cases d une planche de test, dans les dispositions qui comptent.
enum CasesDeTest {
    /// Grille de quatre cases, la disposition la plus courante d une planche.
    static func grille(confiance: Double = 0.9) -> [CaseDePage] {
        [
            CaseDePage(abscisse: 0.55, ordonnee: 0.55, largeur: 0.4, hauteur: 0.4, confiance: confiance),
            CaseDePage(abscisse: 0.05, ordonnee: 0.05, largeur: 0.4, hauteur: 0.4, confiance: confiance),
            CaseDePage(abscisse: 0.05, ordonnee: 0.55, largeur: 0.4, hauteur: 0.4, confiance: confiance),
            CaseDePage(abscisse: 0.55, ordonnee: 0.05, largeur: 0.4, hauteur: 0.4, confiance: confiance),
        ].compactMap(\.self)
    }

    /// Case du haut a droite de la grille, premiere case en droite a gauche.
    static var hautDroite: CaseDePage? {
        CaseDePage(abscisse: 0.55, ordonnee: 0.05, largeur: 0.4, hauteur: 0.4, confiance: 0.9)
    }

    /// Case du haut a gauche de la grille, premiere case en gauche a droite.
    static var hautGauche: CaseDePage? {
        CaseDePage(abscisse: 0.05, ordonnee: 0.05, largeur: 0.4, hauteur: 0.4, confiance: 0.9)
    }
}
