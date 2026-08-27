import Core
import Foundation
import Testing
@testable import DesignSystem

//
// Couvre la surimpression du tutoriel des zones de toucher, section 5.7.
//
// Les valeurs sont comparees a la ligne du document elle meme, jamais a une
// copie. Une modification de la phrase des zones dans DESIGN-SPEC.md qui
// n arriverait pas jusqu au code fait alors virer la suite au rouge, ce qui est
// le but.
//

struct TutorielDeZonesDansLaVueTests {
    private let libelles = LibellesDeZonesDeToucher(
        pageSuivante: "Page suivante",
        pagePrecedente: "Page precedente",
        afficherLesBarres: "Afficher les barres"
    )

    /// Phrase du document qui decrit la seule apparition des zones.
    private func phraseDesZones() throws -> String {
        try #require(
            try SpecificationDeDesign.ligne(contenant: "Les zones ne sont jamais visibles")
        )
    }

    // MARK: Jetons

    @Test("Les opacites du tutoriel sont celles du document")
    func opacitesDuDocument() throws {
        let phrase = try phraseDesZones()

        #expect(phrase.contains("6 pour cent"))
        #expect(phrase.contains("3 pour cent"))
        #expect(phrase.contains("accent"))
        #expect(phrase.contains("blanc"))

        #expect(Jetons.ZonesDeToucher.opaciteDeZoneActive == 0.06)
        #expect(Jetons.ZonesDeToucher.opaciteDeZoneDeMenu == 0.03)
        #expect(Jetons.ZonesDeToucher.couleurDeZoneDeMenu.notation == "#FFFFFF")
    }

    @Test("La duree du tutoriel est celle du document")
    func dureeDuDocument() throws {
        let phrase = try phraseDesZones()

        #expect(phrase.contains("4 secondes"))
        #expect(TutorielDeZones.duree == 4)
    }

    @Test("Les trois colonnes du lecteur pagine sont celles du document")
    func colonnesDuDocument() throws {
        let ligne = try #require(
            try SpecificationDeDesign.ligne(contenant: "Zones de toucher")
        )

        #expect(ligne.contains("28 pour cent"))
        #expect(ligne.contains("44 pour cent"))

        #expect(DispositionDeZones.partDUneBande == 0.28)
        #expect(abs(DispositionDeZones.partDeLaBandeCentrale - 0.44) < 0.000_001)
    }

    @Test("La surimpression n emprunte aucune duree hors du tableau 1.9")
    func transitionDuTableau() {
        #expect(
            Jetons.Mouvement.parTransition.values.contains(Jetons.ZonesDeToucher.apparition)
        )
    }

    // MARK: Couleurs

    @Test("Seules les zones qui tournent une page portent l accent")
    func accentSurLesSeulesZonesActives() {
        for theme in ThemeDeSurface.allCases {
            for apparence in Apparence.allCases {
                let palette = Palette.pour(theme: theme, apparence: apparence)

                #expect(AplatDeZone.couleur(de: .avance, palette: palette) == palette.semantiques.accent)
                #expect(AplatDeZone.couleur(de: .recule, palette: palette) == palette.semantiques.accent)
                #expect(
                    AplatDeZone.couleur(de: .menu, palette: palette)
                        == Jetons.ZonesDeToucher.couleurDeZoneDeMenu
                )
            }
        }
    }

    @Test("Une zone active se distingue de la zone de menu par plus que sa couleur")
    func opacitesDistinctes() {
        #expect(AplatDeZone.opacite(de: .avance) == Jetons.ZonesDeToucher.opaciteDeZoneActive)
        #expect(AplatDeZone.opacite(de: .recule) == Jetons.ZonesDeToucher.opaciteDeZoneActive)
        #expect(AplatDeZone.opacite(de: .menu) == Jetons.ZonesDeToucher.opaciteDeZoneDeMenu)
    }

    // MARK: Libelles

    @Test("Chaque zone porte une etiquette d accessibilite")
    func etiquettesDesZones() {
        for role in RoleDeZone.allCases {
            #expect(libelles.etiquette(de: role).isEmpty == false, "\(role.rawValue)")
        }

        #expect(libelles.etiquette(de: .avance) != libelles.etiquette(de: .recule))
    }

    @Test("Les etiquettes nomment une action de lecture, jamais un bord d ecran")
    func etiquettesSansDirectionDEcran() {
        // Une etiquette qui dirait la gauche ou la droite deviendrait fausse
        // des que le sens de lecture change, ou que l option Inverser les zones
        // est active.
        let interdits = ["gauche", "droite", "haut", "bas"]

        for role in RoleDeZone.allCases {
            let etiquette = libelles.etiquette(de: role).lowercased()

            for mot in interdits {
                #expect(etiquette.contains(mot) == false, "\(role.rawValue) contient \(mot)")
            }
        }
    }

    @Test("Les etiquettes suivent les regles d ecriture de la section 6")
    func reglesDEcriture() {
        // Le caractere interdit par la regle 0 est construit par son code, pour
        // que ce fichier ne le porte pas en clair et ne se signale pas lui meme
        // au controle 4.
        let tiretCadratin = String(UnicodeScalar(0x2014) ?? " ")

        for role in RoleDeZone.allCases {
            let etiquette = libelles.etiquette(de: role)

            #expect(etiquette.contains("!") == false)
            #expect(etiquette.contains(tiretCadratin) == false)
        }
    }

    // MARK: Visibilite

    @Test("Hors tutoriel, la vue ne recoit aucune zone a dessiner")
    func aucuneZoneHorsTutoriel() {
        let tutoriel = TutorielDeZones()

        #expect(tutoriel.zones(disposition: .standard, sens: .droiteGauche).isEmpty)
    }
}
