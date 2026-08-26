import Core
import ImagePipeline
import Testing
@testable import ReaderEngine

/// Couvre la pile de tuiles du mode webtoon, sections 7.1 et 7.3.
///
/// Deux choses sont mesurees ici. La geometrie d abord : les tuiles d une page
/// couvrent la page exactement, l espacement entre pages reste intact, et les
/// rangs se suivent du haut du chapitre au bas. Le budget ensuite : quel que
/// soit l endroit du chapitre et quel que soit le sens du defilement, le nombre
/// de tuiles montees ne depasse jamais le budget annonce, et le pool ne cree
/// jamais une vue de plus.
///
/// Le chapitre de reference melange des bandes tres longues et des pages
/// courtes. Une pile de bandes identiques laisserait passer un budget calcule
/// sur une moyenne, qui tiendrait partout sauf a l endroit ou la bande la plus
/// longue croise la fenetre.
struct PileDeTuilesTests {
    private let hauteurDeLaFenetre: Double = 900

    /// Tuilage de la chaine d images, celui de la section 7.3.
    private let tuilage = TuilageDImageLongue.parDefaut

    // MARK: Geometrie

    @Test("Les tuiles d une page couvrent la page exactement")
    func couvertureDUnePage() {
        let pile = PileDeTuiles(
            pile: DefilementContinu(hauteurs: [4000], interstice: 0),
            partsParPage: [[1, 1, 1, 1]]
        )

        #expect(pile.nombreDeTuiles == 4)
        #expect(pile.debut(deRang: 0) == 0)

        for rang in 0..<pile.nombreDeTuiles {
            #expect(pile.hauteur(deRang: rang) == 1000)
            #expect(pile.debut(deRang: rang) == Double(rang) * 1000)
        }
    }

    @Test("Des parts inegales donnent des tuiles proportionnelles")
    func partsInegales() {
        let pile = PileDeTuiles(
            pile: DefilementContinu(hauteurs: [3000], interstice: 0),
            partsParPage: [[2, 1]]
        )

        #expect(pile.hauteur(deRang: 0) == 2000)
        #expect(pile.hauteur(deRang: 1) == 1000)
    }

    @Test("L espacement entre pages n est jamais mange par les tuiles")
    func espacementPreserve() {
        let espacement = EspacementEntrePages(points: 12)
        let pages = DefilementContinu(hauteurs: [2000, 3000], interstice: espacement.interstice)
        let pile = PileDeTuiles(pile: pages, partsParPage: [[1, 1], [1, 1, 1]])

        let derniereDeLaPremiere = pile.debut(deRang: 1) + pile.hauteur(deRang: 1)

        #expect(derniereDeLaPremiere == pages.debut(dePage: 0) + pages.hauteur(dePage: 0))
        #expect(pile.debut(deRang: 2) == pages.debut(dePage: 1))
        #expect(pile.debut(deRang: 2) - derniereDeLaPremiere == espacement.interstice)
    }

    @Test("La derniere tuile d une page finit exactement au bas de la page")
    func derniereTuileSansDerive() {
        let hauteurs = (0..<40).map { Double(1000 + $0 * 37) }
        let pages = DefilementContinu(hauteurs: hauteurs, interstice: 8)
        let pile = PileDeTuiles(pile: pages, partsParPage: hauteurs.map { _ in [1, 1, 1, 1, 1, 1, 1] })

        for page in 0..<pages.nombreDePages {
            guard let rang = pile.rang(page: page, tuile: 6) else {
                Issue.record("page \(page) sans septieme tuile")
                continue
            }

            let bas = pile.debut(deRang: rang) + pile.hauteur(deRang: rang)

            #expect(abs(bas - (pages.debut(dePage: page) + pages.hauteur(dePage: page))) < 1e-9)
        }
    }

    @Test("Une page sans part declaree compte pour une tuile unique")
    func pageSansPart() {
        let pages = DefilementContinu(hauteurs: [1500, 1500], interstice: 0)
        let pile = PileDeTuiles(pile: pages, partsParPage: [[1, 1]])

        #expect(pile.tuilesParPage == [2, 1])
        #expect(pile.hauteur(deRang: 2) == 1500)
    }

