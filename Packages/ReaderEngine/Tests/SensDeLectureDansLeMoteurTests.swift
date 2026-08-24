import Core
import Testing
@testable import ReaderEngine

/// Couvre tout ce que le sens de lecture gouverne dans le moteur : ordre des
/// pages a l ecran, ordre des moities apres division, direction du geste,
/// fleche clavier, sens du curseur et orientation des zones de toucher.
///
/// Chaque cas est ecrit pour les trois valeurs. Une implementation qui repond
/// juste en gauche a droite et faux en droite a gauche echoue ici, alors
/// qu elle passerait inapercue a la relecture en francais.
struct SensDeLectureDansLeMoteurTests {
    // MARK: Ordre des pages

    @Test("L ordre narratif ne depend pas du sens de lecture")
    func ordreNarratifIndependantDuSens() {
        for sens in SensDeLecture.allCases {
            let pages = OrdreDesPages.ordreNarratif(nombreDePages: 4)

            #expect(pages == [0, 1, 2, 3], "Sens \(sens.rawValue)")
            #expect(OrdreDesPages.aLEcran(pages, sens: sens).count == pages.count)
        }
    }

    @Test("En droite a gauche, la premiere page d une paire occupe le bord droit")
    func ordreALEcranEnDroiteGauche() {
        #expect(OrdreDesPages.aLEcran([0, 1], sens: .droiteGauche) == [1, 0])
        #expect(OrdreDesPages.aLEcran([4, 5], sens: .droiteGauche) == [5, 4])
    }

    @Test("En gauche a droite et en vertical, la sequence est conservee")
    func ordreALEcranDansLesAutresSens() {
        #expect(OrdreDesPages.aLEcran([0, 1], sens: .gaucheDroite) == [0, 1])
        #expect(OrdreDesPages.aLEcran([0, 1], sens: .hautBas) == [0, 1])
    }

    @Test("Une page seule reste identique dans les trois sens")
    func pageSeule() {
        for sens in SensDeLecture.allCases {
            #expect(OrdreDesPages.aLEcran([7], sens: sens) == [7], "Sens \(sens.rawValue)")
        }
    }

    @Test("En droite a gauche, la moitie droite d une image large vient en premier")
    func ordreDesMoities() {
        #expect(OrdreDesPages.ordreDesMoities(sens: .droiteGauche) == [.droite, .gauche])
        #expect(OrdreDesPages.ordreDesMoities(sens: .gaucheDroite) == [.gauche, .droite])
        #expect(OrdreDesPages.ordreDesMoities(sens: .hautBas) == [.gauche, .droite])
    }

    // MARK: Geste

    @Test("Le balayage qui avance depend du sens de lecture")
    func balayageQuiAvance() {
        #expect(NavigationDeLecture.balayageQuiAvance(.gaucheDroite) == .versLaGauche)
        #expect(NavigationDeLecture.balayageQuiAvance(.droiteGauche) == .versLaDroite)
        #expect(NavigationDeLecture.balayageQuiAvance(.hautBas) == .versLeHaut)
    }

