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

    /// Nombre de passes accordees avant de declarer le budget depasse.
    ///
    /// La mesure ne porte que sur du calcul, mais elle tourne dans un processus
    /// de test ou deux cent cinquante suites s executent de front. Une seule des
    /// mille deux cents images prise dans une preemption suffit a faire deborder
    /// la pire image, sans que rien du moteur ait bouge.
    ///
    /// Ce qui est accorde ici n est pas une image plus lente : le budget ne
    /// bouge pas, et une passe doit toujours le tenir image par image, jusqu a
    /// la pire. Ce qui est accorde est une seconde chance quand la machine a
    /// vole du temps a la premiere. Un moteur reellement trop lent depasse le
    /// budget a chaque passe, et echoue.
    private let passesAccordees = 5

    @Test("Le defilement d un chapitre de webtoon tient le budget de 120 images par seconde")
    func chapitreDeWebtoonSousLeBudget() {
        mesurerJusquAuBudget(nombreDeBandes: 60, sur: "un chapitre de 60 bandes")
    }

    @Test("Un chapitre dix fois plus long tient le meme budget")
    func chapitreTresLongSousLeBudget() {
        mesurerJusquAuBudget(nombreDeBandes: 600, sur: "un chapitre de 600 bandes")
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

    /// Deroule le defilement autant de fois qu il faut, puis juge la meilleure
    /// passe.
    ///
    /// La meilleure est celle dont la pire image est la moins lente : c est la
    /// passe la moins perturbee par le reste du processus, donc celle qui dit le
    /// plus honnetement ce que le moteur coute.
    private func mesurerJusquAuBudget(nombreDeBandes: Int, sur chapitre: String) {
        var meilleure = mesurer(nombreDeBandes: nombreDeBandes)

        for _ in 1..<passesAccordees where tientLeBudget(meilleure) == false {
            let autre = mesurer(nombreDeBandes: nombreDeBandes)

            if pire(de: autre) < pire(de: meilleure) {
                meilleure = autre
            }
        }

        verifier(meilleure, sur: chapitre)
    }

    /// La duree de l image la plus lente d une passe.
    private func pire(de mesures: [Duration]) -> Duration {
        mesures.max() ?? .zero
    }

    /// Vrai quand une passe tient le budget sur les deux plans.
    private func tientLeBudget(_ mesures: [Duration]) -> Bool {
        mesures.reduce(Duration.zero, +) < budgetParImage * mesures.count
            && pire(de: mesures) < budgetParImage
    }

    /// Compare une serie de mesures au budget, image par image et sur la duree
    /// totale.
    private func verifier(_ mesures: [Duration], sur chapitre: String) {
        let total = mesures.reduce(Duration.zero, +)

        #expect(total < budgetParImage * mesures.count, "\(chapitre) : \(total) pour \(mesures.count) images")
        #expect(pire(de: mesures) < budgetParImage, "\(chapitre) : pire image a \(pire(de: mesures))")
    }
}
