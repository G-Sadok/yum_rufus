import Core
import Foundation
import Testing

/// Couvre le sens de lecture de la section 7.2 du cahier de developpement, ses
/// trois valeurs, sa resolution entre reglage global et surcharge de serie, et
/// son independance vis a vis de la direction de l interface.
struct SensDeLectureTests {
    @Test("Le sens de lecture porte exactement les trois valeurs de la section 7.2")
    func troisValeurs() {
        #expect(SensDeLecture.allCases.count == 3)
        #expect(Set(SensDeLecture.allCases) == [.droiteGauche, .gaucheDroite, .hautBas])
    }

    @Test("Les representations textuelles sont stables, elles sont ecrites en base")
    func representationsStables() {
        #expect(SensDeLecture.droiteGauche.rawValue == "droiteGauche")
        #expect(SensDeLecture.gaucheDroite.rawValue == "gaucheDroite")
        #expect(SensDeLecture.hautBas.rawValue == "hautBas")
    }

    @Test("Le defaut du modele est celui de la section 12, droite a gauche")
    func defautConformeAuCahier() {
        #expect(SensDeLecture.parDefaut == .droiteGauche)
    }

    @Test("Verticalite et depart par la droite sont definis pour les trois valeurs")
    func proprietesGeometriques() {
        #expect(SensDeLecture.droiteGauche.estVertical == false)
        #expect(SensDeLecture.gaucheDroite.estVertical == false)
        #expect(SensDeLecture.hautBas.estVertical)

        #expect(SensDeLecture.droiteGauche.commenceParLaDroite)
        #expect(SensDeLecture.gaucheDroite.commenceParLaDroite == false)
        #expect(SensDeLecture.hautBas.commenceParLaDroite == false)
    }

    @Test("En droite a gauche, la moitie droite d une image large vient en premier")
    func ordreDesMoities() {
        #expect(SensDeLecture.droiteGauche.ordreDesMoities == [.droite, .gauche])
        #expect(SensDeLecture.gaucheDroite.ordreDesMoities == [.gauche, .droite])
        #expect(SensDeLecture.hautBas.ordreDesMoities == [.gauche, .droite])
    }

    @Test("Les deux moities sont toujours rendues, chacune une seule fois")
    func lesDeuxMoitiesSontRendues() {
        for sens in SensDeLecture.allCases {
            #expect(Set(sens.ordreDesMoities) == Set(MoitieDImageLarge.allCases), "Sens \(sens.rawValue)")
            #expect(sens.ordreDesMoities.count == 2, "Sens \(sens.rawValue)")
        }
    }

    @Test(
        "Sans surcharge, la serie suit le reglage global",
        arguments: SensDeLecture.allCases
    )
    func sansSurchargeLeGlobalDecide(global: SensDeLecture) {
        let reglage = ReglageDeSensDeLecture(sensGlobal: global)

        #expect(reglage.sens(surchargeDeSerie: nil) == global)
    }

    @Test("La surcharge de serie prime sur le reglage global, pour toutes les combinaisons")
    func laSurchargePrime() {
        for global in SensDeLecture.allCases {
            for surcharge in SensDeLecture.allCases {
                let reglage = ReglageDeSensDeLecture(sensGlobal: global)

                #expect(
                    reglage.sens(surchargeDeSerie: surcharge) == surcharge,
                    "Global \(global.rawValue) contre surcharge \(surcharge.rawValue)"
                )
            }
        }
    }

    @Test("Une serie sans surcharge ne se voit jamais deviner un sens depuis sa langue")
    func aucuneDeductionDepuisLaLangue() {
        let serie = Manga(
            sourceId: UUID(),
            identifiantDistant: "serie-japonaise",
            titre: "Serie",
            langue: "ja"
        )
        let reglage = ReglageDeSensDeLecture(sensGlobal: .gaucheDroite)

        #expect(serie.sensLectureForce == nil)
        #expect(
            reglage.sens(pour: serie) == .gaucheDroite,
            "Une serie japonaise sans surcharge suit le reglage global, elle ne le contredit pas"
        )
    }

    @Test(
        "La direction de l interface ne change aucun sens de lecture",
        arguments: SensDeLecture.allCases
    )
    func laDirectionDInterfaceNeChangeRien(sens: SensDeLecture) {
        let serie = Manga(
            sourceId: UUID(),
            identifiantDistant: "serie",
            titre: "Serie",
            sensLectureForce: sens
        )
        let reglage = ReglageDeSensDeLecture(sensGlobal: .hautBas)

        for direction in DirectionDInterface.allCases {
            let contexte = ContexteDePresentation(
                sensDeLecture: reglage.sens(pour: serie),
                directionDInterface: direction
            )

            #expect(
                contexte.sensDeLecture == sens,
                "La direction \(direction.rawValue) a modifie le sens de lecture"
            )
        }
    }

    @Test("Une interface arabe laisse un manhwa se lire de gauche a droite")
    func interfaceArabeEtManhwa() {
        let direction = DirectionDInterface.pourLangue("ar-EG")
        let contexte = ContexteDePresentation(
            sensDeLecture: .gaucheDroite,
            directionDInterface: direction
        )

        #expect(direction == .droiteGauche)
        #expect(contexte.sensDeLecture == .gaucheDroite)
        #expect(contexte.lesDirectionsDivergent)
    }

    @Test("Une interface francaise laisse un manga se lire de droite a gauche")
    func interfaceFrancaiseEtManga() {
        let direction = DirectionDInterface.pourLangue("fr")
        let contexte = ContexteDePresentation(
            sensDeLecture: .droiteGauche,
            directionDInterface: direction
        )

        #expect(direction == .gaucheDroite)
        #expect(contexte.sensDeLecture == .droiteGauche)
        #expect(contexte.lesDirectionsDivergent)
    }

    @Test(
        "La direction de l interface se deduit de la langue, pas du sens de lecture",
        arguments: [
            ("ar", DirectionDInterface.droiteGauche),
            ("ar-EG", DirectionDInterface.droiteGauche),
            ("he_IL", DirectionDInterface.droiteGauche),
            ("fa", DirectionDInterface.droiteGauche),
            ("ur", DirectionDInterface.droiteGauche),
            ("fr", DirectionDInterface.gaucheDroite),
            ("en-US", DirectionDInterface.gaucheDroite),
            ("ja", DirectionDInterface.gaucheDroite),
            ("es", DirectionDInterface.gaucheDroite),
            ("", DirectionDInterface.gaucheDroite),
        ]
    )
    func directionDInterfacePourLangue(code: String, attendue: DirectionDInterface) {
        #expect(DirectionDInterface.pourLangue(code) == attendue)
    }

    @Test("Le japonais dispose son interface de gauche a droite, contrairement au manga")
    func leJaponaisNestPasUneLangueDeDroiteAGauche() {
        // Piege classique : confondre la langue d une serie et le sens de ses
        // pages. Le japonais s ecrit de gauche a droite dans une interface
        // moderne, alors qu un manga japonais se lit de droite a gauche.
        #expect(DirectionDInterface.pourLangue("ja") == .gaucheDroite)
    }
}