    @Test("Un balayage avance ou recule selon le sens, jamais les deux a la fois")
    func balayagesOpposes() {
        for sens in SensDeLecture.allCases {
            let quiAvance = NavigationDeLecture.balayageQuiAvance(sens)

            #expect(
                NavigationDeLecture.intention(pourBalayage: quiAvance, sens: sens) == .pageSuivante,
                "Sens \(sens.rawValue)"
            )
            #expect(
                NavigationDeLecture.intention(pourBalayage: Self.oppose(quiAvance), sens: sens)
                    == .pagePrecedente,
                "Sens \(sens.rawValue)"
            )
        }
    }

    @Test("En droite a gauche, le doigt part vers la droite pour avancer")
    func balayageEnDroiteGauche() {
        #expect(
            NavigationDeLecture.intention(pourBalayage: .versLaDroite, sens: .droiteGauche)
                == .pageSuivante
        )
        #expect(
            NavigationDeLecture.intention(pourBalayage: .versLaGauche, sens: .droiteGauche)
                == .pagePrecedente
        )
    }

    @Test("Un balayage hors de l axe de lecture ne navigue pas")
    func balayageHorsAxe() {
        for sens in [SensDeLecture.gaucheDroite, .droiteGauche] {
            #expect(NavigationDeLecture.intention(pourBalayage: .versLeHaut, sens: sens) == .aucune)
            #expect(NavigationDeLecture.intention(pourBalayage: .versLeBas, sens: sens) == .aucune)
        }

        #expect(NavigationDeLecture.intention(pourBalayage: .versLaGauche, sens: .hautBas) == .aucune)
        #expect(NavigationDeLecture.intention(pourBalayage: .versLaDroite, sens: .hautBas) == .aucune)
    }

    // MARK: Clavier

    @Test("La fleche qui avance designe la position de la page visee")
    func flecheQuiAvance() {
        #expect(NavigationDeLecture.toucheQuiAvance(.gaucheDroite) == .flecheDroite)
        #expect(NavigationDeLecture.toucheQuiAvance(.droiteGauche) == .flecheGauche)
        #expect(NavigationDeLecture.toucheQuiAvance(.hautBas) == .flecheBas)
    }

    @Test("En droite a gauche, la fleche gauche avance et la fleche droite recule")
    func clavierEnDroiteGauche() {
        #expect(
            NavigationDeLecture.intention(pourTouche: .flecheGauche, sens: .droiteGauche)
                == .pageSuivante
        )
        #expect(
            NavigationDeLecture.intention(pourTouche: .flecheDroite, sens: .droiteGauche)
                == .pagePrecedente
        )
    }

    @Test("En gauche a droite et en vertical, les fleches suivent leur axe")
    func clavierDansLesAutresSens() {
        #expect(
            NavigationDeLecture.intention(pourTouche: .flecheDroite, sens: .gaucheDroite)
                == .pageSuivante
        )
        #expect(
            NavigationDeLecture.intention(pourTouche: .flecheGauche, sens: .gaucheDroite)
                == .pagePrecedente
        )
        #expect(NavigationDeLecture.intention(pourTouche: .flecheBas, sens: .hautBas) == .pageSuivante)
        #expect(NavigationDeLecture.intention(pourTouche: .flecheHaut, sens: .hautBas) == .pagePrecedente)
    }

    @Test("Une fleche hors de l axe de lecture ne navigue pas")
    func clavierHorsAxe() {
        for sens in [SensDeLecture.gaucheDroite, .droiteGauche] {
            #expect(NavigationDeLecture.intention(pourTouche: .flecheHaut, sens: sens) == .aucune)
            #expect(NavigationDeLecture.intention(pourTouche: .flecheBas, sens: sens) == .aucune)
        }

        #expect(NavigationDeLecture.intention(pourTouche: .flecheGauche, sens: .hautBas) == .aucune)
        #expect(NavigationDeLecture.intention(pourTouche: .flecheDroite, sens: .hautBas) == .aucune)
    }

    @Test("L espace avance dans les trois sens, l espace avec majuscule recule")
    func espaceSansDirection() {
        for sens in SensDeLecture.allCases {
            #expect(
                NavigationDeLecture.intention(pourTouche: .espace, sens: sens) == .pageSuivante,
                "Sens \(sens.rawValue)"
            )
            #expect(
                NavigationDeLecture.intention(pourTouche: .espaceAvecMajuscule, sens: sens)
                    == .pagePrecedente,
                "Sens \(sens.rawValue)"
            )
        }
    }

    // MARK: Curseur

    @Test("Le curseur prend l axe et l origine du sens de lecture")
    func axeEtOrigineDuCurseur() {
        #expect(CurseurDeProgression(sens: .gaucheDroite).axe == .horizontal)
        #expect(CurseurDeProgression(sens: .droiteGauche).axe == .horizontal)
        #expect(CurseurDeProgression(sens: .hautBas).axe == .vertical)

        #expect(CurseurDeProgression(sens: .gaucheDroite).origine == .gauche)
        #expect(CurseurDeProgression(sens: .droiteGauche).origine == .droite)
        #expect(CurseurDeProgression(sens: .hautBas).origine == .haut)
    }

    @Test("En droite a gauche, le curseur part du bord droit")
    func positionDuCurseurEnDroiteGauche() {
        let curseur = CurseurDeProgression(sens: .droiteGauche)

        #expect(curseur.position(pourProgression: 0) == 1)
        #expect(curseur.position(pourProgression: 0.25) == 0.75)
        #expect(curseur.position(pourProgression: 1) == 0)
    }

    @Test("En gauche a droite et en vertical, le curseur part du debut de l axe")
    func positionDuCurseurDansLesAutresSens() {
        for sens in [SensDeLecture.gaucheDroite, .hautBas] {
            let curseur = CurseurDeProgression(sens: sens)

            #expect(curseur.position(pourProgression: 0) == 0, "Sens \(sens.rawValue)")
            #expect(curseur.position(pourProgression: 0.25) == 0.25, "Sens \(sens.rawValue)")
            #expect(curseur.position(pourProgression: 1) == 1, "Sens \(sens.rawValue)")
        }
    }

    @Test("Position et progression sont reciproques dans les trois sens")
    func curseurReciproque() {
        for sens in SensDeLecture.allCases {
            let curseur = CurseurDeProgression(sens: sens)

            for centieme in 0...100 {
                let progression = Double(centieme) / 100
                let position = curseur.position(pourProgression: progression)
                let retour = curseur.progression(pourPosition: position)

                #expect(
                    abs(retour - progression) < 0.000_001,
                    "Sens \(sens.rawValue), progression \(progression)"
                )
            }
        }
    }

    @Test("Une progression hors bornes est ramenee dans l intervalle")
    func curseurBorne() {
        let curseur = CurseurDeProgression(sens: .gaucheDroite)

        #expect(curseur.position(pourProgression: -0.5) == 0)
        #expect(curseur.position(pourProgression: 1.5) == 1)
    }

    // MARK: Zones de toucher

    @Test("En droite a gauche, la zone de gauche avance et celle de droite recule")
    func zonesEnDroiteGauche() {
        #expect(ZonesDeToucher.intention(pourFraction: 0.1, sens: .droiteGauche) == .pageSuivante)
        #expect(ZonesDeToucher.intention(pourFraction: 0.9, sens: .droiteGauche) == .pagePrecedente)
    }

    @Test("En gauche a droite et en vertical, la zone de fin avance")
    func zonesDansLesAutresSens() {
        #expect(ZonesDeToucher.intention(pourFraction: 0.9, sens: .gaucheDroite) == .pageSuivante)
        #expect(ZonesDeToucher.intention(pourFraction: 0.1, sens: .gaucheDroite) == .pagePrecedente)
        #expect(ZonesDeToucher.intention(pourFraction: 0.9, sens: .hautBas) == .pageSuivante)
        #expect(ZonesDeToucher.intention(pourFraction: 0.1, sens: .hautBas) == .pagePrecedente)
    }

    @Test("La bande du milieu ne navigue jamais, quel que soit le sens")
    func bandeDuMilieu() {
        for sens in SensDeLecture.allCases {
            #expect(ZonesDeToucher.intention(pourFraction: 0.5, sens: sens) == .aucune, "Sens \(sens.rawValue)")
            #expect(
                ZonesDeToucher.intention(pourFraction: 0.5, sens: sens, zonesInversees: true) == .aucune,
                "Sens \(sens.rawValue)"
            )
        }
    }

    @Test("Inverser les zones echange les deux bandes actives dans les trois sens")
    func zonesInversees() {
        for sens in SensDeLecture.allCases {
            for fraction in [0.1, 0.9] {
                let normale = ZonesDeToucher.intention(pourFraction: fraction, sens: sens)
                let inversee = ZonesDeToucher.intention(
                    pourFraction: fraction,
                    sens: sens,
                    zonesInversees: true
                )

                #expect(normale != inversee, "Sens \(sens.rawValue), fraction \(fraction)")
                #expect(inversee != .aucune, "Sens \(sens.rawValue), fraction \(fraction)")
            }
        }
    }

    /// Balayage oppose sur le meme axe.
    static func oppose(_ balayage: BalayageDeNavigation) -> BalayageDeNavigation {
        switch balayage {
        case .versLaGauche: .versLaDroite
        case .versLaDroite: .versLaGauche
        case .versLeHaut: .versLeBas
        case .versLeBas: .versLeHaut
        }
    }
}
