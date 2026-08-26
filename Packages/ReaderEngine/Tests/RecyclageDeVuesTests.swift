import Testing
@testable import ReaderEngine

/// Pool de vues du mode Defilement continu, section 7.1.
struct RecyclageDeVuesTests {
    private let hauteurDeLaFenetre: Double = 900

    @Test("Chaque page montee recoit une vue distincte")
    func unePageUneVue() {
        var pool = RecyclageDeVues(capacite: 5)
        pool.mettreAJour(fenetre: 0..<5)

        #expect(pool.pagesVivantes == [0, 1, 2, 3, 4])
        #expect(pool.nombreDeVuesVivantes == 5)
        #expect(Set(pool.pagesVivantes.compactMap { pool.vue(pourPage: $0) }).count == 5)
    }

    @Test("La vue rendue par la page sortante est reprise par la page entrante")
    func vueRendueEtReprise() {
        var pool = RecyclageDeVues(capacite: 4)
        pool.mettreAJour(fenetre: 0..<4)

        let vueDeLaPageZero = pool.vue(pourPage: 0)
        let changement = pool.mettreAJour(fenetre: 1..<5)

        #expect(changement.liberees == [AttributionDeVue(page: 0, vue: 0)])
        #expect(changement.attribuees == [AttributionDeVue(page: 4, vue: 0)])
        #expect(pool.vue(pourPage: 4) == vueDeLaPageZero)
        #expect(pool.nombreDeVuesCreees == 4)
    }

    @Test("Monter deux fois la meme fenetre ne deplace rien")
    func fenetreInchangee() {
        var pool = RecyclageDeVues(capacite: 4)
        pool.mettreAJour(fenetre: 2..<6)

        #expect(pool.mettreAJour(fenetre: 2..<6).estVide)
        #expect(pool.nombreDeVuesCreees == 4)
    }

    @Test("Une fenetre plus large que la capacite est ramenee a la capacite")
    func fenetreRameneeALaCapacite() {
        var pool = RecyclageDeVues(capacite: 3)
        pool.mettreAJour(fenetre: 0..<10)

        #expect(pool.fenetre == 0..<3)
        #expect(pool.nombreDeVuesVivantes == 3)
        #expect(pool.nombreDeVuesCreees == 3)
    }

    @Test("Une capacite nulle laisse quand meme une vue, jamais zero")
    func capacitePlancher() {
        var pool = RecyclageDeVues(capacite: 0)
        pool.mettreAJour(fenetre: 0..<4)

        #expect(pool.capacite == 1)
        #expect(pool.nombreDeVuesVivantes == 1)
    }

    @Test("Un aller retour sur le chapitre ne cree aucune vue supplementaire")
    func allerRetourSansCreation() {
        var pool = RecyclageDeVues(capacite: 6)
        pool.mettreAJour(fenetre: 0..<6)

        for _ in 0..<200 {
            for debut in 0..<40 {
                pool.mettreAJour(fenetre: debut..<(debut + 6))
            }

            for debut in stride(from: 39, through: 0, by: -1) {
                pool.mettreAJour(fenetre: debut..<(debut + 6))
            }
        }

        #expect(pool.nombreDeVuesCreees == 6)
        #expect(pool.nombreDeVuesVivantes == 6)
    }

    @Test("Le nombre de vues vivantes reste constant sur tout un chapitre long")
    func nombreDeVuesVivantesConstant() {
        let pile = DefilementContinu(hauteurs: Array(repeating: 1400, count: 300), interstice: 12)
        let capacite = pile.capaciteDeRecyclage(hauteurDeLaFenetre: hauteurDeLaFenetre)

        var pool = RecyclageDeVues(capacite: capacite)
        var comptesObserves: Set<Int> = []

        for decalage in stride(from: 0.0, through: pile.hauteurTotale, by: 97) {
            let fenetre = pile.fenetreDeRecyclage(
                auDecalage: decalage,
                hauteurDeLaFenetre: hauteurDeLaFenetre,
                capacite: capacite
            )

            pool.mettreAJour(fenetre: fenetre)
            comptesObserves.insert(pool.nombreDeVuesVivantes)

            #expect(pool.nombreDeVuesCreees <= capacite)
        }

        #expect(comptesObserves == [capacite])
        #expect(pool.nombreDeVuesCreees == capacite)
    }

    @Test("Toute page visible est montee pendant le defilement")
    func pagesVisiblesToujoursMontees() {
        let hauteurs = (0..<200).map { Double(900 + ($0 % 7) * 260) }
        let pile = DefilementContinu(hauteurs: hauteurs, interstice: 12)
        let capacite = pile.capaciteDeRecyclage(hauteurDeLaFenetre: hauteurDeLaFenetre)

        var pool = RecyclageDeVues(capacite: capacite)

        for decalage in stride(from: 0.0, through: pile.hauteurTotale, by: 61) {
            let fenetre = pile.fenetreDeRecyclage(
                auDecalage: decalage,
                hauteurDeLaFenetre: hauteurDeLaFenetre,
                capacite: capacite
            )

            pool.mettreAJour(fenetre: fenetre)

            let visibles = pile.pagesVisibles(auDecalage: decalage, hauteurDeLaFenetre: hauteurDeLaFenetre)

            for page in visibles {
                #expect(pool.vue(pourPage: page) != nil, "page \(page) non montee au decalage \(decalage)")
            }
        }

        #expect(pool.nombreDeVuesCreees == capacite)
    }

    @Test("La fenetre de recyclage garde la meme largeur du debut a la fin du chapitre")
    func largeurDeFenetreConstante() {
        let pile = DefilementContinu(hauteurs: Array(repeating: 1400, count: 120), interstice: 12)
        let capacite = pile.capaciteDeRecyclage(hauteurDeLaFenetre: hauteurDeLaFenetre)

        var largeurs: Set<Int> = []

        for decalage in stride(from: 0.0, through: pile.hauteurTotale, by: 53) {
            largeurs.insert(
                pile.fenetreDeRecyclage(
                    auDecalage: decalage,
                    hauteurDeLaFenetre: hauteurDeLaFenetre,
                    capacite: capacite
                ).count
            )
        }

        #expect(largeurs == [capacite])
    }

    @Test("Un chapitre plus court que la capacite monte toutes ses pages sans plus")
    func chapitrePlusCourtQueLaCapacite() {
        let pile = DefilementContinu(hauteurs: Array(repeating: 1400, count: 3), interstice: 12)
        let fenetre = pile.fenetreDeRecyclage(auDecalage: 0, hauteurDeLaFenetre: hauteurDeLaFenetre, capacite: 8)

        var pool = RecyclageDeVues(capacite: 8)
        pool.mettreAJour(fenetre: fenetre)

        #expect(fenetre == 0..<3)
        #expect(pool.nombreDeVuesCreees == 3)
    }
}
