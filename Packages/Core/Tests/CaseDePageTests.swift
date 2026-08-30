import Core
import Testing

//
// Couvre le premier critere de la fonctionnalite du cote du modele : la
// navigation case par case suit le sens de lecture.
//
// La navigation elle meme vit dans le moteur, mais elle ne fait que parcourir
// la suite que ce fichier fixe. Si l ordre est faux ici, aucun test du moteur ne
// le rattrapera, et le defaut sera invisible en francais comme l erreur 6 du
// cahier des charges le promet.
//
// Les quatre dispositions testees ne sont pas decoratives. Ce sont les quatre
// cas ou un tri naif se trompe : la grille, qui punit le tri par abscisse
// seule, la case pleine largeur, qui punit le tri par colonnes, la case haute
// posee contre deux cases empilees, qui punit le tri par ordonnee seule, et la
// planche verticale, qui ne doit dependre d aucun sens horizontal.
//

struct CaseDePageTests {
    // MARK: Une case ne peut pas mentir sur sa position

    @Test("Une case hors de la planche est refusee a la construction")
    func laCaseHorsDeLaPlancheEstRefusee() {
        #expect(CaseDePage(abscisse: 0.8, ordonnee: 0, largeur: 0.4, hauteur: 0.2) == nil)
        #expect(CaseDePage(abscisse: 0, ordonnee: 0.9, largeur: 0.2, hauteur: 0.3) == nil)
        #expect(CaseDePage(abscisse: -0.2, ordonnee: 0, largeur: 0.5, hauteur: 0.5) == nil)
        #expect(CaseDePage(abscisse: 0, ordonnee: 0, largeur: 0, hauteur: 0.5) == nil)
        #expect(CaseDePage(abscisse: 0, ordonnee: 0, largeur: 0.5, hauteur: 0.5, confiance: 1.4) == nil)
    }

    @Test("Une case qui touche le bord au millieme pres est acceptee")
    func leDepassementSousLePixelEstAccepte() {
        #expect(CaseDePage(abscisse: 0, ordonnee: 0, largeur: 1.0005, hauteur: 1) != nil)
    }

    @Test("La planche entiere est une case et couvre toute la planche")
    func laPlancheEntiereCouvreTout() {
        let planche = CaseDePage.plancheEntiere

        #expect(planche.abscisse == 0)
        #expect(planche.ordonnee == 0)
        #expect(planche.bordDroit == 1)
        #expect(planche.bordBas == 1)
        #expect(planche.surface == 1)
    }

    // MARK: Le cadrage du zoom

    @Test("Le cadrage elargit la case sans jamais sortir de la planche")
    func leCadrageResteDansLaPlanche() throws {
        let case1 = try #require(CaseDePage(abscisse: 0.01, ordonnee: 0.4, largeur: 0.3, hauteur: 0.3))
        let cadre = case1.elargie(de: 0.05)

        #expect(cadre.abscisse == 0)
        #expect(abs(cadre.ordonnee - 0.35) < 0.000_001)
        #expect(cadre.bordDroit <= 1)
        #expect(cadre.bordBas <= 1)
        #expect(cadre.surface > case1.surface)
    }

    @Test("Une marge nulle laisse la case telle quelle")
    func laMargeNulleNeChangeRien() throws {
        let case1 = try #require(CaseDePage(abscisse: 0.1, ordonnee: 0.1, largeur: 0.3, hauteur: 0.3))

        #expect(case1.elargie(de: 0) == case1)
    }

    @Test("Deux detections du meme cadre se reconnaissent, deux cases voisines non")
    func leRecouvrementSeMesure() throws {
        let cadre = try #require(CaseDePage(abscisse: 0.5, ordonnee: 0.05, largeur: 0.4, hauteur: 0.4))
        let presque = try #require(CaseDePage(abscisse: 0.51, ordonnee: 0.06, largeur: 0.4, hauteur: 0.4))
        let voisine = try #require(CaseDePage(abscisse: 0.05, ordonnee: 0.05, largeur: 0.4, hauteur: 0.4))

        #expect(cadre.intersectionSurUnion(cadre) == 1)
        #expect(cadre.intersectionSurUnion(presque) > 0.9)
        #expect(cadre.intersectionSurUnion(voisine) == 0)
    }

    // MARK: L ordre de lecture, disposition par disposition

