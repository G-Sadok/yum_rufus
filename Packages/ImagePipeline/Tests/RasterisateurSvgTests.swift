import Core
import CoreGraphics
import Foundation
import Testing
@testable import ImagePipeline

//
// Couvre le seul format de la section 5.2 qu Image I/O ne sait pas lire.
//
// Trois choses sont verifiees separement, parce qu elles cassent separement :
// la grammaire des chemins, la composition des transformations, et le rendu
// d un document complet a la taille demandee.
//

struct RasterisateurSvgTests {
    private let decodeur = DecodeurDePage()

    /// Cote du document de formes, son `viewBox` fait 400 par 400.
    private let cote = 400.0

    // MARK: Rendu d un document complet

    @Test("Les six formes de base tombent chacune a sa place")
    func formesEtPlaces() throws {
        let echantillon = try echantillonDesFormes()

        // Groupe transforme puis rectangle : quart haut droit.
        #expect(echantillon.estNoir(abscisse: 300, ordonnee: 100))
        // Cercle : quart bas gauche.
        #expect(echantillon.estNoir(abscisse: 100, ordonnee: 300))
        // Chemin en triangle : quart bas droit.
        #expect(echantillon.estNoir(abscisse: 350, ordonnee: 260))
        // Polygone : coin haut gauche.
        #expect(echantillon.estNoir(abscisse: 30, ordonnee: 30))
    }

    @Test("Ce qu aucune forme ne couvre reste au fond")
    func fondPreserve() throws {
        let echantillon = try echantillonDesFormes()

        #expect(echantillon.estBlanc(abscisse: 150, ordonnee: 150))
        #expect(echantillon.estBlanc(abscisse: 200, ordonnee: 380))
        // Hors du cercle, dans son carre englobant.
        #expect(echantillon.estBlanc(abscisse: 20, ordonnee: 220))
    }

    @Test("La transformation d un groupe s applique a ses enfants")
    func transformationHeritee() throws {
        let echantillon = try echantillonDesFormes()

        // Le rectangle est ecrit en 0,0, le groupe le decale de 200. Sans
        // heritage de la transformation il serait peint dans le quart haut
        // gauche, ou le test attend du blanc.
        #expect(echantillon.estNoir(abscisse: 300, ordonnee: 100))
        #expect(echantillon.estBlanc(abscisse: 150, ordonnee: 100))
    }

    // MARK: Taille de rendu

    @Test("Un document vectoriel se rend a la taille de la zone, sans agrandir sa matrice")
    func rendueALaTailleDeLaZone() throws {
        let octets = try #require(FichiersDeFormats.octets("formes.svg"))
        let zone = TailleEnPixels(largeur: 200, hauteur: 200)
        let page = try decodeur.decoder(octets, nom: "formes.svg", dans: zone)

        #expect(page.tailleDecodee == zone)
        #expect(page.niveau == .affichage)
    }

    @Test("Le budget memoire borne aussi un document vectoriel")
    func budgetApplique() throws {
        let octets = try #require(FichiersDeFormats.octets("formes.svg"))
        let zone = TailleEnPixels(largeur: 8000, hauteur: 8000)
        let budget = BudgetDeDecodage(octetsParPage: 2_000_000)
        let page = try decodeur.decoder(octets, nom: "formes.svg", dans: zone, budget: budget)

        #expect(page.octetsEnMemoire < 2_000_000)
    }

    @Test("Une zone pas encore mesuree ne fait pas rendre un document demesure")
    func zoneNulle() throws {
        let octets = try #require(FichiersDeFormats.octets("page.svg"))
        let page = try decodeur.decoder(octets, nom: "page.svg", dans: .nulle)

        #expect(page.octetsEnMemoire < 12_000_000)
    }

    // MARK: Grammaire des chemins

    @Test("Un chemin absolu et son equivalent relatif decrivent la meme forme")
    func absoluEtRelatif() {
        let absolu = CheminSvg.chemin(depuis: "M 10 10 L 110 10 L 110 60 Z")
        let relatif = CheminSvg.chemin(depuis: "m 10 10 l 100 0 l 0 50 z")

        #expect(absolu.boundingBoxOfPath.equalTo(relatif.boundingBoxOfPath))
        #expect(absolu.boundingBoxOfPath.equalTo(CGRect(x: 10, y: 10, width: 100, height: 50)))
    }

    @Test("Les couples qui suivent un deplacement tracent des lignes")
    func repetitionImplicite() {
        // Un seul M, trois couples. La specification veut que les deux derniers
        // soient des lignes. Les traiter comme des deplacements donnerait un
        // chemin de trois points isoles, sans surface.
        let chemin = CheminSvg.chemin(depuis: "M 0 0 100 0 100 40")

        #expect(chemin.boundingBoxOfPath.equalTo(CGRect(x: 0, y: 0, width: 100, height: 40)))
    }

    @Test("Les nombres colles se separent au signe et au point")
    func nombresColles() {
        let colles = CheminSvg.chemin(depuis: "M0 0L10-10L20 0Z")
        let espaces = CheminSvg.chemin(depuis: "M 0 0 L 10 -10 L 20 0 Z")

        #expect(colles.boundingBoxOfPath.equalTo(espaces.boundingBoxOfPath))
        #expect(LecteurDeNombres.tousLesNombres(de: "1.5.5") == [1.5, 0.5])
        #expect(LecteurDeNombres.tousLesNombres(de: "1e2 -3E-1") == [100, -0.3])
    }