    @Test("Un rang et une adresse se repondent sur tout le chapitre")
    func rangEtAdresse() {
        let pile = PileDeTuiles(
            pile: DefilementContinu(hauteurs: Array(repeating: 2000, count: 12), interstice: 4),
            partsParPage: (0..<12).map { Array(repeating: 1.0, count: 1 + $0 % 4) }
        )

        for rang in 0..<pile.nombreDeTuiles {
            guard let adresse = pile.adresse(deRang: rang) else {
                Issue.record("rang \(rang) sans adresse")
                continue
            }

            #expect(pile.rang(page: adresse.page, tuile: adresse.tuile) == rang)
        }

        #expect(pile.adresse(deRang: pile.nombreDeTuiles) == nil)
        #expect(pile.rang(page: 0, tuile: 99) == nil)
        #expect(pile.rang(page: 99, tuile: 0) == nil)
    }

    @Test("Un chapitre vide ne porte aucune tuile")
    func chapitreVide() {
        let pile = PileDeTuiles(pile: DefilementContinu(hauteurs: []), partsParPage: [])

        #expect(pile.estVide)
        #expect(pile.nombreDeTuiles == 0)
        #expect(pile.tuilesVisibles(auDecalage: 0, hauteurDeLaFenetre: hauteurDeLaFenetre).isEmpty)
        #expect(pile.fenetreDeTuiles(auDecalage: 0, hauteurDeLaFenetre: hauteurDeLaFenetre, budget: 8).isEmpty)
        #expect(pile.budgetDeTuiles(hauteurDeLaFenetre: hauteurDeLaFenetre) == 0)
    }

    // MARK: Visibilite

    @Test("Les tuiles visibles sont celles qui touchent la fenetre")
    func tuilesVisibles() {
        let pile = PileDeTuiles(
            pile: DefilementContinu(hauteurs: [8000], interstice: 0),
            partsParPage: [Array(repeating: 1.0, count: 8)]
        )

        #expect(pile.tuilesVisibles(auDecalage: 0, hauteurDeLaFenetre: 1000) == 0..<1)
        #expect(pile.tuilesVisibles(auDecalage: 0, hauteurDeLaFenetre: 1001) == 0..<2)
        #expect(pile.tuilesVisibles(auDecalage: 2500, hauteurDeLaFenetre: 1000) == 2..<4)
    }

    @Test("Une fenetre calee sur le debut d une tuile ne montre pas la precedente")
    func bordExclusif() {
        let pile = PileDeTuiles(
            pile: DefilementContinu(hauteurs: [4000], interstice: 0),
            partsParPage: [Array(repeating: 1.0, count: 4)]
        )

        #expect(pile.tuilesVisibles(auDecalage: 1000, hauteurDeLaFenetre: 1000) == 1..<2)
    }

    // MARK: Budget de tuiles vivantes

    @Test("Le budget de tuiles n est jamais depasse sur un chapitre de webtoon")
    func budgetJamaisDepasse() {
        let pile = chapitreDeWebtoon()
        let budget = pile.budgetDeTuiles(hauteurDeLaFenetre: hauteurDeLaFenetre)

        var pool = RecyclageDeVues(capacite: budget)
        var largeurs: Set<Int> = []

        for decalage in stride(from: 0.0, through: pile.pile.hauteurTotale, by: 79) {
            let fenetre = pile.fenetreDeTuiles(
                auDecalage: decalage,
                hauteurDeLaFenetre: hauteurDeLaFenetre,
                budget: budget
            )

            pool.mettreAJour(fenetre: fenetre)
            largeurs.insert(fenetre.count)

            #expect(fenetre.count <= budget)
            #expect(pool.nombreDeVuesVivantes <= budget)
            #expect(pool.nombreDeVuesCreees <= budget)
        }

        #expect(largeurs == [budget])
    }

