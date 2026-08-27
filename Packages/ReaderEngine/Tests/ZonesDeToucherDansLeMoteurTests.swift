import Core
import ReaderEngine
import Testing

//
// Couvre la traduction d un appui en tourne de page, pour les quatre
// dispositions de la section 9 du cahier de developpement.
//
// Les tests de geometrie vivent cote modele, avec `DispositionDeZones`. Ceux ci
// verifient ce que le moteur en fait : qu une zone active tourne bien une page
// dans le bon sens, et qu une zone de menu n en tourne aucune.
//

struct ZonesDeToucherDansLeMoteurTests {
    // MARK: Traduction du role

    @Test("Un role de zone donne une et une seule intention")
    func traductionDesRoles() {
        #expect(ZonesDeToucher.intention(pourRole: .avance) == .pageSuivante)
        #expect(ZonesDeToucher.intention(pourRole: .recule) == .pagePrecedente)
        #expect(ZonesDeToucher.intention(pourRole: .menu) == .aucune)
    }

    @Test("Les parts du moteur sont celles du modele, jamais une seconde ecriture")
    func partsPartagees() {
        #expect(ZonesDeToucher.partDUneBandeActive == DispositionDeZones.partDUneBande)
        #expect(ZonesDeToucher.partDeLaBandeCentrale == DispositionDeZones.partDeLaBandeCentrale)
    }

    // MARK: Les quatre dispositions

    @Test("Desactive ne tourne aucune page, ou que l on appuie", arguments: SensDeLecture.allCases)
    func desactiveNeTourneRien(sens: SensDeLecture) {
        for abscisse in [0.02, 0.5, 0.98] {
            for ordonnee in [0.02, 0.5, 0.98] {
                let intention = ZonesDeToucher.intention(
                    pourAbscisse: abscisse,
                    ordonnee: ordonnee,
                    sens: sens,
                    disposition: .desactive
                )

                #expect(intention == .aucune, "\(sens.rawValue), point \(abscisse) \(ordonnee)")
            }
        }
    }

    @Test("Chaque disposition active tourne la page dans le sens de lecture")
    func dispositionsActives() {
        for disposition in [DispositionDeZones.standard, .bord, .kindle] {
            // En droite a gauche, la page suivante se trouve a gauche.
            #expect(
                ZonesDeToucher.intention(
                    pourAbscisse: 0.02,
                    ordonnee: 0.5,
                    sens: .droiteGauche,
                    disposition: disposition
                ) == .pageSuivante,
                "\(disposition.rawValue)"
            )

            // En gauche a droite, elle se trouve a droite.
            #expect(
                ZonesDeToucher.intention(
                    pourAbscisse: 0.98,
                    ordonnee: 0.5,
                    sens: .gaucheDroite,
                    disposition: disposition
                ) == .pageSuivante,
                "\(disposition.rawValue)"
            )

            // En vertical, elle se trouve en bas.
            #expect(
                ZonesDeToucher.intention(
                    pourAbscisse: 0.5,
                    ordonnee: 0.98,
                    sens: .hautBas,
                    disposition: disposition
                ) == .pageSuivante,
                "\(disposition.rawValue)"
            )
        }
    }

    @Test("La disposition Standard reste celle de l appui mesure sur le seul axe")
    func standardParFraction() {
        for sens in SensDeLecture.allCases {
            for fraction in [0.02, 0.5, 0.98] {
                let surLAxe = ZonesDeToucher.intention(pourFraction: fraction, sens: sens)
                let surLaSurface = ZonesDeToucher.intention(
                    pourAbscisse: sens.estVertical ? 0.5 : fraction,
                    ordonnee: sens.estVertical ? fraction : 0.5,
                    sens: sens,
                    disposition: .standard
                )

                #expect(surLAxe == surLaSurface, "\(sens.rawValue), fraction \(fraction)")
            }
        }
    }

    // MARK: Inversion

    @Test(
        "L inversion echange les deux intentions actives, dans les trois sens",
        arguments: [DispositionDeZones.standard, .bord, .kindle]
    )
    func inversionDesIntentions(disposition: DispositionDeZones) {
        for sens in SensDeLecture.allCases {
            // La tete de l axe de lecture, qui est en haut en mode vertical. Le
            // travers passe par le milieu pour eviter le bandeau de menu de
            // Kindle.
            let tete = 0.02
            let milieu = 0.5
            let abscisse = sens.estVertical ? milieu : tete
            let ordonnee = sens.estVertical ? tete : milieu

            let normale = ZonesDeToucher.intention(
                pourAbscisse: abscisse,
                ordonnee: ordonnee,
                sens: sens,
                disposition: disposition
            )
            let inversee = ZonesDeToucher.intention(
                pourAbscisse: abscisse,
                ordonnee: ordonnee,
                sens: sens,
                disposition: disposition,
                zonesInversees: true
            )

            #expect(normale != .aucune, "\(disposition.rawValue), \(sens.rawValue)")
            #expect(inversee != .aucune, "\(disposition.rawValue), \(sens.rawValue)")
            #expect(normale != inversee, "\(disposition.rawValue), \(sens.rawValue)")
        }
    }

    // MARK: Pagination

    @Test("Un appui sur une zone active deplace la page lue")
    func appuiSurLaPagination() {
        var pagination = PaginationEnPageSimple(nombreDePages: 20, sens: .droiteGauche, index: 10)

        // En droite a gauche, le bord gauche avance.
        let avancee = pagination.appliquer(
            appuiSurAbscisse: 0.02,
            ordonnee: 0.5,
            disposition: .standard
        )

        #expect(avancee)
        #expect(pagination.index == 11)

        let reculee = pagination.appliquer(
            appuiSurAbscisse: 0.98,
            ordonnee: 0.5,
            disposition: .standard
        )

        #expect(reculee)
        #expect(pagination.index == 10)
    }

    @Test("Un appui sur la zone de menu ne deplace jamais la page lue")
    func appuiSurLeMenu() {
        for disposition in DispositionDeZones.allCases {
            var pagination = PaginationEnPageSimple(nombreDePages: 20, sens: .droiteGauche, index: 10)

            // Le menu de Kindle est un bandeau de tete, celui des autres
            // dispositions occupe le centre de la surface.
            let ordonnee = disposition == .kindle ? 0.1 : 0.5
            let deplacee = pagination.appliquer(
                appuiSurAbscisse: 0.5,
                ordonnee: ordonnee,
                disposition: disposition
            )

            #expect(deplacee == false, "\(disposition.rawValue)")
            #expect(pagination.index == 10, "\(disposition.rawValue)")
        }
    }

    @Test("L inversion tient jusque dans la pagination")
    func appuiInverseSurLaPagination() {
        var pagination = PaginationEnPageSimple(nombreDePages: 20, sens: .droiteGauche, index: 10)

        let deplacee = pagination.appliquer(
            appuiSurAbscisse: 0.02,
            ordonnee: 0.5,
            disposition: .kindle,
            zonesInversees: true
        )

        #expect(deplacee)
        #expect(pagination.index == 9, "Inversee, la bande de tete recule au lieu d avancer")
    }
}
