import Core
import ReaderEngine
import Testing

//
// Couvre le premier critere de la fonctionnalite : la navigation case par case
// suit le sens de lecture.
//
// Le critere se joue a deux endroits, et les deux sont eprouves ici. L ordre des
// cases vient du sens, et le geste qui avance aussi. Le cas le plus important du
// fichier est celui qui les prend ensemble : en droite a gauche, la fleche
// gauche avance, et elle doit mener a la case situee a gauche de celle que le
// lecteur regarde. Un seul des deux inverse produit une lecture a l envers, les
// deux inverses la remettent a l endroit par accident, et le defaut ressort le
// jour ou l un des deux est corrige.
//
// La traversee complete est le second cas fort. Elle enchaine deux planches et
// verifie la suite exacte des cases visitees, aller et retour, ce qu un test par
// etape isolee ne peut pas faire : c est au retour que se voit le defaut ou la
// planche precedente reprend a sa premiere case au lieu de sa derniere.
//

struct NavigationParCasesTests {
    // MARK: L ordre des cases suit le sens

    @Test("La premiere case d une planche est celle du bord ou la lecture commence")
    func laPremiereCaseEstCelleDuBordDeDepart() throws {
        let planche = try PlancheDeTest.grille()

        let droiteGauche = NavigationParCases(cases: planche.cases, sens: .droiteGauche)
        let gaucheDroite = NavigationParCases(cases: planche.cases, sens: .gaucheDroite)

        #expect(droiteGauche.caseCourante == planche.hautDroite)
        #expect(gaucheDroite.caseCourante == planche.hautGauche)
    }

    @Test("Une entree par la fin reprend la planche a sa derniere case")
    func lEntreeParLaFinReprendALaDerniereCase() throws {
        let planche = try PlancheDeTest.grille()

        let droiteGauche = NavigationParCases(
            cases: planche.cases,
            sens: .droiteGauche,
            entree: .parLaFin
        )
        let gaucheDroite = NavigationParCases(
            cases: planche.cases,
            sens: .gaucheDroite,
            entree: .parLaFin
        )

        #expect(droiteGauche.caseCourante == planche.basGauche)
        #expect(gaucheDroite.caseCourante == planche.basDroite)
    }

    @Test("Le bord d entree se deduit de l intention qui amene sur la planche")
    func leBordDEntreeSuitLIntention() {
        #expect(EntreeDansLaPlanche.apres(.pageSuivante) == .parLeDebut)
        #expect(EntreeDansLaPlanche.apres(.pagePrecedente) == .parLaFin)
        #expect(EntreeDansLaPlanche.apres(.aucune) == .parLeDebut)
    }

    // MARK: Le geste qui avance suit le sens

    /// Le cas qui ferme l erreur 6 du cahier des charges pour cette
    /// fonctionnalite. En droite a gauche, la fleche gauche avance, et la case
    /// qu elle atteint est bien celle qui se trouve a gauche.
    @Test("En droite a gauche, la fleche gauche mene a la case de gauche")
    func laFlecheGaucheAvanceEnDroiteAGauche() throws {
        let planche = try PlancheDeTest.grille()
        let depart = NavigationParCases(cases: planche.cases, sens: .droiteGauche)

        #expect(depart.caseCourante == planche.hautDroite)

        let apres = try Self.caseVisee(depart.apres(touche: .flecheGauche))

        #expect(apres.caseCourante == planche.hautGauche)
        #expect(apres.caseCourante.abscisse < depart.caseCourante.abscisse)

        #expect(depart.apres(touche: .flecheDroite) == .changementDePage(.pagePrecedente))
    }

    @Test("En gauche a droite, la fleche droite mene a la case de droite")
    func laFlecheDroiteAvanceEnGaucheADroite() throws {
        let planche = try PlancheDeTest.grille()
        let depart = NavigationParCases(cases: planche.cases, sens: .gaucheDroite)

        #expect(depart.caseCourante == planche.hautGauche)

        let apres = try Self.caseVisee(depart.apres(touche: .flecheDroite))

        #expect(apres.caseCourante == planche.hautDroite)
        #expect(apres.caseCourante.abscisse > depart.caseCourante.abscisse)

        #expect(depart.apres(touche: .flecheGauche) == .changementDePage(.pagePrecedente))
    }

