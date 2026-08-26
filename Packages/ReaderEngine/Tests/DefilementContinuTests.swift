import Testing
@testable import ReaderEngine

/// Geometrie de la pile du mode Defilement continu, section 7.1.
struct DefilementContinuTests {
    private let interstice: Double = 12

    @Test("Un chapitre vide n a ni hauteur ni page visible")
    func chapitreVide() {
        let pile = DefilementContinu(hauteurs: [])

        #expect(pile.estVide)
        #expect(pile.nombreDePages == 0)
        #expect(pile.hauteurTotale == 0)
        #expect(pile.pagesVisibles(auDecalage: 0, hauteurDeLaFenetre: 900).isEmpty)
        #expect(pile.position(auDecalage: 250) == PositionDansLeDefilement(page: 0, fraction: 0))
    }

    @Test("Les debuts de page cumulent les hauteurs et les interstices")
    func debutsCumules() {
        let pile = DefilementContinu(hauteurs: [1000, 500, 2000], interstice: interstice)

        #expect(pile.debut(dePage: 0) == 0)
        #expect(pile.debut(dePage: 1) == 1012)
        #expect(pile.debut(dePage: 2) == 1524)
    }

    @Test("La hauteur totale ne compte aucun interstice apres la derniere page")
    func hauteurTotaleSansIntersticeFinal() {
        let pile = DefilementContinu(hauteurs: [1000, 500, 2000], interstice: interstice)

        #expect(pile.hauteurTotale == 3524)
    }

    @Test("Une pile d une seule page ne porte aucun interstice")
    func pageUniqueSansInterstice() {
        let pile = DefilementContinu(hauteurs: [800], interstice: interstice)

        #expect(pile.hauteurTotale == 800)
    }

    @Test("Le decalage se traduit en page et en fraction de cette page")
    func positionAuDecalage() {
        let pile = DefilementContinu(hauteurs: [1000, 500, 2000], interstice: interstice)

        #expect(pile.position(auDecalage: 0) == PositionDansLeDefilement(page: 0, fraction: 0))
        #expect(pile.position(auDecalage: 250) == PositionDansLeDefilement(page: 0, fraction: 0.25))
        #expect(pile.position(auDecalage: 1262) == PositionDansLeDefilement(page: 1, fraction: 0.5))
        #expect(pile.position(auDecalage: 2524) == PositionDansLeDefilement(page: 2, fraction: 0.5))
    }

    @Test("Un decalage tombe dans l interstice appartient a la page qui precede")
    func decalageDansLInterstice() {
        let pile = DefilementContinu(hauteurs: [1000, 500], interstice: interstice)
        let position = pile.position(auDecalage: 1006)

        #expect(position.page == 0)
        #expect(position.fraction == 1)
    }

    @Test("Un decalage hors de la pile est ramene dedans")
    func decalageBorne() {
        let pile = DefilementContinu(hauteurs: [1000, 500], interstice: interstice)

        #expect(pile.position(auDecalage: -400) == PositionDansLeDefilement(page: 0, fraction: 0))
        #expect(pile.position(auDecalage: 90000) == PositionDansLeDefilement(page: 1, fraction: 1))
    }

    @Test("Aller et retour entre decalage et position redonne le meme decalage")
    func allerRetourExact() {
        let pile = DefilementContinu(hauteurs: [1000, 500, 2000, 340])

        for decalage in stride(from: 0.0, through: pile.hauteurTotale, by: 37) {
            let retour = pile.decalage(pour: pile.position(auDecalage: decalage))

            #expect(abs(retour - decalage) < 1e-9, "decalage \(decalage) revenu a \(retour)")
        }
    }

    @Test("Un aller retour depuis l interstice retombe a la fin de la page qui precede")
    func allerRetourDepuisLInterstice() {
        let pile = DefilementContinu(hauteurs: [1000, 500], interstice: interstice)
        let retour = pile.decalage(pour: pile.position(auDecalage: 1006))

        #expect(retour == 1000)
    }

    @Test("Une page sans hauteur connue recoit un plancher, la fraction reste definie")
    func hauteurNulleRamenee() {
        let pile = DefilementContinu(hauteurs: [0, -20, 500])

        #expect(pile.hauteur(dePage: 0) == 1)
        #expect(pile.hauteur(dePage: 1) == 1)
        #expect(pile.position(auDecalage: 0).fraction.isNaN == false)
        #expect(pile.position(auDecalage: 1) == PositionDansLeDefilement(page: 1, fraction: 0))
    }

    @Test("La fenetre affichee rend toutes les pages qu elle touche")
    func pagesVisiblesDansLaFenetre() {
        let pile = DefilementContinu(hauteurs: Array(repeating: 400, count: 10))

        #expect(pile.pagesVisibles(auDecalage: 0, hauteurDeLaFenetre: 900) == 0..<3)
        #expect(pile.pagesVisibles(auDecalage: 200, hauteurDeLaFenetre: 900) == 0..<3)
        #expect(pile.pagesVisibles(auDecalage: 400, hauteurDeLaFenetre: 400) == 1..<2)
    }

    @Test("Une fenetre qui s arrete pile sur le debut d une page ne la montre pas")
    func bordBasExclusif() {
        let pile = DefilementContinu(hauteurs: Array(repeating: 400, count: 10))

        #expect(pile.pagesVisibles(auDecalage: 0, hauteurDeLaFenetre: 800) == 0..<2)
    }

    @Test("La capacite couvre le pire cas, la fenetre calee sur le bas d une page")
    func capaciteCouvreLePireCas() {
        // Fenetre de 900 sur des pages de 400 : un filet de la page 0 laisse
        // encore la place aux pages 1, 2 et un debut de 3.
        let pile = DefilementContinu(hauteurs: Array(repeating: 400, count: 20))
        let capacite = pile.capaciteDeRecyclage(hauteurDeLaFenetre: 900)

        var maximum = 0
        for decalage in stride(from: 0.0, through: pile.hauteurTotale, by: 7) {
            maximum = max(maximum, pile.pagesVisibles(auDecalage: decalage, hauteurDeLaFenetre: 900).count)
        }

        #expect(maximum == 4)
        #expect(capacite >= maximum)
        #expect(capacite == maximum + PlanDePrecharge.parDefaut.enAvant + PlanDePrecharge.parDefaut.enArriere)
    }

    @Test("Une page plus haute que la fenetre laisse une capacite minimale")
    func capaciteSurPageTresHaute() {
        let pile = DefilementContinu(hauteurs: Array(repeating: 18000, count: 5))

        // Deux pages au plus se touchent, a la charniere exacte entre les deux.
        #expect(pile.capaciteDeRecyclage(hauteurDeLaFenetre: 900) == 5)
    }
}