    @Test("Toute tuile visible est montee pendant le defilement")
    func tuilesVisiblesToujoursMontees() {
        let pile = chapitreDeWebtoon()
        let budget = pile.budgetDeTuiles(hauteurDeLaFenetre: hauteurDeLaFenetre)

        var pool = RecyclageDeVues(capacite: budget)

        for decalage in stride(from: 0.0, through: pile.pile.hauteurTotale, by: 53) {
            pool.mettreAJour(
                fenetre: pile.fenetreDeTuiles(
                    auDecalage: decalage,
                    hauteurDeLaFenetre: hauteurDeLaFenetre,
                    budget: budget
                )
            )

            for tuile in pile.tuilesVisibles(auDecalage: decalage, hauteurDeLaFenetre: hauteurDeLaFenetre) {
                #expect(pool.vue(pourPage: tuile) != nil, "tuile \(tuile) non montee au decalage \(decalage)")
            }
        }
    }

    @Test("Une remontee du chapitre ne cree aucune tuile supplementaire")
    func remonteeSansCreation() {
        let pile = chapitreDeWebtoon()
        let budget = pile.budgetDeTuiles(hauteurDeLaFenetre: hauteurDeLaFenetre)

        var pool = RecyclageDeVues(capacite: budget)

        for decalage in stride(from: 0.0, through: pile.pile.hauteurTotale, by: 137) {
            pool.mettreAJour(fenetre: fenetre(de: pile, auDecalage: decalage, budget: budget))
        }

        for decalage in stride(from: pile.pile.hauteurTotale, through: 0, by: -137) {
            pool.mettreAJour(fenetre: fenetre(de: pile, auDecalage: decalage, budget: budget))
        }

        #expect(pool.nombreDeVuesCreees == budget)
        #expect(pool.nombreDeVuesVivantes == budget)
    }

    @Test("Le budget garde une tuile en avance sur ce qui est visible")
    func tuileEnAvance() {
        let pile = chapitreDeWebtoon()
        let budget = pile.budgetDeTuiles(hauteurDeLaFenetre: hauteurDeLaFenetre)
        let sansAvance = pile.budgetDeTuiles(hauteurDeLaFenetre: hauteurDeLaFenetre, enAvance: 0)

        #expect(budget == sansAvance + PileDeTuiles.tuilesEnAvance)

        let visibles = pile.tuilesVisibles(auDecalage: 0, hauteurDeLaFenetre: hauteurDeLaFenetre)
        let montees = pile.fenetreDeTuiles(auDecalage: 0, hauteurDeLaFenetre: hauteurDeLaFenetre, budget: budget)

        #expect(montees.upperBound > visibles.upperBound)
    }

    @Test("Le budget colle au pire cas de la pile, ni au dessus ni en dessous")
    func budgetColleAuPireCas() {
        let pile = chapitreDeWebtoon()
        var pire = 0

        // Le pire cas d une tuile donnee n est pas la fenetre calee sur son
        // debut, mais la fenetre qui n en montre plus qu un filet : elle descend
        // alors aussi loin que possible dans la pile.
        for rang in 0..<pile.nombreDeTuiles {
            let filet = pile.debut(deRang: rang) + pile.hauteur(deRang: rang) - 1e-6

            pire = max(pire, pile.tuilesVisibles(auDecalage: filet, hauteurDeLaFenetre: hauteurDeLaFenetre).count)
        }

        #expect(pire > 3, "la pile de test doit contenir un cas ou la fenetre montre plusieurs tuiles")
        #expect(pile.budgetDeTuiles(hauteurDeLaFenetre: hauteurDeLaFenetre) == pire + PileDeTuiles.tuilesEnAvance)
    }