    @Test("La grille de quatre cases se lit en commencant par le bord du sens")
    func laGrilleSuitLeSens() throws {
        let planche = try Self.grille()

        #expect(
            SensDeLecture.droiteGauche.ordonner(planche.cases)
                == [planche.hautDroite, planche.hautGauche, planche.basDroite, planche.basGauche]
        )
        #expect(
            SensDeLecture.gaucheDroite.ordonner(planche.cases)
                == [planche.hautGauche, planche.hautDroite, planche.basGauche, planche.basDroite]
        )
    }

    @Test("Une case pleine largeur se lit seule, avant la bande qui la suit")
    func laCasePleineLargeurSeLitSeule() throws {
        let banniere = try #require(CaseDePage(abscisse: 0.05, ordonnee: 0.05, largeur: 0.9, hauteur: 0.3))
        let basGauche = try #require(CaseDePage(abscisse: 0.05, ordonnee: 0.4, largeur: 0.4, hauteur: 0.5))
        let basDroite = try #require(CaseDePage(abscisse: 0.55, ordonnee: 0.4, largeur: 0.4, hauteur: 0.5))
        let cases = [basGauche, banniere, basDroite]

        #expect(
            SensDeLecture.droiteGauche.ordonner(cases) == [banniere, basDroite, basGauche]
        )
        #expect(
            SensDeLecture.gaucheDroite.ordonner(cases) == [banniere, basGauche, basDroite]
        )
    }

    /// La disposition qui casse les deux tris naifs a la fois.
    ///
    /// Un tri par ordonnee lirait la case haute entre les deux cases empilees,
    /// un tri par colonne la lirait apres les deux. Elle se lit en premier en
    /// droite a gauche, en dernier en gauche a droite.
    @Test("La case haute posee contre deux cases empilees se lit avec elles")
    func laCaseHauteResteDansSaBande() throws {
        let haute = try #require(CaseDePage(abscisse: 0.55, ordonnee: 0.05, largeur: 0.4, hauteur: 0.9))
        let gaucheHaut = try #require(CaseDePage(abscisse: 0.05, ordonnee: 0.05, largeur: 0.4, hauteur: 0.4))
        let gaucheBas = try #require(CaseDePage(abscisse: 0.05, ordonnee: 0.5, largeur: 0.4, hauteur: 0.45))
        let cases = [gaucheBas, haute, gaucheHaut]

        #expect(
            SensDeLecture.droiteGauche.ordonner(cases) == [haute, gaucheHaut, gaucheBas]
        )
        #expect(
            SensDeLecture.gaucheDroite.ordonner(cases) == [gaucheHaut, gaucheBas, haute]
        )
    }

    @Test("Une planche verticale se lit du haut vers le bas, quel que soit le sens")
    func laPlancheVerticaleSeLitDuHautVersLeBas() throws {
        let premiere = try #require(CaseDePage(abscisse: 0.05, ordonnee: 0.02, largeur: 0.9, hauteur: 0.3))
        let deuxieme = try #require(CaseDePage(abscisse: 0.05, ordonnee: 0.34, largeur: 0.9, hauteur: 0.3))
        let troisieme = try #require(CaseDePage(abscisse: 0.05, ordonnee: 0.66, largeur: 0.9, hauteur: 0.3))
        let cases = [troisieme, premiere, deuxieme]
        let attendu = [premiere, deuxieme, troisieme]

        for sens in SensDeLecture.allCases {
            #expect(sens.ordonner(cases) == attendu, "\(sens)")
        }
    }

    // MARK: Les proprietes que l ordre doit tenir

    @Test("Le sens droite a gauche lit la planche miroir comme le sens inverse")
    func lesDeuxSensSontSymetriques() throws {
        let planche = try Self.grille()
        let miroir = planche.cases.compactMap { Self.miroir(de: $0) }

        #expect(miroir.count == planche.cases.count)

        let droiteGauche = SensDeLecture.droiteGauche.ordonner(planche.cases)
        let gaucheDroite = SensDeLecture.gaucheDroite.ordonner(miroir)

        #expect(droiteGauche.compactMap { Self.miroir(de: $0) } == gaucheDroite)
    }

    @Test("L ordre ne depend pas de l ordre d arrivee des cases")
    func lOrdreNeDependPasDeLArrivee() throws {
        let planche = try Self.grille()

        for sens in SensDeLecture.allCases {
            let reference = sens.ordonner(planche.cases)

            let tournees = Array(planche.cases.dropFirst()) + Array(planche.cases.prefix(1))

            #expect(sens.ordonner(planche.cases.reversed()) == reference, "\(sens)")
            #expect(sens.ordonner(reference) == reference, "\(sens)")
            #expect(sens.ordonner(tournees) == reference, "\(sens)")
        }
    }

    @Test("Aucune case n est perdue ni dupliquee par le rangement")
    func aucuneCaseNEstPerdue() throws {
        let planche = try Self.grille()

        for sens in SensDeLecture.allCases {
            let rangees = sens.ordonner(planche.cases)

            #expect(rangees.count == planche.cases.count, "\(sens)")
            #expect(Set(rangees) == Set(planche.cases), "\(sens)")
        }
    }

    @Test("Une planche sans case, ou d une seule case, traverse le rangement telle quelle")
    func lesCasLimitesTraversent() throws {
        let seule = try #require(CaseDePage(abscisse: 0.1, ordonnee: 0.1, largeur: 0.5, hauteur: 0.5))

        for sens in SensDeLecture.allCases {
            #expect(sens.ordonner([]).isEmpty, "\(sens)")
            #expect(sens.ordonner([seule]) == [seule], "\(sens)")
        }
    }

    // MARK: Materiel des cas

    /// Grille de quatre cases, la disposition la plus courante d une planche.
    private struct Grille {
        let hautGauche: CaseDePage
        let hautDroite: CaseDePage
        let basGauche: CaseDePage
        let basDroite: CaseDePage

        /// Cases dans un ordre d arrivee qui n est celui d aucun sens.
        var cases: [CaseDePage] {
            [basDroite, hautGauche, basGauche, hautDroite]
        }
    }

    private static func grille() throws -> Grille {
        try Grille(
            hautGauche: #require(CaseDePage(abscisse: 0.05, ordonnee: 0.05, largeur: 0.4, hauteur: 0.4)),
            hautDroite: #require(CaseDePage(abscisse: 0.55, ordonnee: 0.05, largeur: 0.4, hauteur: 0.4)),
            basGauche: #require(CaseDePage(abscisse: 0.05, ordonnee: 0.55, largeur: 0.4, hauteur: 0.4)),
            basDroite: #require(CaseDePage(abscisse: 0.55, ordonnee: 0.55, largeur: 0.4, hauteur: 0.4))
        )
    }

    /// Case retournee autour de l axe vertical de la planche.
    private static func miroir(de element: CaseDePage) -> CaseDePage? {
        CaseDePage(
            abscisse: 1 - element.bordDroit,
            ordonnee: element.ordonnee,
            largeur: element.largeur,
            hauteur: element.hauteur,
            confiance: element.confiance
        )
    }
}
