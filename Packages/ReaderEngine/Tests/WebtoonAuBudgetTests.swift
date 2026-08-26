import Core
import Foundation
import ImagePipeline
import Testing
@testable import ReaderEngine

/// Mesure le cout par image du mode webtoon contre le budget de 120 images par
/// seconde de la section 12.
///
/// La mesure porte sur ce que le moteur refait a chaque image de defilement :
/// retrouver la tuile sous le bord haut, recalculer la fenetre de tuiles a
/// monter, et faire tourner le pool. Le rendu appartient a la couche vue, mais
/// aucun budget ne tient si cette part la deborde deja.
///
/// Le chapitre mesure est celui qui coute le plus cher : des bandes de vingt
/// mille pixels posees sur une colonne etroite, donc beaucoup de tuiles courtes,
/// donc une fenetre qui change presque a chaque image.
struct WebtoonAuBudgetTests {
    /// Budget d une image a 120 images par seconde.
    private let budgetParImage = Duration.nanoseconds(8_333_333)

    private let hauteurDeLaFenetre: Double = 900
    private let images = 1200

    @Test("Le defilement d un chapitre de webtoon tient le budget de 120 images par seconde")
    func chapitreDeWebtoonSousLeBudget() {
        let mesures = mesurer(nombreDeBandes: 60)

        verifier(mesures, sur: "un chapitre de 60 bandes")
    }

    @Test("Un chapitre dix fois plus long tient le meme budget")
    func chapitreTresLongSousLeBudget() {
        let mesures = mesurer(nombreDeBandes: 600)

        verifier(mesures, sur: "un chapitre de 600 bandes")
    }

    @Test("Le pool ne cree aucune tuile supplementaire pendant la mesure")
    func aucuneTuileCreeePendantLeDefilement() {
        let pile = chapitre(nombreDeBandes: 60)
        let budget = pile.budgetDeTuiles(hauteurDeLaFenetre: hauteurDeLaFenetre)
        var pool = RecyclageDeVues(capacite: budget)

        let pas = pile.pile.hauteurTotale / Double(images)

        for image in 0..<images {
            pool.mettreAJour(
                fenetre: pile.fenetreDeTuiles(
                    auDecalage: Double(image) * pas,
                    hauteurDeLaFenetre: hauteurDeLaFenetre,
                    budget: budget
                )
            )

            #expect(pool.nombreDeVuesVivantes == budget)
        }

        #expect(pool.nombreDeVuesCreees == budget)
    }

    /// Chapitre de bandes longues posees sur une colonne etroite.
    private func chapitre(nombreDeBandes: Int) -> PileDeTuiles {
        let tuilage = TuilageDImageLongue.parDefaut
        var hauteurs: [Double] = []
        var decoupes: [[DecoupeDeTuile]] = []

        for bande in 0..<nombreDeBandes {
            let hauteurEnPixels = 14000 + (bande % 7) * 1000
            let taille = TailleEnPixels(largeur: 800, hauteur: hauteurEnPixels)

            hauteurs.append(Double(hauteurEnPixels) * 0.1)
            decoupes.append(tuilage.decoupes(de: taille))
        }

        return PileDeTuiles(
            pile: DefilementContinu(hauteurs: hauteurs, interstice: EspacementEntrePages(points: 8).interstice),
            decoupes: decoupes
        )
    }

    /// Deroule un defilement complet et rend la duree de chaque image.
    private func mesurer(nombreDeBandes: Int) -> [Duration] {
        let pile = chapitre(nombreDeBandes: nombreDeBandes)
        let budget = pile.budgetDeTuiles(hauteurDeLaFenetre: hauteurDeLaFenetre)
        let pas = pile.pile.hauteurTotale / Double(images)

        var pool = RecyclageDeVues(capacite: budget)
        var mesures = [Duration](repeating: .zero, count: images)
        var tuilesVues = 0

        // Chauffe : la mesure porte sur le regime etabli, pas sur l ouverture du
        // chapitre, qui alloue les tables du pool.
        for image in 0..<200 {
            pool.mettreAJour(
                fenetre: pile.fenetreDeTuiles(
                    auDecalage: Double(image) * pas,
                    hauteurDeLaFenetre: hauteurDeLaFenetre,
                    budget: budget
                )
            )
        }

        for image in 0..<images {
            let decalage = Double(image) * pas

            let debut = ContinuousClock.now

            let fenetre = pile.fenetreDeTuiles(
                auDecalage: decalage,
                hauteurDeLaFenetre: hauteurDeLaFenetre,
                budget: budget
            )
            pool.mettreAJour(fenetre: fenetre)
            let visibles = pile.tuilesVisibles(auDecalage: decalage, hauteurDeLaFenetre: hauteurDeLaFenetre)

            mesures[image] = ContinuousClock.now - debut
            tuilesVues += visibles.count
        }

        #expect(tuilesVues > images)

        return mesures
    }

    /// Compare une serie de mesures au budget, image par image et sur la duree
    /// totale.
    private func verifier(_ mesures: [Duration], sur chapitre: String) {
        let total = mesures.reduce(Duration.zero, +)
        let pire = mesures.max() ?? .zero

        #expect(total < budgetParImage * mesures.count, "\(chapitre) : \(total) pour \(mesures.count) images")
        #expect(pire < budgetParImage, "\(chapitre) : pire image a \(pire)")
    }
}