    @Test("Le balayage qui avance d une page avance aussi d une case")
    func leBalayageQuiAvanceAvanceDUneCase() throws {
        let planche = try PlancheDeTest.grille()

        for sens in SensDeLecture.allCases {
            let depart = NavigationParCases(cases: planche.cases, sens: sens)
            let balayage = NavigationDeLecture.balayageQuiAvance(sens)
            let apres = try Self.caseVisee(depart.apres(balayage: balayage))

            #expect(apres.indice == 1, "\(sens)")
        }
    }

    @Test("L espace avance et le meme espace avec majuscule recule, dans les deux sens")
    func lEspaceAvanceQuelQueSoitLeSens() throws {
        let planche = try PlancheDeTest.grille()

        for sens in SensDeLecture.allCases {
            let depart = NavigationParCases(cases: planche.cases, sens: sens)
            let apres = try Self.caseVisee(depart.apres(touche: .espace))

            #expect(apres.indice == 1, "\(sens)")
            #expect(
                depart.apres(touche: .espaceAvecMajuscule) == .changementDePage(.pagePrecedente),
                "\(sens)"
            )
        }
    }

    @Test("Un geste qui ne navigue pas ne bouge aucune case")
    func leGesteQuiNeNaviguePasNeBougeRien() throws {
        let planche = try PlancheDeTest.grille()
        let depart = NavigationParCases(cases: planche.cases, sens: .droiteGauche)

        #expect(depart.apres(balayage: .versLeHaut) == .aucune)
        #expect(depart.apres(touche: .flecheHaut) == .aucune)
        #expect(depart.apres(.aucune) == .aucune)
    }

    // MARK: La traversee complete d un chapitre de deux planches

    @Test("La traversee visite toutes les cases des deux planches dans le sens de la serie")
    func laTraverseeSuitLeSens() throws {
        let planche = try PlancheDeTest.grille()

        let droiteGauche = try Self.traversee(planche.cases, sens: .droiteGauche, planches: 2)
        let gaucheDroite = try Self.traversee(planche.cases, sens: .gaucheDroite, planches: 2)

        let attenduDroiteGauche = [
            planche.hautDroite, planche.hautGauche, planche.basDroite, planche.basGauche,
        ]
        let attenduGaucheDroite = [
            planche.hautGauche, planche.hautDroite, planche.basGauche, planche.basDroite,
        ]

        #expect(droiteGauche == attenduDroiteGauche + attenduDroiteGauche)
        #expect(gaucheDroite == attenduGaucheDroite + attenduGaucheDroite)
        #expect(droiteGauche != gaucheDroite)
    }

    @Test("Le retour reprend la planche precedente par sa derniere case, jamais par sa premiere")
    func leRetourReprendParLaDerniereCase() throws {
        let planche = try PlancheDeTest.grille()

        // Le lecteur vient d entrer dans la seconde planche par son debut.
        let seconde = NavigationParCases(
            cases: planche.cases,
            sens: .droiteGauche,
            entree: .apres(.pageSuivante)
        )

        #expect(seconde.indice == 0)
        #expect(seconde.caseCourante == planche.hautDroite)

        guard case let .changementDePage(intention) = seconde.apres(.pagePrecedente) else {
            Issue.record("La premiere case d une planche doit rendre la main a la tourne de page")

            return
        }

        #expect(intention == .pagePrecedente)

        let precedente = NavigationParCases(
            cases: planche.cases,
            sens: .droiteGauche,
            entree: .apres(intention)
        )

        #expect(precedente.caseCourante == planche.basGauche)
        #expect(precedente.estALaDerniereCase)
        #expect(precedente.caseCourante != seconde.caseCourante)
    }

    // MARK: Une planche sans case reste lisible

    @Test("Une planche sans case detectee se navigue comme une page entiere")
    func laPlancheSansCaseSeNavigueCommeUnePage() {
        for sens in SensDeLecture.allCases {
            let parcours = NavigationParCases(cases: [], sens: sens)

            #expect(parcours.cases == [.plancheEntiere], "\(sens)")
            #expect(parcours.caseCourante == .plancheEntiere, "\(sens)")
            #expect(parcours.estALaPremiereCase, "\(sens)")
            #expect(parcours.estALaDerniereCase, "\(sens)")
            #expect(parcours.apres(.pageSuivante) == .changementDePage(.pageSuivante), "\(sens)")
            #expect(parcours.apres(.pagePrecedente) == .changementDePage(.pagePrecedente), "\(sens)")
        }
    }

    @Test("Le cadrage du zoom elargit la case sans sortir de la planche")
    func leCadrageResteDansLaPlanche() throws {
        let planche = try PlancheDeTest.grille()
        let parcours = NavigationParCases(cases: planche.cases, sens: .droiteGauche)
        let cadre = parcours.cadrage()

        #expect(cadre.surface > parcours.caseCourante.surface)
        #expect(cadre.abscisse >= 0)
        #expect(cadre.ordonnee >= 0)
        #expect(cadre.bordDroit <= 1)
        #expect(cadre.bordBas <= 1)
    }

    // MARK: Materiel des cas

    /// Cases visitees en avancant jusqu au bout du nombre de planches demande.
    private static func traversee(
        _ cases: [CaseDePage],
        sens: SensDeLecture,
        planches: Int
    ) throws -> [CaseDePage] {
        var parcours = NavigationParCases(cases: cases, sens: sens)
        var visitees = [parcours.caseCourante]
        var restantes = planches - 1

        while true {
            switch parcours.apres(.pageSuivante) {
            case let .caseVisee(suivant):
                parcours = suivant
                visitees.append(parcours.caseCourante)

            case .changementDePage:
                guard restantes > 0 else { return visitees }

                restantes -= 1
                parcours = NavigationParCases(
                    cases: cases,
                    sens: sens,
                    entree: .apres(.pageSuivante)
                )
                visitees.append(parcours.caseCourante)

            case .aucune:
                throw ErreurDeCasDeTest.intentionSansEffet
            }
        }
    }

    /// Parcours porte par une etape, ou echec du cas.
    private static func caseVisee(_ etape: EtapeDeNavigationParCases) throws -> NavigationParCases {
        guard case let .caseVisee(parcours) = etape else {
            throw ErreurDeCasDeTest.etapeInattendue
        }

        return parcours
    }
}

