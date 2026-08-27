import Core
import Testing

//
// Couvre les deux premiers criteres de la fonctionnalite : les quatre
// dispositions fonctionnent, et l inversion respecte le sens de lecture.
//
// Les tests de couverture sont les plus importants du fichier. Une disposition
// se juge d abord sur ce qu elle ne laisse pas passer : un point de la surface
// qui n appartient a aucune zone, ou deux zones qui se disputent le meme point,
// produisent un appui dont le resultat depend de l ordre d ecriture des bandes.
// Le balayage systematique ferme les deux cas.
//

struct DispositionDeZonesTests {
    /// Pas du balayage de la surface. Assez fin pour tomber de part et d autre
    /// de chaque bord de bande, y compris ceux de 0.28 et de 0.72.
    static let pas = 0.01

    /// Points de balayage d un axe, du bord au bord.
    static let points = Array(stride(from: 0.0, through: 1.0, by: pas))

    // MARK: Les quatre dispositions existent

    @Test("Le menu Zones de toucher propose les quatre dispositions du document")
    func quatreDispositions() {
        #expect(DispositionDeZones.allCases.count == 4)
        #expect(
            DispositionDeZones.valeursDuDocument == ["Desactive", "Standard", "Bord", "Kindle"]
        )
        #expect(DispositionDeZones.parDefaut == .desactive)
    }

    @Test("Seule la disposition desactivee ne pose aucune zone active")
    func zonesActives() {
        #expect(DispositionDeZones.desactive.aDesZonesActives == false)
        #expect(DispositionDeZones.standard.aDesZonesActives)
        #expect(DispositionDeZones.bord.aDesZonesActives)
        #expect(DispositionDeZones.kindle.aDesZonesActives)
    }

    // MARK: Couverture de la surface

    @Test(
        "Chaque disposition couvre toute la surface, sans trou ni recouvrement",
        arguments: DispositionDeZones.allCases,
        SensDeLecture.allCases
    )
    func couvertureComplete(disposition: DispositionDeZones, sens: SensDeLecture) {
        let zones = disposition.zones(sens: sens)

        for abscisse in Self.points {
            for ordonnee in Self.points {
                let touchees = zones.filter { $0.contient(abscisse: abscisse, ordonnee: ordonnee) }

                #expect(
                    touchees.count == 1,
                    "\(disposition.rawValue), \(sens.rawValue), point \(abscisse) \(ordonnee)"
                )
            }
        }
    }

    @Test(
        "La somme des parts de zone fait exactement la surface",
        arguments: DispositionDeZones.allCases
    )
    func sommeDesParts(disposition: DispositionDeZones) {
        for sens in SensDeLecture.allCases {
            let total = disposition.zones(sens: sens).reduce(0) { $0 + $1.part }

            #expect(abs(total - 1) < 0.000_001, "\(disposition.rawValue), \(sens.rawValue)")
        }
    }

    @Test("Aucune zone ne sort de la surface", arguments: DispositionDeZones.allCases)
    func zonesDansLaSurface(disposition: DispositionDeZones) {
        for sens in SensDeLecture.allCases {
            for zone in disposition.zones(sens: sens) {
                #expect(zone.abscisse >= 0)
                #expect(zone.ordonnee >= 0)
                #expect(zone.abscisse + zone.largeur <= 1.000_001)
                #expect(zone.ordonnee + zone.hauteur <= 1.000_001)
            }
        }
    }

    // MARK: Geometrie de chaque disposition

    @Test("Desactive ne fait tourner aucune page, ou que l on appuie")
    func desactiveNeNaviguePas() {
        for sens in SensDeLecture.allCases {
            for abscisse in Self.points {
                for ordonnee in Self.points {
                    let role = DispositionDeZones.desactive.role(
                        pourAbscisse: abscisse,
                        ordonnee: ordonnee,
                        sens: sens
                    )

                    #expect(role == .menu, "\(sens.rawValue), point \(abscisse) \(ordonnee)")
                }
            }
        }
    }

    @Test("Standard pose les trois colonnes de 28, 44 et 28 pour cent de la section 5.7")
    func standardEnTroisColonnes() {
        #expect(DispositionDeZones.partDUneBande == 0.28)
        #expect(proches(DispositionDeZones.partDeLaBandeCentrale, 0.44))

        let zones = DispositionDeZones.standard.zones(sens: .gaucheDroite)

        #expect(zones.count == 3)

        for zone in zones {
            #expect(zone.hauteur == 1, "Une colonne de Standard traverse toute la hauteur")
        }

        // Bande de tete, bande centrale, bande de queue.
        #expect(zones.map(\.role) == [.recule, .menu, .avance])
        #expect(proches(zones[0].largeur, 0.28))
        #expect(proches(zones[1].largeur, DispositionDeZones.partDeLaBandeCentrale))
        #expect(proches(zones[2].largeur, 0.28))
    }

    @Test("Bord ajoute deux bandes actives en travers, et reduit le menu au centre")
    func bordActiveLesQuatreBords() {
        let disposition = DispositionDeZones.bord

        // Les quatre bords tournent une page.
        #expect(disposition.role(pourAbscisse: 0.02, ordonnee: 0.5, sens: .gaucheDroite) == .recule)
        #expect(disposition.role(pourAbscisse: 0.98, ordonnee: 0.5, sens: .gaucheDroite) == .avance)
        #expect(disposition.role(pourAbscisse: 0.5, ordonnee: 0.02, sens: .gaucheDroite) == .recule)
        #expect(disposition.role(pourAbscisse: 0.5, ordonnee: 0.98, sens: .gaucheDroite) == .avance)

        // Le menu se limite au rectangle central.
        #expect(disposition.role(pourAbscisse: 0.5, ordonnee: 0.5, sens: .gaucheDroite) == .menu)

        let menu = disposition.zones(sens: .gaucheDroite).filter { $0.role == .menu }
        let centrale = DispositionDeZones.partDeLaBandeCentrale

        #expect(menu.count == 1)
        #expect(proches(menu.first?.part ?? 0, centrale * centrale))
    }

    @Test("Kindle donne la plus grande surface a l avance, sous un bandeau de menu")
    func kindleDonneLaPlaceALAvance() {
        let disposition = DispositionDeZones.kindle

        // Le bandeau de menu occupe la tete du travers, sur toute la longueur.
        #expect(disposition.role(pourAbscisse: 0.1, ordonnee: 0.1, sens: .gaucheDroite) == .menu)
        #expect(disposition.role(pourAbscisse: 0.9, ordonnee: 0.1, sens: .gaucheDroite) == .menu)

        // Sous lui, une petite bande recule et tout le reste avance.
        #expect(disposition.role(pourAbscisse: 0.1, ordonnee: 0.5, sens: .gaucheDroite) == .recule)
        #expect(disposition.role(pourAbscisse: 0.5, ordonnee: 0.5, sens: .gaucheDroite) == .avance)
        #expect(disposition.role(pourAbscisse: 0.9, ordonnee: 0.9, sens: .gaucheDroite) == .avance)

        let parts = Dictionary(
            disposition.zones(sens: .gaucheDroite).map { ($0.role, $0.part) },
            uniquingKeysWith: { premiere, seconde in premiere + seconde }
        )
        let avance = parts[.avance] ?? 0
        let recule = parts[.recule] ?? 0

        #expect(avance > recule, "Le geste le plus frequent recoit la plus grande surface")
    }

    // MARK: Orientation par le sens de lecture

    @Test(
        "Le sens de lecture oriente les zones, dans les quatre dispositions",
        arguments: DispositionDeZones.allCases
    )
    func orientationParLeSens(disposition: DispositionDeZones) {
        for abscisse in Self.points {
            for ordonnee in Self.points {
                let reference = disposition.role(
                    pourAbscisse: abscisse,
                    ordonnee: ordonnee,
                    sens: .gaucheDroite
                )

                // En droite a gauche, la lecture avance vers la gauche : le
                // point symetrique porte le meme role.
                let symetrique = disposition.role(
                    pourAbscisse: 1 - abscisse,
                    ordonnee: ordonnee,
                    sens: .droiteGauche
                )

                #expect(
                    symetrique == reference || estSurUnBord(abscisse),
                    "\(disposition.rawValue), point \(abscisse) \(ordonnee)"
                )

                // En vertical, l axe de lecture bascule : le point transpose
                // porte le meme role.
                let transpose = disposition.role(
                    pourAbscisse: ordonnee,
                    ordonnee: abscisse,
                    sens: .hautBas
                )

                #expect(
                    transpose == reference || estSurUnBord(abscisse) || estSurUnBord(ordonnee),
                    "\(disposition.rawValue), point \(abscisse) \(ordonnee)"
                )
            }
        }
    }

    @Test("En droite a gauche, la bande de tete avance et celle de queue recule")
    func sensDroiteGauche() {
        for disposition in [DispositionDeZones.standard, .bord, .kindle] {
            #expect(
                disposition.role(pourAbscisse: 0.02, ordonnee: 0.5, sens: .droiteGauche) == .avance,
                "\(disposition.rawValue)"
            )
            #expect(
                disposition.role(pourAbscisse: 0.98, ordonnee: 0.5, sens: .droiteGauche) == .recule,
                "\(disposition.rawValue)"
            )
        }
    }

    // MARK: Inverser les zones

    @Test(
        "L inversion echange les deux roles actifs et ne touche pas au menu",
        arguments: DispositionDeZones.allCases,
        SensDeLecture.allCases
    )
    func inversionEchangeLesRolesActifs(disposition: DispositionDeZones, sens: SensDeLecture) {
        for abscisse in Self.points {
            for ordonnee in Self.points {
                let normal = disposition.role(pourAbscisse: abscisse, ordonnee: ordonnee, sens: sens)
                let inverse = disposition.role(
                    pourAbscisse: abscisse,
                    ordonnee: ordonnee,
                    sens: sens,
                    zonesInversees: true
                )

                #expect(
                    inverse == normal.inverse,
                    "\(disposition.rawValue), \(sens.rawValue), point \(abscisse) \(ordonnee)"
                )

                if normal == .menu {
                    #expect(inverse == .menu, "L inversion ne touche jamais a la zone de menu")
                }
            }
        }
    }

    @Test("L inversion s applique apres le sens de lecture, jamais avant")
    func inversionApresLeSens() {
        // Le piege que ce test ferme : inverser la geometrie plutot que les
        // roles reviendrait, en droite a gauche, a inverser deux fois. Le
        // reglage n aurait alors aucun effet visible dans le sens le plus
        // courant du produit, et serait juste dans les deux autres.
        for disposition in [DispositionDeZones.standard, .bord, .kindle] {
            for sens in SensDeLecture.allCases {
                let point = Self.pointDeTete(sens: sens)
                let normal = disposition.role(
                    pourAbscisse: point.abscisse,
                    ordonnee: point.ordonnee,
                    sens: sens
                )
                let inverse = disposition.role(
                    pourAbscisse: point.abscisse,
                    ordonnee: point.ordonnee,
                    sens: sens,
                    zonesInversees: true
                )

                #expect(normal.navigue, "\(disposition.rawValue), \(sens.rawValue)")
                #expect(inverse != normal, "\(disposition.rawValue), \(sens.rawValue)")
            }
        }
    }

    /// Point pose sur la bande de tete de l axe de lecture, hors de toute zone
    /// de menu, quelle que soit la disposition.
    ///
    /// Il suit l axe : en vertical la tete est en haut, et le travers passe par
    /// le milieu pour eviter le bandeau de menu de Kindle.
    static func pointDeTete(sens: SensDeLecture) -> (abscisse: Double, ordonnee: Double) {
        let tete = 0.02
        let milieu = 0.5

        return sens.estVertical ? (milieu, tete) : (tete, milieu)
    }

    @Test("L inversion ne reveille aucune zone quand les zones sont desactivees")
    func inversionSansZones() {
        for sens in SensDeLecture.allCases {
            let role = DispositionDeZones.desactive.role(
                pourAbscisse: 0.02,
                ordonnee: 0.5,
                sens: sens,
                zonesInversees: true
            )

            #expect(role == .menu, "\(sens.rawValue)")
        }
    }

    // MARK: Bornes

    @Test("Un point hors de la surface est ramene dans la surface")
    func pointHorsSurface() {
        let disposition = DispositionDeZones.standard

        #expect(
            disposition.role(pourAbscisse: -2, ordonnee: 0.5, sens: .gaucheDroite)
                == disposition.role(pourAbscisse: 0, ordonnee: 0.5, sens: .gaucheDroite)
        )
        #expect(
            disposition.role(pourAbscisse: 4, ordonnee: 0.5, sens: .gaucheDroite)
                == disposition.role(pourAbscisse: 1, ordonnee: 0.5, sens: .gaucheDroite)
        )
    }

    /// Vrai quand deux parts de surface sont la meme, au bruit de calcul pres.
    private func proches(_ gauche: Double, _ droite: Double) -> Bool {
        abs(gauche - droite) < 0.000_001
    }

    /// Vrai quand la coordonnee tombe sur un bord de bande.
    ///
    /// Un bord appartient a la bande qui commence la, pas a celle qui finit. La
    /// symetrie d un point de bord bascule donc d une bande a l autre, ce qui
    /// est attendu et sans consequence : deux appuis distants d un centieme de
    /// surface ne se distinguent pas au doigt.
    private func estSurUnBord(_ valeur: Double) -> Bool {
        [0, DispositionDeZones.partDUneBande, 1 - DispositionDeZones.partDUneBande, 1]
            .contains { abs($0 - valeur) < 0.000_001 }
    }
}
