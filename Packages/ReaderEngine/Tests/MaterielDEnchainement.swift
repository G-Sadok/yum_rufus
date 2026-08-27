import Core
import Foundation
import ImagePipeline
@testable import ReaderEngine

//
// MaterielDEnchainement
//
// Chapitres, rubans et attentes partages par les tests de l enchainement.
//
// Les deux suites qui suivent, celle du chargement et celle du marquage,
// montent le meme decor : une serie de chapitres courts, un chargeur pilote a la
// main, un marqueur espion. Le decor vit ici pour que chaque test ne montre que
// ce qu il verifie.
//

enum MaterielDEnchainement {
    /// Hauteur visible employee par tous les tests.
    static let hauteurDeLaFenetre: Double = 800

    /// Hauteur de l intercalaire, telle que la couche vue la passerait.
    static let intercalaire: Double = 96

    /// Suite de chapitres de deux pages, dans l ordre narratif.
    static func maillons(_ nombre: Int) -> [MaillonDeChapitre] {
        (0..<nombre).map {
            MaillonDeChapitre(id: UUID(), numero: Double($0 + 1), ordreDansSerie: $0, nombreDePages: 2)
        }
    }

    /// Chapitre lu en defilement continu.
    static func segmentContinu(
        _ maillon: MaillonDeChapitre,
        hauteurs: [Double] = [1000, 1000]
    ) -> SegmentDeChapitre {
        SegmentDeChapitre(
            chapitreId: maillon.id,
            numero: maillon.numero,
            pile: DefilementContinu(hauteurs: hauteurs)
        )
    }

    /// Chapitre de webtoon, bandes de vingt mille pixels decoupees en tuiles.
    static func segmentDeWebtoon(_ maillon: MaillonDeChapitre, bandes: Int = 2) -> SegmentDeChapitre {
        let tuilage = TuilageDImageLongue.parDefaut
        let taille = TailleEnPixels(largeur: 800, hauteur: 20000)
        let hauteurs = [Double](repeating: 2000, count: bandes)
        let decoupes = [[DecoupeDeTuile]](repeating: tuilage.decoupes(de: taille), count: bandes)

        return SegmentDeChapitre(
            chapitreId: maillon.id,
            numero: maillon.numero,
            tuiles: PileDeTuiles(pile: DefilementContinu(hauteurs: hauteurs), decoupes: decoupes)
        )
    }

    /// Enchainement monte sur ce decor.
    static func enchainement(
        suite: [MaillonDeChapitre],
        premier: SegmentDeChapitre,
        chargeur: ChargeurDeTest,
        marqueur: MarqueurEspion
    ) -> EnchainementDeChapitres {
        EnchainementDeChapitres(
            suite: SuiteDeChapitres(suite),
            premier: premier,
            chargeur: chargeur,
            marqueur: marqueur,
            intercalaire: intercalaire
        )
    }

    /// Attend que le ruban porte le nombre de chapitres demande.
    static func attendreLeRuban(de enchainement: EnchainementDeChapitres, chapitres: Int) async -> Bool {
        await Attente.jusqua {
            await enchainement.ruban.nombreDeChapitres == chapitres
        }
    }

    /// Attend que le chargeur ait recu le nombre de demandes attendu.
    ///
    /// La demande est enregistree par une tache detachee, que le systeme lance
    /// quand il veut. Observer son compte sans attendre rend un test qui passe
    /// sur une machine au repos et echoue sur une machine chargee.
    static func attendreLesDemandes(de chargeur: ChargeurDeTest, nombre: Int) async -> Bool {
        await Attente.jusqua {
            await chargeur.demandes.count == nombre
        }
    }
}