/// Echecs propres au materiel des cas, jamais leves par le code teste.
enum ErreurDeCasDeTest: Error {
    case intentionSansEffet
    case etapeInattendue
}

/// Grille de quatre cases, la disposition la plus courante d une planche.
struct PlancheDeTest {
    let hautGauche: CaseDePage
    let hautDroite: CaseDePage
    let basGauche: CaseDePage
    let basDroite: CaseDePage

    /// Cases dans un ordre d arrivee qui n est celui d aucun sens.
    var cases: [CaseDePage] {
        [basDroite, hautGauche, basGauche, hautDroite]
    }

    static func grille() throws -> PlancheDeTest {
        try PlancheDeTest(
            hautGauche: #require(CaseDePage(abscisse: 0.05, ordonnee: 0.05, largeur: 0.4, hauteur: 0.4)),
            hautDroite: #require(CaseDePage(abscisse: 0.55, ordonnee: 0.05, largeur: 0.4, hauteur: 0.4)),
            basGauche: #require(CaseDePage(abscisse: 0.05, ordonnee: 0.55, largeur: 0.4, hauteur: 0.4)),
            basDroite: #require(CaseDePage(abscisse: 0.55, ordonnee: 0.55, largeur: 0.4, hauteur: 0.4))
        )
    }
}
