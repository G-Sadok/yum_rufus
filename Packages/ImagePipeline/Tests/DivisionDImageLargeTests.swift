import Core
import Foundation
import Testing
@testable import ImagePipeline

/// Couvre la deuxieme etape de la chaine de traitement de la section 6.3 : une
/// planche plus large que haute est coupee au milieu, les deux moities sont
/// rendues dans l ordre du sens de lecture, et le raccord ne perd ni ne double
/// aucune colonne.
///
/// Chaque cas d ordre est ecrit pour les trois sens. Une implementation qui
/// range juste en gauche a droite et a l envers en droite a gauche passerait
/// inapercue a la relecture, et c est precisement la faute que ce fichier
/// existe pour attraper.
struct DivisionDImageLargeTests {
    private let division = DivisionDImageLarge(reglages: .recommande)

    /// Planche double ordinaire, largeur paire.
    private let planche = TailleEnPixels(largeur: 240, hauteur: 160)

    /// Planche double a largeur impaire, celle qui ne se partage pas en deux
    /// parts egales.
    private let plancheImpaire = TailleEnPixels(largeur: 241, hauteur: 160)

    // MARK: Detection

    @Test("Une planche plus large que haute est divisee")
    func plancheLargeDivisee() {
        #expect(division.doitDiviser(TailleEnPixels(largeur: 3000, hauteur: 2000)))
        #expect(division.doitDiviser(TailleEnPixels(largeur: 2001, hauteur: 2000)))
    }

    @Test("Une page de lecture ordinaire n est pas divisee")
    func pageOrdinaireNonDivisee() {
        #expect(division.doitDiviser(TailleEnPixels(largeur: 1600, hauteur: 2400)) == false)
        #expect(division.doitDiviser(TailleEnPixels(largeur: 2000, hauteur: 2000)) == false)
    }

    @Test("Une taille inconnue ne declenche jamais la division")
    func tailleInconnueNonDivisee() {
        #expect(division.doitDiviser(.nulle) == false)
        #expect(division.doitDiviser(TailleEnPixels(largeur: 3000, hauteur: 0)) == false)
    }

    @Test("Le seuil se releve pour ne couper que les vraies planches doubles")
    func seuilReleve() {
        let stricte = DivisionDImageLarge(reglages: ReglagesDeDivision(actif: true, seuil: 1.4))

        #expect(stricte.doitDiviser(TailleEnPixels(largeur: 2100, hauteur: 2000)) == false)
        #expect(stricte.doitDiviser(TailleEnPixels(largeur: 3000, hauteur: 2000)))
    }

    // MARK: Ordre des moities

    @Test("En droite a gauche, la moitie droite vient en premier")
    func moitieDroiteEnPremierEnDroiteGauche() throws {
        let page = try #require(PlancheLarge.page(taille: planche))

        let moities = division.moities(de: page, sens: .droiteGauche)

        #expect(moities.map(\.moitie) == [.droite, .gauche])
    }

    @Test("En gauche a droite, la moitie gauche vient en premier")
    func moitieGaucheEnPremierEnGaucheDroite() throws {
        let page = try #require(PlancheLarge.page(taille: planche))

        let moities = division.moities(de: page, sens: .gaucheDroite)

        #expect(moities.map(\.moitie) == [.gauche, .droite])
    }

    @Test("En vertical, les moities sont rangees de gauche a droite")
    func ordreEnVertical() throws {
        let page = try #require(PlancheLarge.page(taille: planche))

        #expect(division.moities(de: page, sens: .hautBas).map(\.moitie) == [.gauche, .droite])
    }

    @Test("L ordre rendu est celui que le sens de lecture annonce, dans les trois sens")
    func ordreConformeAuSensDeLecture() throws {
        let page = try #require(PlancheLarge.page(taille: planche))

        for sens in SensDeLecture.allCases {
            let moities = division.moities(de: page, sens: sens)

            #expect(moities.map(\.moitie) == sens.ordreDesMoities, "Sens \(sens.rawValue)")
            #expect(division.decoupes(de: planche, sens: sens).map(\.moitie) == sens.ordreDesMoities)
        }
    }

    @Test("En droite a gauche, la premiere page affichee porte bien les pixels de droite")
    func premierePageEnDroiteGauchePorteLesPixelsDeDroite() throws {
        let page = try #require(PlancheLarge.page(taille: planche))
        let entiere = try #require(MatriceDeGris(page.image))
        let milieu = DivisionDImageLarge.milieu(de: planche.largeur)

        let pages = division.pages(de: page, sens: .droiteGauche)
        let premierePage = try #require(pages.first)
        let premiere = try #require(MatriceDeGris(premierePage.image))

        // Le nom de la moitie ne prouve rien tant que ses pixels ne sont pas
        // ceux du bon cote : une inversion des deux decoupes passerait le test
        // d ordre sans etre vue.
        #expect(PlancheLarge.ecarts(entre: premiere, et: entiere, origineX: milieu) == 0)
    }

