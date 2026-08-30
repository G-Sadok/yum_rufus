import Testing
@testable import Core

//
// Couvre l ordre dans lequel les bulles traduites se lisent.
//
// L ordre est celui des cases, et c est precisement pour cela qu il merite ses
// propres tests plutot qu une confiance dans ceux de `CaseDePageTests`. Le
// rangement des bulles passe par un regroupement qui doit rendre autant de
// bulles qu il en recoit : une bulle perdue en chemin, c est une phrase de la
// planche qui ne s affiche plus, et rien a l ecran ne dirait qu elle a disparu.
//
// Le sens de lecture est celui de la serie, jamais celui de l interface. Le
// defaut serait invisible en francais, comme le promet l erreur 6 du cahier des
// charges, et systematique en droite a gauche.
//

struct BulleDeTexteTests {
    /// Bulle sure au coin demande de la planche.
    private func bulle(
        abscisse: Double,
        ordonnee: Double,
        texte: String
    ) throws -> BulleDeTexte {
        let cadre = try #require(
            CaseDePage(abscisse: abscisse, ordonnee: ordonnee, largeur: 0.25, hauteur: 0.15)
        )

        return try #require(BulleDeTexte(cadre: cadre, texte: texte))
    }

    // MARK: Une bulle vide n en est pas une

    @Test("Une bulle sans texte est refusee a la construction")
    func laBulleSansTexteEstRefusee() throws {
        let cadre = try #require(
            CaseDePage(abscisse: 0, ordonnee: 0, largeur: 0.4, hauteur: 0.2)
        )

        #expect(BulleDeTexte(cadre: cadre, texte: "") == nil)
        #expect(BulleDeTexte(cadre: cadre, texte: "   \n  ") == nil)
    }

    @Test("Le texte lu est nettoye de ses blancs de bord")
    func leTexteEstNettoye() throws {
        let cadre = try #require(
            CaseDePage(abscisse: 0, ordonnee: 0, largeur: 0.4, hauteur: 0.2)
        )
        let bulle = try #require(BulleDeTexte(cadre: cadre, texte: "  Attends  \n"))

        #expect(bulle.texte == "Attends")
        #expect(bulle.confiance == cadre.confiance)
    }

    // MARK: L ordre de lecture

    @Test("En droite a gauche, la bulle de droite se lit en premier")
    func enDroiteAGaucheLaDroiteVientEnPremier() throws {
        let gauche = try bulle(abscisse: 0.05, ordonnee: 0.05, texte: "gauche")
        let droite = try bulle(abscisse: 0.65, ordonnee: 0.05, texte: "droite")

        let rangees = SensDeLecture.droiteGauche.ordonnerLesBulles([gauche, droite])

        #expect(rangees.map(\.texte) == ["droite", "gauche"])
    }

    @Test("En gauche a droite, la bulle de gauche se lit en premier")
    func enGaucheADroiteLaGaucheVientEnPremier() throws {
        let gauche = try bulle(abscisse: 0.05, ordonnee: 0.05, texte: "gauche")
        let droite = try bulle(abscisse: 0.65, ordonnee: 0.05, texte: "droite")

        let rangees = SensDeLecture.gaucheDroite.ordonnerLesBulles([droite, gauche])

        #expect(rangees.map(\.texte) == ["gauche", "droite"])
    }

    @Test("Le rangement ne perd aucune bulle, quel que soit le sens")
    func leRangementNePerdAucuneBulle() throws {
        let bulles = try [
            bulle(abscisse: 0.05, ordonnee: 0.05, texte: "un"),
            bulle(abscisse: 0.65, ordonnee: 0.05, texte: "deux"),
            bulle(abscisse: 0.05, ordonnee: 0.45, texte: "trois"),
            bulle(abscisse: 0.65, ordonnee: 0.45, texte: "quatre"),
        ]

        for sens in SensDeLecture.allCases {
            let rangees = sens.ordonnerLesBulles(bulles)

            #expect(rangees.count == bulles.count, "\(sens)")
            #expect(Set(rangees) == Set(bulles), "\(sens)")
        }
    }

    @Test("Une planche sans bulle, ou d une seule, traverse le rangement telle quelle")
    func lesCasLimitesTraversent() throws {
        let seule = try bulle(abscisse: 0.1, ordonnee: 0.1, texte: "seule")

        for sens in SensDeLecture.allCases {
            #expect(sens.ordonnerLesBulles([]).isEmpty, "\(sens)")
            #expect(sens.ordonnerLesBulles([seule]) == [seule], "\(sens)")
        }
    }

    // MARK: L ordre des bulles traduites

    @Test("Les bulles traduites se rangent comme les bulles d origine")
    func lesTraductionsSeRangentCommeLesBulles() throws {
        let gauche = try bulle(abscisse: 0.05, ordonnee: 0.05, texte: "gauche")
        let droite = try bulle(abscisse: 0.65, ordonnee: 0.05, texte: "droite")

        let traductions = [gauche, droite].map {
            TraductionDeBulle(
                bulle: $0,
                texteTraduit: "traduit \($0.texte)",
                langueCible: .francais,
                moteur: .surLAppareil
            )
        }

        let rangees = SensDeLecture.droiteGauche.ordonnerLesTraductions(traductions)

        #expect(rangees.map(\.texteDOrigine) == ["droite", "gauche"])
        #expect(rangees.map(\.texteTraduit) == ["traduit droite", "traduit gauche"])
    }

    @Test("Le rangement des traductions ne perd aucune bulle")
    func leRangementDesTraductionsNePerdRien() throws {
        let bulles = try [
            bulle(abscisse: 0.05, ordonnee: 0.05, texte: "un"),
            bulle(abscisse: 0.65, ordonnee: 0.05, texte: "deux"),
            bulle(abscisse: 0.35, ordonnee: 0.55, texte: "trois"),
        ]
        let traductions = bulles.map {
            TraductionDeBulle(
                bulle: $0,
                texteTraduit: $0.texte,
                langueCible: .francais,
                moteur: .surLAppareil
            )
        }

        for sens in SensDeLecture.allCases {
            let rangees = sens.ordonnerLesTraductions(traductions)

            #expect(rangees.count == traductions.count, "\(sens)")
            #expect(Set(rangees) == Set(traductions), "\(sens)")
        }
    }

    @Test("Une bulle deja dans la langue cible se declare inchangee")
    func laBulleInchangeeSeDeclare() throws {
        let bulle = try bulle(abscisse: 0.1, ordonnee: 0.1, texte: "deja traduit")
        let traduction = TraductionDeBulle(
            bulle: bulle,
            texteTraduit: "deja traduit",
            langueCible: .francais,
            moteur: .surLAppareil
        )

        #expect(traduction.estInchangee)
        #expect(traduction.cadre == bulle.cadre)
    }
}
