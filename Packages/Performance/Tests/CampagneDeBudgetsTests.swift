import Foundation
import Testing
@testable import BudgetsDePerformance

//
// CampagneDeBudgetsTests
//
// Les sept mesures doivent s executer, et refuser de mesurer sans corpus.
//
// Cette suite ne juge aucun budget. Les bornes de la section 12 se mesurent sur
// le corpus complet de 5000 series, dans un processus par budget, et c est le
// travail de scripts/budgets-performance.sh. Ce qui est verifie ici est ce qui
// rendrait ce travail inutile : une mesure qui ne s executerait pas, une mesure
// qui rendrait zero ou l infini, et surtout une campagne qui accepterait de
// mesurer sur un corpus absent, ce qui donnerait des durees minuscules et sept
// budgets tenus sans avoir rien mesure.
//

struct CampagneDeBudgetsTests {
    /// Corpus reduit, pose dans un dossier temporaire.
    ///
    /// Il compte plus de series que la fenetre de la grille n en affiche, sans
    /// quoi la mesure de defilement refuserait de tourner, et ses pages sont
    /// petites pour que la suite reste rapide. Tout le reste emprunte le meme
    /// chemin de code que le corpus de la section 12.
    private let reduit = ManifesteDuJeuDeTest(
        series: 120,
        chapitres: 1200,
        graine: ManifesteDuJeuDeTest.section12.graine,
        chapitresSurDisque: 1,
        pagesParChapitreSurDisque: 4,
        largeurDePage: 240,
        hauteurDePage: 360
    )

    @Test("Les sept mesures s executent et rendent une valeur exploitable", arguments: CleDeBudget.allCases)
    func mesureExploitable(cle: CleDeBudget) throws {
        let atelier = try Atelier(manifeste: reduit)
        defer { atelier.ranger() }

        let mesure = try atelier.campagne.mesurer(cle)

        #expect(mesure.cle == cle)
        #expect(mesure.valeur > 0, "\(cle.rawValue) a rendu \(mesure.valeur)")
        #expect(mesure.valeur.isFinite, "\(cle.rawValue) a rendu une valeur non finie")
        #expect(mesure.detail.isEmpty == false)
    }

    @Test(
        "Une mesure qui a besoin du corpus le refuse quand il manque",
        arguments: [
            CleDeBudget.lancementAFroid,
            CleDeBudget.ouvertureDeChapitreLocal,
            CleDeBudget.tourneDePage,
            CleDeBudget.defilementDeLaGrille,
            CleDeBudget.memoireEnLecture,
            CleDeBudget.memoireAuRepos,
        ]
    )
    func corpusAbsentRefuse(cle: CleDeBudget) throws {
        let racine = try Atelier.dossierTemporaire()
        defer { try? FileManager.default.removeItem(at: racine) }

        let emplacement = EmplacementDuJeuDeTest.parDefaut(racineDuDepot: racine)
        let campagne = CampagneDeBudgets(emplacement: emplacement, chronometre: Chronometre(passes: 1))

        #expect(throws: ErreurDeMesure.jeuDeTestAbsent(chemin: emplacement.genere.path)) {
            try campagne.mesurer(cle)
        }
    }

    @Test("La mesure du webtoon ne depend pas du corpus, elle depend du moteur")
    func webtoonSansCorpus() throws {
        let racine = try Atelier.dossierTemporaire()
        defer { try? FileManager.default.removeItem(at: racine) }

        let campagne = CampagneDeBudgets(
            emplacement: EmplacementDuJeuDeTest.parDefaut(racineDuDepot: racine),
            chronometre: Chronometre(passes: 1)
        )

        let mesure = try campagne.mesurer(.defilementWebtoon)

        #expect(mesure.valeur > 0)
    }

    @Test("Le chapitre de webtoon mesure depasse la limite de texture, donc il est tuile")
    func chapitreDeWebtoonTuile() {
        let pile = CampagneDeBudgets.chapitreDeWebtoon(bandes: 60)

        #expect(pile.nombreDeTuiles > 60)
        #expect(pile.pile.nombreDePages == 60)
    }

    /// Un corpus reduit materialise sur disque, et la campagne qui va avec.
    private struct Atelier {
        let racine: URL
        let campagne: CampagneDeBudgets

        init(manifeste: ManifesteDuJeuDeTest) throws {
            racine = try Self.dossierTemporaire()

            let emplacement = EmplacementDuJeuDeTest.parDefaut(racineDuDepot: racine)
            try GenerateurDeJeuDeTest.materialiser(manifeste, vers: emplacement)

            // Une seule passe : les bornes de la section 12 ne sont pas jugees
            // ici, et repeter la mesure du defilement cinq fois allongerait la
            // suite sans rien prouver de plus.
            campagne = CampagneDeBudgets(emplacement: emplacement, chronometre: Chronometre(passes: 1))
        }

        func ranger() {
            try? FileManager.default.removeItem(at: racine)
        }

        static func dossierTemporaire() throws -> URL {
            let dossier = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                .appendingPathComponent("campagne-\(UUID().uuidString)", isDirectory: true)

            try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)

            return dossier
        }
    }
}
