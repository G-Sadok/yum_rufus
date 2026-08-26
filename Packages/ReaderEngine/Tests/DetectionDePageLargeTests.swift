import Core
import Testing
@testable import ReaderEngine

/// Couvre la detection des pages larges, celle qui decide qu une page occupe
/// l ecran seule en mode double page.
///
/// La detection ne devine rien : une page dont la taille est inconnue n est pas
/// declaree large. Une double page prise pour une page simple casse la paire
/// suivante, et une page simple prise pour une double laisse un vide a cote
/// d elle pendant tout le reste du chapitre.
struct DetectionDePageLargeTests {
    @Test("Une page plus large que haute est une page large")
    func pagePlusLargeQueHaute() {
        let detection = DetectionDePageLarge()

        #expect(detection.estLarge(TailleEnPixels(largeur: 3000, hauteur: 2000)))
        #expect(detection.estLarge(TailleEnPixels(largeur: 2001, hauteur: 2000)))
    }

    @Test("Une page de lecture ordinaire n est pas large")
    func pageOrdinaire() {
        let detection = DetectionDePageLarge()

        #expect(detection.estLarge(TailleEnPixels(largeur: 1600, hauteur: 2400)) == false)
        #expect(detection.estLarge(TailleEnPixels(largeur: 800, hauteur: 1200)) == false)
    }

    @Test("Une page carree n est pas large")
    func pageCarree() {
        let detection = DetectionDePageLarge()

        #expect(detection.estLarge(TailleEnPixels(largeur: 2000, hauteur: 2000)) == false)
    }

    @Test("Une taille inconnue ne declare jamais une page large")
    func tailleInconnue() {
        let detection = DetectionDePageLarge()

        #expect(detection.estLarge(.nulle) == false)
        #expect(detection.estLarge(TailleEnPixels(largeur: 1600, hauteur: 0)) == false)
        #expect(detection.estLarge(TailleEnPixels(largeur: 0, hauteur: 2400)) == false)
    }

    @Test("Le seuil se releve pour ne retenir que les vraies doubles pages")
    func seuilReleve() {
        let stricte = DetectionDePageLarge(seuil: 1.4)

        #expect(stricte.estLarge(TailleEnPixels(largeur: 2100, hauteur: 2000)) == false)
        #expect(stricte.estLarge(TailleEnPixels(largeur: 3000, hauteur: 2000)))
    }

    @Test("Un seuil sous un est ramene a un, faute de quoi tout serait large")
    func seuilTropBas() {
        #expect(DetectionDePageLarge(seuil: 0.2).seuil == DetectionDePageLarge.seuilParDefaut)
        #expect(DetectionDePageLarge(seuil: 0).seuil == DetectionDePageLarge.seuilParDefaut)
    }

    @Test("Les pages larges d un chapitre sont relevees par leur index")
    func relevePourUnChapitre() {
        let detection = DetectionDePageLarge()
        let tailles = [
            TailleEnPixels(largeur: 1600, hauteur: 2400),
            TailleEnPixels(largeur: 3200, hauteur: 2400),
            TailleEnPixels(largeur: 1600, hauteur: 2400),
            TailleEnPixels.nulle,
        ]

        #expect(detection.pagesLarges(parmi: tailles) == [1])
    }

    @Test("La detection alimente la composition en double page")
    func detectionEtComposition() {
        let detection = DetectionDePageLarge()
        let tailles = [
            TailleEnPixels(largeur: 1600, hauteur: 2400),
            TailleEnPixels(largeur: 1600, hauteur: 2400),
            TailleEnPixels(largeur: 3200, hauteur: 2400),
            TailleEnPixels(largeur: 1600, hauteur: 2400),
        ]

        let composition = CompositionEnDoublePage(
            nombreDePages: tailles.count,
            sens: .droiteGauche,
            decalage: .aucun,
            pagesLarges: detection.pagesLarges(parmi: tailles)
        )

        #expect(composition.paires.map(\.pages) == [[0, 1], [2], [3]])
        #expect(composition.paires.map(\.aLEcran) == [[1, 0], [2], [3]])
    }
}