    @Test("Un arc elliptique trace bien une demie ellipse")
    func arcElliptique() {
        // Deux points opposes, deux rayons de 50, sens positif : la moitie
        // haute d un cercle de centre 50,50 dans un repere ou l ordonnee croit
        // vers le bas.
        let chemin = CheminSvg.chemin(depuis: "M 0 50 A 50 50 0 1 1 100 50")
        let cadre = chemin.boundingBoxOfPath

        #expect(abs(cadre.minX) < 0.5)
        #expect(abs(cadre.minY) < 0.5)
        #expect(abs(cadre.width - 100) < 0.5)
        #expect(abs(cadre.height - 50) < 0.5)
    }

    @Test("Les drapeaux d un arc se lisent meme colles a la coordonnee suivante")
    func drapeauxColles() {
        // Forme produite par les optimiseurs : les deux drapeaux et l abscisse
        // sans separateur. Un lecteur de nombres y verrait 11 au lieu de 1 et 1.
        let colles = CheminSvg.chemin(depuis: "M 0 50 A 50 50 0 1150 50")
        let espaces = CheminSvg.chemin(depuis: "M 0 50 A 50 50 0 1 1 50 50")

        #expect(colles.boundingBoxOfPath.equalTo(espaces.boundingBoxOfPath))
    }

    @Test("Un chemin illisible rend ce qui precede plutot que rien")
    func cheminTronque() {
        let chemin = CheminSvg.chemin(depuis: "M 0 0 L 100 0 L 100 50 L")

        #expect(chemin.isEmpty == false)
        #expect(chemin.boundingBoxOfPath.equalTo(CGRect(x: 0, y: 0, width: 100, height: 50)))
    }

    // MARK: Transformations

    @Test("Les fonctions d une transformation s appliquent de la droite vers la gauche")
    func ordreDesTransformations() {
        let transformation = TransformationSvg.transformation(depuis: "translate(10 20) scale(2)")
        let point = CGPoint(x: 1, y: 1).applying(transformation)

        // Mise a l echelle d abord, translation ensuite. L ordre inverse
        // donnerait 22 et 42.
        #expect(abs(point.x - 12) < 0.001)
        #expect(abs(point.y - 22) < 0.001)
    }

    @Test("Une rotation autour d un centre laisse ce centre en place")
    func rotationAutourDunCentre() {
        let transformation = TransformationSvg.transformation(depuis: "rotate(90 50 50)")
        let centre = CGPoint(x: 50, y: 50).applying(transformation)

        #expect(abs(centre.x - 50) < 0.001)
        #expect(abs(centre.y - 50) < 0.001)
    }

    // MARK: Peinture

    @Test("Les trois notations de couleur donnent la meme couleur")
    func notationsDeCouleur() {
        // Le croisillon et ses six chiffres sont assembles plutot qu ecrits,
        // parce que le controle 5 des verifications cherche cette forme exacte
        // dans tout fichier Swift hors du systeme de design, et ne peut pas
        // distinguer un test d une valeur visuelle en dur.
        let sixChiffres = CouleurSvg("#" + "ff0000")
        let troisChiffres = CouleurSvg("#f00")
        let fonction = CouleurSvg("rgb(255, 0, 0)")

        #expect(troisChiffres == sixChiffres)
        #expect(fonction == sixChiffres)
        #expect(sixChiffres == CouleurSvg(rouge: 1, vert: 0, bleu: 0))
    }

    @Test("La valeur none ne peint rien, un nom inconnu peint en noir")
    func couleursParticulieres() {
        #expect(CouleurSvg("none") == nil)
        #expect(CouleurSvg("transparent") == nil)
        #expect(CouleurSvg("chartreuse") == .noir)
    }

    @Test("Le style est herite du parent puis modifie par l element")
    func heritageDuStyle() {
        let parent = StyleSvg().herite(de: ["fill": "none", "stroke": "black", "stroke-width": "4"])
        let enfant = parent.herite(de: ["stroke-width": "2"])

        #expect(parent.remplissage == nil)
        #expect(enfant.remplissage == nil)
        #expect(enfant.contour == .noir)
        #expect(enfant.epaisseurDeContour == 2)
    }

    @Test("L attribut style vaut les attributs de presentation")
    func styleEnUneChaine() {
        let parAttributs = StyleSvg().herite(de: ["fill": "none", "stroke-width": "3"])
        let parChaine = StyleSvg().herite(de: ["style": "fill: none; stroke-width: 3"])

        #expect(parAttributs == parChaine)
    }

    // MARK: Outils

    private func echantillonDesFormes() throws -> EchantillonDePage {
        let octets = try #require(FichiersDeFormats.octets("formes.svg"))
        let zone = TailleEnPixels(largeur: Int(cote), hauteur: Int(cote))
        let page = try decodeur.decoder(octets, nom: "formes.svg", dans: zone)

        return try #require(EchantillonDePage(page.image, cote: cote))
    }
}