    @Test("En gauche a droite, la premiere page affichee porte les pixels de gauche")
    func premierePageEnGaucheDroitePorteLesPixelsDeGauche() throws {
        let page = try #require(PlancheLarge.page(taille: planche))
        let entiere = try #require(MatriceDeGris(page.image))

        let pages = division.pages(de: page, sens: .gaucheDroite)
        let premierePage = try #require(pages.first)
        let premiere = try #require(MatriceDeGris(premierePage.image))

        #expect(PlancheLarge.ecarts(entre: premiere, et: entiere, origineX: 0) == 0)
    }

    // MARK: Raccord

    @Test("Les deux moities se partagent toutes les colonnes, sans trou ni recouvrement")
    func colonnesIntegralementPartagees() {
        for sens in SensDeLecture.allCases {
            for taille in [planche, plancheImpaire] {
                let decoupes = division.decoupes(de: taille, sens: sens)
                let gauche = decoupes.first { $0.moitie == .gauche }
                let droite = decoupes.first { $0.moitie == .droite }

                #expect(gauche?.colonnes.lowerBound == 0, "Sens \(sens.rawValue)")
                #expect(gauche?.colonnes.upperBound == droite?.colonnes.lowerBound, "Sens \(sens.rawValue)")
                #expect(droite?.colonnes.upperBound == taille.largeur, "Sens \(sens.rawValue)")
                #expect(gauche?.taille.hauteur == taille.hauteur, "Sens \(sens.rawValue)")
                #expect(droite?.taille.hauteur == taille.hauteur, "Sens \(sens.rawValue)")
            }
        }
    }

