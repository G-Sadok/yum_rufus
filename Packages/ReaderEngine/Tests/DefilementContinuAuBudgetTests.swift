import Foundation
import Testing
@testable import ReaderEngine

/// Mesure le cout par image du mode Defilement continu contre le budget de
/// 120 images par seconde de la section 12.
///
/// La mesure porte sur ce que le moteur refait a chaque image de defilement :
/// retrouver la page sous le bord haut, recalculer la fenetre a monter, faire
/// tourner le pool de vues et former la position de reprise. Le rendu lui meme
/// n est pas mesure ici, il appartient a la couche vue, mais aucun budget ne
/// tient si cette part la deborde deja.
///
/// Le defilement simule est plus dur que le reel : il traverse le chapitre
/// entier en mille deux cents images, donc la fenetre change a chaque image, la
/// ou un geste ordinaire la laisse souvent en place.
struct DefilementContinuAuBudgetTests {
    /// Budget d une image a 120 images par seconde.
    private let budgetParImage = Duration.nanoseconds(8_333_333)

    private let hauteurDeLaFenetre: Double = 900
    private let images = 1200

    @Test("Le defilement d un chapitre de 400 pages tient le budget de 120 images par seconde")
    func chapitreOrdinaireSousLeBudget() {
        let mesures = mesurer(nombreDePages: 400)

        verifier(mesures, sur: "un chapitre de 400 pages")
    }

    @Test("Un chapitre de 4000 pages tient le meme budget, le cout ne suit pas la longueur")
    func chapitreTresLongSousLeBudget() {
        let mesures = mesurer(nombreDePages: 4000)

        verifier(mesures, sur: "un chapitre de 4000 pages")
    }

    @Test("Le pool ne cree aucune vue supplementaire pendant la mesure")
    func aucuneVueCreeePendantLeDefilement() {
        let pile = construirePile(nombreDePages: 400)
        let capacite = pile.capaciteDeRecyclage(hauteurDeLaFenetre: hauteurDeLaFenetre)
        var pool = RecyclageDeVues(capacite: capacite)

        let pas = pile.hauteurTotale / Double(images)

        for image in 0..<images {
            pool.mettreAJour(
                fenetre: pile.fenetreDeRecyclage(
                    auDecalage: Double(image) * pas,
                    hauteurDeLaFenetre: hauteurDeLaFenetre,
                    capacite: capacite
                )
            )

            #expect(pool.nombreDeVuesVivantes == capacite)
        }

        #expect(pool.nombreDeVuesCreees == capacite)
    }

    /// Chapitre de hauteurs inegales, pour qu aucun calcul ne profite d une
    /// pile reguliere.
    private func construirePile(nombreDePages: Int) -> DefilementContinu {
        let hauteurs = (0..<nombreDePages).map { Double(1200 + ($0 % 11) * 160) }

        return DefilementContinu(hauteurs: hauteurs, interstice: 12)
    }

    /// Deroule un defilement complet et rend la duree de chaque image.
    private func mesurer(nombreDePages: Int) -> [Duration] {
        let pile = construirePile(nombreDePages: nombreDePages)
        let capacite = pile.capaciteDeRecyclage(hauteurDeLaFenetre: hauteurDeLaFenetre)
        let chapitre = UUID()
        let pas = pile.hauteurTotale / Double(images)

        var pool = RecyclageDeVues(capacite: capacite)
        var mesures = [Duration](repeating: .zero, count: images)
        var pagesVues = 0

        // Chauffe : la premiere image alloue les tables du pool, et la mesure
        // porte sur le regime etabli, pas sur l ouverture du chapitre.
        for image in 0..<200 {
            pool.mettreAJour(
                fenetre: pile.fenetreDeRecyclage(
                    auDecalage: Double(image) * pas,
                    hauteurDeLaFenetre: hauteurDeLaFenetre,
                    capacite: capacite
                )
            )
        }

        for image in 0..<images {
            let decalage = Double(image) * pas

            let debut = ContinuousClock.now

            let fenetre = pile.fenetreDeRecyclage(
                auDecalage: decalage,
                hauteurDeLaFenetre: hauteurDeLaFenetre,
                capacite: capacite
            )
            pool.mettreAJour(fenetre: fenetre)
            let position = pile.positionDeLecture(chapitreId: chapitre, auDecalage: decalage)

            mesures[image] = ContinuousClock.now - debut
            pagesVues += position.pageIndex
        }

        #expect(pagesVues > 0)

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
