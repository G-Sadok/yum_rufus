import Core
import Testing
@testable import ReaderEngine

/// Couvre les bornes et les invariants de la composition en double page :
/// chapitre vide, page unique, compte impair, index hors du chapitre, et les
/// proprietes qui doivent tenir pour toute combinaison de sens, de decalage et
/// de pages larges.
///
/// Ces cas vivent a part de `CompositionEnDoublePageTests`, qui verifie ce que
/// la composition produit. Ici, on verifie ce qu elle ne peut jamais produire :
/// une page perdue, une page vue deux fois, une paire de trois pages, ou une
/// page large accompagnee.
struct InvariantsDeDoublePageTests {
    // MARK: Bornes

    @Test("Un chapitre vide ne compose aucune paire")
    func chapitreVide() {
        for sens in SensDeLecture.allCases {
            for decalage in DecalageDeCouverture.allCases {
                let composition = CompositionEnDoublePage(
                    nombreDePages: 0,
                    sens: sens,
                    decalage: decalage
                )

                #expect(composition.paires.isEmpty, "Sens \(sens.rawValue)")
                #expect(composition.paire(contenantLaPage: 0) == nil, "Sens \(sens.rawValue)")
            }
        }
    }

    @Test("Un chapitre d une seule page tient dans une paire seule")
    func chapitreDUneSeulePage() {
        for decalage in DecalageDeCouverture.allCases {
            let composition = CompositionEnDoublePage(
                nombreDePages: 1,
                sens: .droiteGauche,
                decalage: decalage
            )

            #expect(composition.paires.map(\.pages) == [[0]])
        }
    }

    @Test("La derniere page d un compte impair est affichee seule")
    func dernierePageImpaire() {
        let composition = CompositionEnDoublePage(nombreDePages: 5, sens: .gaucheDroite, decalage: .aucun)

        #expect(composition.paires.last?.pages == [4])
        #expect(composition.paires.last?.motifDeLaPageSeule == .finDuChapitre)
    }

    @Test("Un nombre de pages negatif est ramene a un chapitre vide")
    func nombreDePagesNegatif() {
        let composition = CompositionEnDoublePage(nombreDePages: -3, sens: .droiteGauche)

        #expect(composition.nombreDePages == 0)
        #expect(composition.paires.isEmpty)
    }

    @Test("Une page large hors du chapitre est ignoree")
    func pageLargeHorsDuChapitre() {
        let composition = CompositionEnDoublePage(
            nombreDePages: 4,
            sens: .gaucheDroite,
            decalage: .aucun,
            pagesLarges: [9, -1]
        )

        #expect(composition.paires.map(\.pages) == [[0, 1], [2, 3]])
    }

    // MARK: Invariants

    @Test("Chaque page apparait une fois et une seule, dans l ordre narratif")
    func chaquePageUneFois() {
        for sens in SensDeLecture.allCases {
            for decalage in DecalageDeCouverture.allCases {
                for largeur in [Set<Int>(), [0], [1], [3], [0, 1], [2, 5], [1, 2, 3]] {
                    let composition = CompositionEnDoublePage(
                        nombreDePages: 7,
                        sens: sens,
                        decalage: decalage,
                        pagesLarges: largeur
                    )

                    let parcourues = composition.paires.flatMap(\.pages)

                    #expect(
                        parcourues == Array(0..<7),
                        "Sens \(sens.rawValue), decalage \(decalage.rawValue), larges \(largeur.sorted())"
                    )
                }
            }
        }
    }

    @Test("Une paire ne porte jamais plus de deux pages, ni deux pages disjointes")
    func formeDesPaires() {
        for sens in SensDeLecture.allCases {
            for decalage in DecalageDeCouverture.allCases {
                let composition = CompositionEnDoublePage(
                    nombreDePages: 11,
                    sens: sens,
                    decalage: decalage,
                    pagesLarges: [4, 7]
                )

                for paire in composition.paires {
                    #expect((1...2).contains(paire.pages.count), "Sens \(sens.rawValue)")
                    #expect(paire.aLEcran.count == paire.pages.count, "Sens \(sens.rawValue)")

                    if paire.pages.count == 2 {
                        #expect(paire.pages[1] == paire.pages[0] + 1, "Sens \(sens.rawValue)")
                        #expect(paire.motifDeLaPageSeule == nil, "Sens \(sens.rawValue)")
                    }
                }
            }
        }
    }

    @Test("Toute page du chapitre se retrouve par sa paire, et aucune autre")
    func rechercheParPage() {
        let composition = CompositionEnDoublePage(
            nombreDePages: 6,
            sens: .droiteGauche,
            decalage: .couvertureSeule,
            pagesLarges: [4]
        )

        for page in 0..<6 {
            guard let index = composition.indexDePaire(contenantLaPage: page) else {
                Issue.record("La page \(page) doit appartenir a une paire")
                continue
            }

            #expect(composition.paires[index].contient(page))
        }

        #expect(composition.indexDePaire(contenantLaPage: 6) == nil)
        #expect(composition.indexDePaire(contenantLaPage: -1) == nil)
    }

    @Test("Une page large n est jamais accompagnee, quel que soit le sens ou le decalage")
    func pageLargeJamaisAccompagnee() {
        for sens in SensDeLecture.allCases {
            for decalage in DecalageDeCouverture.allCases {
                for pageLarge in 0..<8 {
                    let composition = CompositionEnDoublePage(
                        nombreDePages: 8,
                        sens: sens,
                        decalage: decalage,
                        pagesLarges: [pageLarge]
                    )

                    #expect(
                        composition.paire(contenantLaPage: pageLarge)?.pages == [pageLarge],
                        "Sens \(sens.rawValue), decalage \(decalage.rawValue), page \(pageLarge)"
                    )
                }
            }
        }
    }
}