    @Test("Le budget ne depend pas de la longueur du chapitre")
    func budgetIndependantDeLaLongueur() {
        let court = chapitreDeWebtoon(nombreDeBandes: 4)
        let long = chapitreDeWebtoon(nombreDeBandes: 80)

        #expect(court.budgetDeTuiles(hauteurDeLaFenetre: hauteurDeLaFenetre)
            == long.budgetDeTuiles(hauteurDeLaFenetre: hauteurDeLaFenetre))
        #expect(long.nombreDeTuiles > court.nombreDeTuiles * 10)
    }

    @Test("Un chapitre plus court que le budget monte toutes ses tuiles sans plus")
    func chapitrePlusCourtQueLeBudget() {
        let pile = PileDeTuiles(
            pile: DefilementContinu(hauteurs: [1200], interstice: 0),
            partsParPage: [[1, 1]]
        )

        let fenetre = pile.fenetreDeTuiles(auDecalage: 0, hauteurDeLaFenetre: hauteurDeLaFenetre, budget: 12)

        #expect(fenetre == 0..<2)
    }

    // MARK: Construction depuis la chaine d images

    @Test("Une bande de 20000 pixels entre dans la pile avec ses dix tuiles")
    func pileConstruiteDepuisLesDecoupes() {
        let bande = TailleEnPixels(largeur: 800, hauteur: 20000)
        let decoupes = tuilage.decoupes(de: bande)
        let hauteurEnPoints = 10000.0

        let pile = PileDeTuiles(
            pile: DefilementContinu(hauteurs: [hauteurEnPoints], interstice: 0),
            decoupes: [decoupes]
        )

        #expect(pile.nombreDeTuiles == 10)
        #expect(pile.tuilesParPage == [10])

        // Les tuiles pleines pesent la meme part, la derniere porte le reste.
        #expect(abs(pile.hauteur(deRang: 0) - hauteurEnPoints * 2048 / 20000) < 1e-9)
        #expect(abs(pile.debut(deRang: 9) + pile.hauteur(deRang: 9) - hauteurEnPoints) < 1e-9)
    }

    @Test("Une bande de 20000 pixels ne fait jamais monter plus de tuiles que le budget")
    func budgetSurUneBandeDeVingtMille() {
        let bande = TailleEnPixels(largeur: 800, hauteur: 20000)
        let decoupes = tuilage.decoupes(de: bande)

        let pile = PileDeTuiles(
            pile: DefilementContinu(hauteurs: Array(repeating: 20000, count: 6), interstice: 12),
            decoupes: Array(repeating: decoupes, count: 6)
        )

        let budget = pile.budgetDeTuiles(hauteurDeLaFenetre: hauteurDeLaFenetre)
        var pool = RecyclageDeVues(capacite: budget)

        #expect(pile.nombreDeTuiles == 60)

        for decalage in stride(from: 0.0, through: pile.pile.hauteurTotale, by: 91) {
            pool.mettreAJour(fenetre: fenetre(de: pile, auDecalage: decalage, budget: budget))

            #expect(pool.nombreDeVuesVivantes <= budget)
        }

        #expect(pool.nombreDeVuesCreees == budget)
    }

    // MARK: Outils

    /// Fenetre a monter pour ce decalage.
    private func fenetre(de pile: PileDeTuiles, auDecalage decalage: Double, budget: Int) -> Range<Int> {
        pile.fenetreDeTuiles(auDecalage: decalage, hauteurDeLaFenetre: hauteurDeLaFenetre, budget: budget)
    }

    /// Chapitre de webtoon qui melange bandes longues, pages courtes et rapports
    /// d affichage differents.
    ///
    /// Le rapport compte autant que la longueur. Une bande de vingt mille pixels
    /// posee sur une colonne etroite occupe deux mille points, ses dix tuiles
    /// font alors deux cents points chacune et la fenetre en montre six a la
    /// fois. La meme bande posee a l echelle un pour un n en montre qu une. Un
    /// budget calcule sur le seul second cas serait faux d un facteur six
    /// exactement la ou le webtoon se lit.
    private func chapitreDeWebtoon(nombreDeBandes: Int = 20) -> PileDeTuiles {
        var hauteurs: [Double] = []
        var decoupes: [[DecoupeDeTuile]] = []

        for bande in 0..<nombreDeBandes {
            let (hauteurEnPixels, rapport) = Self.formatDeBande(bande)
            let taille = TailleEnPixels(largeur: 800, hauteur: hauteurEnPixels)

            hauteurs.append(Double(hauteurEnPixels) * rapport)
            decoupes.append(tuilage.decoupes(de: taille))
        }

        return PileDeTuiles(
            pile: DefilementContinu(hauteurs: hauteurs, interstice: EspacementEntrePages(points: 8).interstice),
            decoupes: decoupes
        )
    }

    /// Hauteur en pixels d une bande et rapport auquel la colonne la pose.
    private static func formatDeBande(_ bande: Int) -> (hauteur: Int, rapport: Double) {
        switch bande % 4 {
        case 0: (1400, 1)
        case 1: (20000, 0.1)
        case 2: (8000, 0.25)
        default: (12000, 0.5)
        }
    }
}
