import Foundation
import Testing
@testable import DesignSystem

/// Verifie la section 7 de DESIGN-SPEC.md par la mesure, et non par la lecture.
///
/// Les ratios du document etaient jusqu ici des nombres ecrits dans un tableau,
/// que rien ne recalculait. Un jeton retouche les rendait faux en silence. Ces
/// tests recalculent chaque paire depuis les jetons du code, et comparent au
/// document lu sur disque.
struct ContrasteDesJetonsTests {
    /// Ecart admis entre la mesure du code et le ratio ecrit dans le document.
    ///
    /// Le document arrondit ses ratios au dixieme et sa table a ete relevee a
    /// la main : l ecart le plus large constate vaut 0.4, sur `accent` en
    /// variante sombre. La borne est posee juste au dessus. Un ecart plus grand
    /// signale une vraie divergence entre le code et le document, pas un
    /// arrondi.
    private static let ecartAdmis = 0.5

    /// Surfaces qui portent du texte, section 1.1.
    ///
    /// `surface.reader` en est absente : c est le fond d une page de manga,
    /// aucune interface ne s y pose, section 5.7.
    private static let surfacesQuiPortentDuTexte = [
        "surface.canvas",
        "surface.window",
        "surface.chrome",
        "surface.sidebar",
        "surface.card",
        "surface.cardHover",
        "surface.menu",
        "surface.selected",
        "surface.field",
        "surface.sheet",
        "surface.premium",
    ]

    // MARK: La table du document