    @Test("Aucun pixel n est perdu ni double au raccord, dans les trois sens")
    func aucunArtefactAuRaccord() throws {
        let page = try #require(PlancheLarge.page(taille: planche))
        let entiere = try #require(MatriceDeGris(page.image))
        let milieu = DivisionDImageLarge.milieu(de: planche.largeur)

        for sens in SensDeLecture.allCases {
            for moitie in division.moities(de: page, sens: sens) {
                let matrice = try #require(MatriceDeGris(moitie.page.image))
                let origineX = moitie.moitie == .gauche ? 0 : milieu

                #expect(
                    PlancheLarge.ecarts(entre: matrice, et: entiere, origineX: origineX) == 0,
                    "Sens \(sens.rawValue), moitie \(moitie.moitie.rawValue)"
                )
            }
        }
    }

    @Test("Les deux colonnes qui bordent la coupe sont celles de la planche")
    func colonnesDuRaccordIntactes() throws {
        let page = try #require(PlancheLarge.page(taille: planche))
        let entiere = try #require(MatriceDeGris(page.image))
        let milieu = DivisionDImageLarge.milieu(de: planche.largeur)

        let moities = division.moities(de: page, sens: .droiteGauche)
        let gauche = try #require(moities.first { $0.moitie == .gauche })
        let droite = try #require(moities.first { $0.moitie == .droite })
        let matriceGauche = try #require(MatriceDeGris(gauche.page.image))
        let matriceDroite = try #require(MatriceDeGris(droite.page.image))

        // La derniere colonne de la moitie gauche et la premiere de la moitie
        // droite sont voisines dans la planche. Un raccord qui doublerait une
        // colonne les rendrait identiques, un raccord qui en perdrait une les
        // eloignerait de deux crans.
        for ligne in 0..<planche.hauteur {
            #expect(
                matriceGauche.valeur(colonne: matriceGauche.largeur - 1, ligne: ligne)
                    == entiere.valeur(colonne: milieu - 1, ligne: ligne),
                "Ligne \(ligne)"
            )
            #expect(
                matriceDroite.valeur(colonne: 0, ligne: ligne)
                    == entiere.valeur(colonne: milieu, ligne: ligne),
                "Ligne \(ligne)"
            )
        }
    }

    @Test("Une largeur impaire donne la colonne du milieu a la moitie de droite")
    func largeurImpaire() throws {
        let page = try #require(PlancheLarge.page(taille: plancheImpaire))
        let entiere = try #require(MatriceDeGris(page.image))
        let milieu = DivisionDImageLarge.milieu(de: plancheImpaire.largeur)

        let moities = division.moities(de: page, sens: .droiteGauche)
        let gauche = try #require(moities.first { $0.moitie == .gauche })
        let droite = try #require(moities.first { $0.moitie == .droite })

        #expect(gauche.page.tailleDecodee == TailleEnPixels(largeur: 120, hauteur: 160))
        #expect(droite.page.tailleDecodee == TailleEnPixels(largeur: 121, hauteur: 160))
        #expect(gauche.page.tailleDecodee.largeur + droite.page.tailleDecodee.largeur == 241)

        // Le partage inegal ne dispense pas de la fidelite au pixel pres.
        let matriceGauche = try #require(MatriceDeGris(gauche.page.image))
        let matriceDroite = try #require(MatriceDeGris(droite.page.image))

        #expect(PlancheLarge.ecarts(entre: matriceGauche, et: entiere, origineX: 0) == 0)
        #expect(PlancheLarge.ecarts(entre: matriceDroite, et: entiere, origineX: milieu) == 0)
    }

    // MARK: Pages rendues

    @Test("Une planche divisee rend deux pages, la planche entiere n en rend qu une")
    func nombreDePagesRendues() throws {
        let large = try #require(PlancheLarge.page(taille: planche))
        let ordinaire = try #require(PlancheLarge.page(taille: TailleEnPixels(largeur: 160, hauteur: 240)))

        #expect(division.pages(de: large, sens: .droiteGauche).count == 2)
        #expect(division.pages(de: ordinaire, sens: .droiteGauche).count == 1)
        #expect(division.moities(de: ordinaire, sens: .droiteGauche).isEmpty)
    }

    @Test("Une page non divisee traverse la chaine sans changer de taille")
    func pageNonDiviseeInchangee() throws {
        let ordinaire = try #require(PlancheLarge.page(taille: TailleEnPixels(largeur: 160, hauteur: 240)))

        let rendue = try #require(division.pages(de: ordinaire, sens: .droiteGauche).first)

        #expect(rendue.tailleDecodee == ordinaire.tailleDecodee)
        #expect(rendue.octetsEnMemoire == ordinaire.octetsEnMemoire)
    }

    @Test("Chaque moitie occupe reellement moins de memoire que la planche")
    func memoireReellementRendue() throws {
        let page = try #require(PlancheLarge.page(taille: planche))

        for moitie in division.moities(de: page, sens: .droiteGauche) {
            // Une image seulement decoupee garderait la matrice complete vivante
            // derriere elle, et le cache memoire compterait deux fois la planche.
            #expect(moitie.page.octetsEnMemoire < page.octetsEnMemoire, "Moitie \(moitie.moitie.rawValue)")
        }
    }

    @Test("La moitie garde la taille d origine du fichier et le niveau de decodage")
    func metadonneesConservees() throws {
        let page = try #require(PlancheLarge.page(taille: planche))

        for moitie in division.moities(de: page, sens: .droiteGauche) {
            #expect(moitie.page.tailleDOrigine == page.tailleDOrigine)
            #expect(moitie.page.niveau == page.niveau)
            #expect(moitie.page.tailleDecodee.hauteur == planche.hauteur)
        }
    }

    // MARK: Reglages

    @Test("La division inactive rend la planche entiere")
    func divisionInactive() throws {
        let page = try #require(PlancheLarge.page(taille: planche))
        let inactive = DivisionDImageLarge()

        #expect(inactive.reglages.actif == false)
        #expect(inactive.doitDiviser(planche) == false)
        #expect(inactive.moities(de: page, sens: .droiteGauche).isEmpty)
        #expect(inactive.decoupes(de: planche, sens: .droiteGauche).isEmpty)

        let rendue = try #require(inactive.pages(de: page, sens: .droiteGauche).first)

        #expect(rendue.tailleDecodee == page.tailleDecodee)
    }

    @Test("Un seuil sous un est ramene a un, faute de quoi tout serait coupe")
    func seuilTropBas() {
        #expect(ReglagesDeDivision(actif: true, seuil: 0.2).seuil == DetectionDePageLarge.seuilParDefaut)
        #expect(ReglagesDeDivision(actif: true, seuil: 0).seuil == DetectionDePageLarge.seuilParDefaut)
    }

    @Test("L empreinte distingue les reglages qui changent le resultat")
    func empreinteDesReglages() {
        let actif = ReglagesDeDivision(actif: true)
        let stricte = ReglagesDeDivision(actif: true, seuil: 1.4)

        #expect(ReglagesDeDivision.parDefaut.empreinte != actif.empreinte)
        #expect(actif.empreinte != stricte.empreinte)

        // Le seuil ne change rien quand l interrupteur est ouvert, deux reglages
        // inactifs ne doivent donc pas creer deux entrees de cache.
        #expect(
            ReglagesDeDivision(actif: false, seuil: 1.4).empreinte
                == ReglagesDeDivision.parDefaut.empreinte
        )
    }

    @Test("L interrupteur est livre inactif, comme le tableau de la section 10 l ecrit")
    func reglagesParDefaut() {
        #expect(ReglagesDeDivision.parDefaut.actif == false)
        #expect(ReglagesDeDivision.recommande.actif)
        #expect(ReglagesDeDivision.recommande.seuil == DetectionDePageLarge.seuilParDefaut)
    }
}
