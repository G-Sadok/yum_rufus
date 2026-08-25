import Core
import Foundation
import Testing
@testable import ImagePipeline

/// Couvre la premiere etape de la chaine de traitement de la section 6.3 : les
/// marges de scan disparaissent, le dessin ne bouge pas, et une page dont le
/// fond est deja sombre ou uni n est pas amputee.
struct RognageAutomatiqueTests {
    private let rognage = RognageAutomatique(reglages: .recommande)
    private let pageEntiere = TailleEnPixels(largeur: 200, hauteur: 300)
    private let encre = PageAMarges.Contenu(clair: 200, sombre: 40)

    /// Bloc centre laissant 30 pixels de marge laterale et 50 en haut et en bas.
    private let bloc = PageAMarges.Bloc(origineX: 30, origineY: 50, largeur: 140, hauteur: 200)

    /// Page a marges franches, celle que la plupart des tests reprennent.
    private func scan(fond: UInt8) -> MatriceDeGris? {
        PageAMarges.avecContenu(taille: pageEntiere, fond: fond, bloc: bloc, contenu: encre)
    }

    // MARK: Bordure blanche

    @Test("Un scan a bordure blanche est rogne sur son contenu")
    func bordureBlancheRognee() throws {
        let matrice = try #require(scan(fond: 255))

        let zone = rognage.zoneUtile(de: matrice)

        // Le contenu occupe 30..<170 et 50..<250, la marge de securite rend
        // quatre pixels de chaque cote.
        #expect(zone.origineX == 26)
        #expect(zone.origineY == 46)
        #expect(zone.taille == TailleEnPixels(largeur: 148, hauteur: 208))
    }

