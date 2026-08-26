import Core
import Testing
@testable import ReaderEngine

/// Couvre la composition des paires du mode double page, dans les deux sens de
/// lecture, avec et sans decalage de couverture, avec et sans page large.
///
/// La zone est listee comme non negociable par la strategie de test : une
/// composition juste en gauche a droite et fausse en droite a gauche se relit
/// sans rien voir en francais, et fait lire un manga a l envers.
///
/// Les bornes et les invariants vivent dans `InvariantsDeDoublePageTests`.
struct CompositionEnDoublePageTests {
    // MARK: Ordre a l ecran

    @Test("En droite a gauche, la premiere page de la paire occupe le bord droit")
    func premierePageADroiteEnDroiteGauche() {
        let composition = CompositionEnDoublePage(
            nombreDePages: 5,
            sens: .droiteGauche,
            decalage: .aucun
        )

        #expect(composition.paires.map(\.pages) == [[0, 1], [2, 3], [4]])
        #expect(composition.paires.map(\.aLEcran) == [[1, 0], [3, 2], [4]])
    }

    @Test("En gauche a droite, la premiere page de la paire occupe le bord gauche")
    func premierePageAGaucheEnGaucheDroite() {
        let composition = CompositionEnDoublePage(
            nombreDePages: 5,
            sens: .gaucheDroite,
            decalage: .aucun
        )

        #expect(composition.paires.map(\.pages) == [[0, 1], [2, 3], [4]])
        #expect(composition.paires.map(\.aLEcran) == [[0, 1], [2, 3], [4]])
    }

    @Test("Les deux sens composent les memes paires et les affichent en ordre inverse")
    func memesPairesOrdreInverse() {
        let pagesLarges: Set = [3]

        let droiteGauche = CompositionEnDoublePage(
            nombreDePages: 9,
            sens: .droiteGauche,
            decalage: .couvertureSeule,
            pagesLarges: pagesLarges
        )
        let gaucheDroite = CompositionEnDoublePage(
            nombreDePages: 9,
            sens: .gaucheDroite,
            decalage: .couvertureSeule,
            pagesLarges: pagesLarges
        )

        #expect(droiteGauche.paires.map(\.pages) == gaucheDroite.paires.map(\.pages))

        for (aDroite, aGauche) in zip(droiteGauche.paires, gaucheDroite.paires) {
            #expect(aDroite.aLEcran == aGauche.aLEcran.reversed())
        }
    }

    // MARK: Page large

    @Test("Une page large est affichee seule, dans les deux sens")
    func pageLargeAfficheeSeule() {
        for sens in [SensDeLecture.droiteGauche, .gaucheDroite] {
            let composition = CompositionEnDoublePage(
                nombreDePages: 6,
                sens: sens,
                decalage: .aucun,
                pagesLarges: [2]
            )

            let paireDeLaPageLarge = composition.paire(contenantLaPage: 2)

            #expect(paireDeLaPageLarge?.pages == [2], "Sens \(sens.rawValue)")
            #expect(paireDeLaPageLarge?.estSeule == true, "Sens \(sens.rawValue)")
            #expect(paireDeLaPageLarge?.motifDeLaPageSeule == .pageLarge, "Sens \(sens.rawValue)")
        }
    }

    @Test("Une page large decale la suite du chapitre au lieu de la casser")
    func pageLargeDecaleLaSuite() {
        let composition = CompositionEnDoublePage(
            nombreDePages: 6,
            sens: .gaucheDroite,
            decalage: .aucun,
            pagesLarges: [2]
        )

        #expect(composition.paires.map(\.pages) == [[0, 1], [2], [3, 4], [5]])
    }

    @Test("La page qui precede une page large reste seule plutot que d etre appariee avec elle")
    func voisineDUnePageLarge() {
        let composition = CompositionEnDoublePage(
            nombreDePages: 4,
            sens: .gaucheDroite,
            decalage: .aucun,
            pagesLarges: [1]
        )

        #expect(composition.paires.map(\.pages) == [[0], [1], [2, 3]])
        #expect(composition.paires.first?.motifDeLaPageSeule == .voisineLarge)
    }

    @Test("Deux pages larges consecutives restent deux pages seules")
    func deuxPagesLargesConsecutives() {
        let composition = CompositionEnDoublePage(
            nombreDePages: 4,
            sens: .droiteGauche,
            decalage: .aucun,
            pagesLarges: [1, 2]
        )

        #expect(composition.paires.map(\.pages) == [[0], [1], [2], [3]])
    }

    @Test("Un chapitre entierement compose de pages larges n apparie rien")
    func chapitreEntierementLarge() {
        let composition = CompositionEnDoublePage(
            nombreDePages: 3,
            sens: .droiteGauche,
            decalage: .aucun,
            pagesLarges: [0, 1, 2]
        )

        // La valeur est extraite avant d etre attendue : passer l appel a
        // allSatisfy directement a la macro la fait juger capable de lancer.
        let toutesSeules = composition.paires.allSatisfy(\.estSeule)

        #expect(toutesSeules)
        #expect(composition.paires.count == 3)
    }

    // MARK: Decalage de couverture

    @Test("Le decalage de couverture affiche la premiere page seule et decale toute la suite")
    func decalageDeCouverture() {
        let composition = CompositionEnDoublePage(
            nombreDePages: 6,
            sens: .droiteGauche,
            decalage: .couvertureSeule
        )

        #expect(composition.paires.map(\.pages) == [[0], [1, 2], [3, 4], [5]])
        #expect(composition.paires.first?.motifDeLaPageSeule == .couverture)
        #expect(composition.paires.first?.aLEcran == [0])
    }

    @Test("Sans decalage, la couverture est appariee avec la page suivante")
    func sansDecalage() {
        let composition = CompositionEnDoublePage(
            nombreDePages: 6,
            sens: .droiteGauche,
            decalage: .aucun
        )

        #expect(composition.paires.map(\.pages) == [[0, 1], [2, 3], [4, 5]])
    }

    @Test("Changer le decalage change toute la sequence qui suit")
    func leDecalageChangeToutLaSuite() {
        let avec = CompositionEnDoublePage(nombreDePages: 8, sens: .droiteGauche, decalage: .couvertureSeule)
        let sans = CompositionEnDoublePage(nombreDePages: 8, sens: .droiteGauche, decalage: .aucun)

        #expect(avec.paires != sans.paires)

        for page in 1..<7 {
            let dansAvec = avec.paire(contenantLaPage: page)?.pages
            let dansSans = sans.paire(contenantLaPage: page)?.pages

            #expect(dansAvec != dansSans, "La page \(page) doit changer de paire")
        }
    }

    @Test("Le decalage se reduit modulo deux, la composition n a que deux formes")
    func decalageReduitModuloDeux() {
        #expect(DecalageDeCouverture.normalise(0) == .aucun)
        #expect(DecalageDeCouverture.normalise(1) == .couvertureSeule)
        #expect(DecalageDeCouverture.normalise(2) == .aucun)
        #expect(DecalageDeCouverture.normalise(3) == .couvertureSeule)
        #expect(DecalageDeCouverture.normalise(-1) == .couvertureSeule)
        #expect(DecalageDeCouverture.normalise(-2) == .aucun)
    }
}