    @Test("Les ratios de la section 7 se retrouvent par le calcul sur surface.card")
    func ratiosDuDocument() throws {
        let table = try tableDesRatios()

        #expect(table.lignes.count == 5, "La section 7 mesure cinq paires")

        for ligne in table.lignes {
            let nom = ligne[0]

            for (colonne, apparence) in [(1, Apparence.sombre), (2, Apparence.clair)] {
                let documente = try #require(
                    ratio(ligne[colonne]),
                    "Ratio illisible pour \(nom) en \(apparence.rawValue)"
                )

                let jeton = try #require(
                    Self.jeton(nomme: nom, apparence: apparence),
                    "Jeton inconnu dans la section 7 : \(nom)"
                )

                // Le document mesure sur `surface.card`. Il ne nomme pas de
                // theme, et ses valeurs collent a Midnight, le theme par
                // defaut de la section 1.1.
                let carte = JetonsDeSurface.pour(theme: .midnight, apparence: apparence).card
                let mesure = jeton.contraste(avec: carte)

                #expect(
                    abs(mesure - documente) <= Self.ecartAdmis,
                    "\(nom) en \(apparence.rawValue) mesure \(mesure), le document ecrit \(documente)"
                )
            }
        }
    }

    @Test("Les jetons porteurs d information tiennent 4.5:1 sur surface.card")
    func seuilSurLaCarte() {
        for apparence in Apparence.allCases {
            for theme in ThemeDeSurface.allCases {
                let carte = JetonsDeSurface.pour(theme: theme, apparence: apparence).card

                for (nom, jeton) in Self.jetonsQuiTiennentSurLaCarte(apparence) {
                    #expect(
                        jeton.contraste(avec: carte) >= Jetons.Contraste.texteCourant,
                        "\(nom) sur surface.card en \(theme.rawValue) \(apparence.rawValue)"
                    )
                }
            }
        }
    }

    /// `accent.text` est le seul jeton porteur d information qui ne tienne pas
    /// le seuil sur `surface.card`, et c est un defaut du document lui meme.
    ///
    /// En variante sombre, `accent.text` vaut `#0A84FF`, le meme que `accent`.
    /// La section 7 lui prete 4.9:1 sur `surface.card`. Le calcul donne 4.46:1
    /// en Midnight, 5.02:1 en Obsidian, 4.40:1 en Slate et 4.31:1 en Paper :
    /// trois themes sur quatre sont sous le seuil que la meme section declare
    /// non negociable. Le chiffre du document a ete releve a la main et il est
    /// faux.
    ///
    /// Le code ne retouche pas le jeton, qui appartient au document. Il le
    /// derive au moment de le poser, selon la regle que la section 1.3 a deja
    /// posee pour ce meme jeton en variante claire. Ce test verifie que la
    /// derivation ferme l ecart dans les quatre themes et les deux apparences.
    @Test("La derivation ferme l ecart d accent.text sur surface.card")
    func accentTextSurLaCarte() {
        for apparence in Apparence.allCases {
            for theme in ThemeDeSurface.allCases {
                let carte = JetonsDeSurface.pour(theme: theme, apparence: apparence).card
                let jeton = JetonsSemantiques.pour(apparence: apparence).accentText
                let posee = Lisibilite.derivee(jeton, sur: [carte])

                #expect(
                    posee.contraste(avec: carte) >= Jetons.Contraste.texteCourant,
                    "accent.text pose sur surface.card en \(theme.rawValue) \(apparence.rawValue)"
                )
            }
        }
    }

    // MARK: Les deux exceptions declarees

    @Test("Les deux exceptions de la section 7 sont les deux seules, et tiennent 3:1")
    func exceptionsDeclarees() {
        let sombre = JetonsDeTexte.pour(apparence: .sombre)
        let carte = JetonsDeSurface.pour(theme: .midnight, apparence: .sombre).card

        let quaternaire = sombre.quaternary.contraste(avec: carte)
        #expect(quaternaire < Jetons.Contraste.texteCourant, "Premiere exception, texte redondant")
        #expect(quaternaire >= Jetons.Contraste.grandTexte, "Elle tient au moins le seuil de 3:1")

        for apparence in Apparence.allCases {
            let textes = JetonsDeTexte.pour(apparence: apparence)
            let accent = JetonsSemantiques.pour(apparence: apparence).accent
            let pastille = textes.onAccent.contraste(avec: accent)

            #expect(pastille < Jetons.Contraste.texteCourant, "Seconde exception, pastille de non lus")
            #expect(pastille >= Jetons.Contraste.grandTexte, "Elle tient au moins le seuil de 3:1")
        }

        // Toute autre utilisation de `text.quaternary` passe a `text.tertiary`,
        // qui doit donc tenir le seuil plein la ou le quaternaire ne le tient
        // pas. La verification precedente le couvre deja sur `surface.card`.
        #expect(
            sombre.tertiary.contraste(avec: carte) >= Jetons.Contraste.texteCourant,
            "Le repli du quaternaire tient le seuil plein"
        )
    }

    // MARK: La derivation de lisibilite

    @Test("La derivation ferme l ecart sur toutes les surfaces qui portent du texte")
    func derivationSurToutesLesSurfaces() {
        for apparence in Apparence.allCases {
            for theme in ThemeDeSurface.allCases {
                let surfaces = JetonsDeSurface.pour(theme: theme, apparence: apparence).parNom

                for nomDeSurface in Self.surfacesQuiPortentDuTexte {
                    guard let surface = surfaces[nomDeSurface] else {
                        Issue.record("Surface inconnue : \(nomDeSurface)")
                        continue
                    }

                    for (nom, jeton) in Self.jetonsPorteursDInformation(apparence) {
                        let derivee = Lisibilite.derivee(jeton, sur: [surface])

                        #expect(
                            derivee.contraste(avec: surface) >= Jetons.Contraste.texteCourant,
                            "\(nom) derive sur \(nomDeSurface), \(theme.rawValue) \(apparence.rawValue)"
                        )
                    }
                }
            }
        }
    }

    @Test("La derivation rend le jeton inchange quand il tient deja le seuil")
    func derivationNeutre() {
        for apparence in Apparence.allCases {
            let carte = JetonsDeSurface.pour(theme: .midnight, apparence: apparence).card

            for (nom, jeton) in Self.jetonsQuiTiennentSurLaCarte(apparence) {
                #expect(
                    Lisibilite.derivee(jeton, sur: [carte]) == jeton,
                    "\(nom) tient deja le seuil sur surface.card, il ne doit pas bouger"
                )
            }
        }
    }

    @Test("La derivation tient le seuil sur la pire des surfaces citees")
    func derivationSurPlusieursSurfaces() {
        let surfaces = JetonsDeSurface.pour(theme: .midnight, apparence: .sombre)
        let fonds = [surfaces.card, surfaces.cardHover, surfaces.menu, surfaces.premium]
        let accentText = JetonsSemantiques.pour(apparence: .sombre).accentText
        let derivee = Lisibilite.derivee(accentText, sur: fonds)

        for fond in fonds {
            #expect(derivee.contraste(avec: fond) >= Jetons.Contraste.texteCourant)
        }
    }

    @Test("Une liste de surfaces vide rend la couleur telle quelle")
    func derivationSansSurface() {
        let jeton = JetonsSemantiques.pour(apparence: .sombre).accentText
        #expect(Lisibilite.derivee(jeton, sur: []) == jeton)
    }

    // MARK: La formule

    @Test("La formule de contraste reproduit les deux bornes connues")
    func bornesDeLaFormule() {
        let blanc = CouleurHexadecimale(0xFFFFFF)
        let noir = CouleurHexadecimale(0x000000)

        #expect(abs(blanc.contraste(avec: noir) - 21) < 0.001, "Le rapport maximal vaut 21")
        #expect(abs(blanc.contraste(avec: blanc) - 1) < 0.001, "Une couleur avec elle meme vaut 1")
        #expect(
            abs(blanc.contraste(avec: noir) - noir.contraste(avec: blanc)) < 0.001,
            "Le rapport est symetrique"
        )
    }

    @Test("Une couleur translucide se mesure apres composition sur son fond")
    func compositionAvantMesure() {
        let voile = CouleurHexadecimale(0x000000, opacite: 0.5)
        let blanc = CouleurHexadecimale(0xFFFFFF)
        let composee = voile.composee(sur: blanc)

        #expect(composee.opacite == 1, "La composition rend une couleur opaque")
        #expect(composee.rouge == 128, "Moitie de noir sur du blanc")
        #expect(blanc.composee(sur: composee) == blanc, "Une couleur opaque se rend elle meme")
    }

    @Test("Les seuils du code sont ceux du tableau de la section 7")
    func seuilsDuDocument() throws {
        let lignes = try SpecificationDeDesign.lignes()

        #expect(
            lignes.contains { $0.contains("| Contraste, texte sous 18 px | 4.5:1 minimum |") },
            "Le document fixe 4.5:1 sous 18 px"
        )
        #expect(
            lignes.contains { $0.contains("| Contraste, texte 18 px et plus | 3:1 minimum |") },
            "Le document fixe 3:1 a 18 px et plus"
        )

        #expect(Jetons.Contraste.texteCourant == 4.5)
        #expect(Jetons.Contraste.grandTexte == 3)
        #expect(Jetons.Contraste.seuil(pourTailleDeTexte: 17) == 4.5)
        #expect(Jetons.Contraste.seuil(pourTailleDeTexte: 18) == 3)
    }

    // MARK: Lecture du document

    /// Le tableau des ratios de la section 7, reconnu par ses en tetes.
    private func tableDesRatios() throws -> TableauMarkdown {
        let tableaux = try SpecificationDeDesign.tableaux()
            .filter { $0.entetes == ["Paire", "Sombre", "Clair"] }

        return try #require(tableaux.first, "La section 7 doit porter la table des ratios")
    }

    /// `14.9:1` devient 14.9.
    private func ratio(_ cellule: String) -> Double? {
        Double(cellule.components(separatedBy: ":").first ?? "")
    }

    /// Jeton du document, par le nom que la section 7 lui donne.
    ///
    /// La cinquieme ligne s ecrit `accent` ou `accent.text` : les deux jetons
    /// ne different qu en variante claire, et c est `accent.text` qui porte le
    /// texte sous 18 px, donc c est lui qu on mesure.
    private static func jeton(nomme nom: String, apparence: Apparence) -> CouleurHexadecimale? {
        if nom.hasPrefix("accent") {
            return JetonsSemantiques.pour(apparence: apparence).accentText
        }

        return JetonsDeTexte.pour(apparence: apparence).parNom[nom]
    }

    /// Jetons qui portent une information par eux memes, et doivent donc tenir
    /// le seuil plein de la section 7.
    ///
    /// Sont exclus : `text.quaternary` et `text.onAccent`, couverts par les
    /// deux exceptions declarees, `text.disabled`, qui marque un element hors
    /// service, et `text.emptyGlyph`, qui n est pas du texte mais un glyphe
    /// dont le titre voisin porte le sens.
    private static func jetonsPorteursDInformation(
        _ apparence: Apparence
    ) -> [(String, CouleurHexadecimale)] {
        let textes = JetonsDeTexte.pour(apparence: apparence)
        let semantiques = JetonsSemantiques.pour(apparence: apparence)

        return [
            ("text.primary", textes.primary),
            ("text.secondary", textes.secondary),
            ("text.tertiary", textes.tertiary),
            ("accent.text", semantiques.accentText),
            ("danger", semantiques.danger),
            ("warning", semantiques.warning),
        ]
    }

    /// Ceux des jetons precedents qui tiennent le seuil sans derivation sur
    /// `surface.card`, dans les quatre themes et les deux apparences.
    ///
    /// `accent.text` en est absent, voir `accentTextSurLaCarte`.
    private static func jetonsQuiTiennentSurLaCarte(
        _ apparence: Apparence
    ) -> [(String, CouleurHexadecimale)] {
        jetonsPorteursDInformation(apparence).filter { $0.0 != "accent.text" }
    }
}