    @Test("Les quatre marges sont mesurees chacune de leur cote")
    func margesAsymetriques() throws {
        let matrice = try #require(PageAMarges.avecContenu(
            taille: TailleEnPixels(largeur: 120, hauteur: 160),
            fond: 255,
            bloc: PageAMarges.Bloc(origineX: 5, origineY: 10, largeur: 90, hauteur: 110),
            contenu: encre
        ))

        let zone = rognage.zoneUtile(de: matrice)

        // Marge gauche de 5 pixels, dont la securite ne peut rendre que 4.
        #expect(zone.origineX == 1)
        #expect(zone.origineY == 6)
        #expect(zone.taille == TailleEnPixels(largeur: 98, hauteur: 118))
    }

    @Test("Le chemin complet, image comprise, trouve la meme zone que la matrice")
    func memeZoneDepuisLImage() throws {
        let matrice = try #require(PageAMarges.avecContenu(
            taille: TailleEnPixels(largeur: 120, hauteur: 160),
            fond: 255,
            bloc: PageAMarges.Bloc(origineX: 5, origineY: 10, largeur: 90, hauteur: 110),
            contenu: encre
        ))
        let image = try #require(PageAMarges.image(de: matrice))

        // Les marges sont volontairement asymetriques : une matrice lue a
        // l envers rendrait ici une origine et une hauteur echangees.
        #expect(rognage.zoneUtile(de: image) == rognage.zoneUtile(de: matrice))
    }

    @Test("La page rognee garde tous les pixels de contenu")
    func contenuIntegralementConserve() throws {
        let matrice = try #require(scan(fond: 255))
        let page = try #require(PageAMarges.page(de: matrice))

        let rognee = rognage.rogner(page)
        let apres = try #require(MatriceDeGris(rognee.image))

        #expect(rognee.tailleDecodee == TailleEnPixels(largeur: 148, hauteur: 208))
        #expect(rognee.tailleDOrigine == pageEntiere)
        #expect(rognee.niveau == .affichage)
        #expect(
            PageAMarges.pixelsDeContenu(dans: apres, fond: 255)
                == PageAMarges.pixelsDeContenu(dans: matrice, fond: 255)
        )
    }

    @Test("La page rognee occupe reellement moins de memoire")
    func memoireReellementRendue() throws {
        let matrice = try #require(scan(fond: 255))
        let page = try #require(PageAMarges.page(de: matrice))

        let rognee = rognage.rogner(page)

        // Une image seulement decoupee garderait la matrice complete vivante
        // derriere elle, et le cache memoire compterait faux.
        #expect(rognee.octetsEnMemoire < page.octetsEnMemoire)
    }

    // MARK: Bordure noire et fond sombre

    @Test("Une bordure noire est rognee comme une bordure blanche")
    func bordureNoireRognee() throws {
        let matrice = try #require(PageAMarges.avecContenu(
            taille: pageEntiere,
            fond: 0,
            bloc: bloc,
            contenu: PageAMarges.Contenu(clair: 255, sombre: 160)
        ))

        let zone = rognage.zoneUtile(de: matrice)

        #expect(zone.origineX == 26)
        #expect(zone.origineY == 46)
        #expect(zone.taille == TailleEnPixels(largeur: 148, hauteur: 208))
    }

    @Test("Une page a fond noir entierement dessinee n est pas rognee")
    func pageAFondNoirNonRognee() throws {
        // Fond noir, dessin sombre jusqu au bord : aucune bande n est unie.
        let matrice = try #require(PageAMarges.texturee(taille: pageEntiere, claire: 90, sombre: 0))

        #expect(rognage.zoneUtile(de: matrice).couvreToute(pageEntiere))
    }

    @Test("Une page noire unie n est pas reduite a rien")
    func pageNoireUnie() throws {
        let matrice = try #require(PageAMarges.unie(taille: pageEntiere, valeur: 0))

        #expect(rognage.zoneUtile(de: matrice).couvreToute(pageEntiere))
    }

    @Test("Une page blanche unie n est pas reduite a rien")
    func pageBlancheUnie() throws {
        let matrice = try #require(PageAMarges.unie(taille: pageEntiere, valeur: 255))

        #expect(rognage.zoneUtile(de: matrice).couvreToute(pageEntiere))
    }

    @Test("Une page noire unie traverse la chaine sans changer de taille")
    func pageNoireUnieInchangeeApresRognage() throws {
        let matrice = try #require(PageAMarges.unie(taille: pageEntiere, valeur: 0))
        let page = try #require(PageAMarges.page(de: matrice))

        let rognee = rognage.rogner(page)

        #expect(rognee.tailleDecodee == page.tailleDecodee)
        #expect(rognee.octetsEnMemoire == page.octetsEnMemoire)
    }

    // MARK: Ce qui n est pas une marge

    @Test("Un fond gris uni n est ni blanc ni noir, il n est pas rogne")
    func fondGrisNonRogne() throws {
        let matrice = try #require(scan(fond: 128))

        #expect(rognage.zoneUtile(de: matrice).couvreToute(pageEntiere))
    }

    @Test("Un fond blanc legerement bruite reste vu comme une marge")
    func fondBlancLegerementBruite() throws {
        // Deux niveaux d ecart, ce que produit une compression JPEG sur du blanc.
        let matrice = try #require(PageAMarges.avecFondAlterne(
            taille: pageEntiere,
            fond: PageAMarges.Contenu(clair: 255, sombre: 251),
            bloc: bloc
        ))

        #expect(rognage.zoneUtile(de: matrice).taille == TailleEnPixels(largeur: 148, hauteur: 208))
    }

    @Test("Un fond clair mais trame depasse le seuil de variance et reste")
    func fondClairTrameConserve() throws {
        // Moyenne a 240 sur 255, donc encore proche du blanc, mais une variance
        // deux fois au dessus du seuil : c est une trame, pas une marge.
        let matrice = try #require(PageAMarges.avecFondAlterne(
            taille: pageEntiere,
            fond: PageAMarges.Contenu(clair: 255, sombre: 225),
            bloc: bloc
        ))

        #expect(rognage.zoneUtile(de: matrice).couvreToute(pageEntiere))
    }

    @Test("Un rognage qui emporterait presque toute la page est refuse")
    func rognageTropAgressifRefuse() throws {
        let matrice = try #require(PageAMarges.avecContenu(
            taille: pageEntiere,
            fond: 255,
            bloc: PageAMarges.Bloc(origineX: 98, origineY: 148, largeur: 4, hauteur: 4),
            contenu: encre
        ))

        // La zone detectee ne garderait que 0,24 pour cent de la surface.
        #expect(rognage.zoneUtile(de: matrice).couvreToute(pageEntiere))
    }

    // MARK: Reglages

    @Test("Le rognage inactif rend la page telle quelle")
    func rognageInactif() throws {
        let matrice = try #require(scan(fond: 255))
        let page = try #require(PageAMarges.page(de: matrice))
        let inactif = RognageAutomatique()

        #expect(inactif.reglages.actif == false)
        #expect(inactif.zoneUtile(de: matrice).couvreToute(pageEntiere))
        #expect(inactif.rogner(page).tailleDecodee == page.tailleDecodee)
    }

    @Test("Une marge de securite nulle colle au contenu")
    func margeDeSecuriteNulle() throws {
        let matrice = try #require(scan(fond: 255))
        let colle = RognageAutomatique(reglages: ReglagesDeRognage(actif: true, margeDeSecurite: 0))

        let zone = colle.zoneUtile(de: matrice)

        #expect(zone.origineX == 30)
        #expect(zone.origineY == 50)
        #expect(zone.taille == TailleEnPixels(largeur: 140, hauteur: 200))
    }

    @Test("Une marge de securite plus large que la bordure s arrete au bord")
    func margeDeSecuriteBornee() throws {
        let matrice = try #require(scan(fond: 255))
        let large = RognageAutomatique(reglages: ReglagesDeRognage(actif: true, margeDeSecurite: 400))

        #expect(large.zoneUtile(de: matrice).couvreToute(pageEntiere))
    }

    @Test("Les reglages ramenent chaque valeur dans son domaine")
    func reglagesBornes() {
        let reglages = ReglagesDeRognage(
            actif: true,
            seuilDeVariance: -1,
            toleranceDeBlanc: 4,
            toleranceDeNoir: -0.5,
            margeDeSecurite: -8,
            partMinimaleConservee: 9
        )

        #expect(reglages.seuilDeVariance == 0)
        #expect(reglages.toleranceDeBlanc == 1)
        #expect(reglages.toleranceDeNoir == 0)
        #expect(reglages.margeDeSecurite == 0)
        #expect(reglages.partMinimaleConservee == 1)
    }

    @Test("La marge de securite par defaut vaut les quatre pixels du cahier")
    func margeParDefaut() {
        #expect(ReglagesDeRognage.recommande.margeDeSecurite == 4)
        #expect(ReglagesDeRognage.parDefaut.actif == false)
    }
}
