import Core
import Foundation
import Testing
@testable import ImagePipeline

/// Couvre la promesse centrale de la chaine d images : une page n est jamais
/// decodee en pleine resolution pour etre affichee, quelle que soit la taille
/// de la zone qui la recoit.
struct DecodageSousEchantillonneTests {
    private let decodeur = DecodeurDePage()
    private let pageDeReference = TailleEnPixels(largeur: 3000, hauteur: 4500)

    // MARK: Budget memoire

    @Test("Une page de 3000 par 4500 tient sous 12 Mo dans une zone demesuree")
    func pageDeReferenceSousDouzeMegaoctets() throws {
        let donnees = PageDeTest.standard
        #expect(donnees.isEmpty == false)

        // Zone plus grande que la page. Sans budget, le decodeur rendrait ici
        // la page entiere, soit 54 Mo.
        let zone = TailleEnPixels(largeur: 6000, hauteur: 9000)
        let page = try decodeur.decoder(donnees, nom: "reference.jpg", dans: zone)

        #expect(page.tailleDOrigine == pageDeReference)
        #expect(page.octetsEnMemoire < 12_000_000)
        #expect(page.estSousEchantillonnee)
        #expect(page.niveau == .affichage)
        #expect(page.octetsEnMemoire <= BudgetDeDecodage.octetsOccupes(par: page.tailleDecodee))
    }

    @Test("Le budget borne aussi une zone d ecran dense credible")
    func zoneDenseBorneeParLeBudget() throws {
        // 1600 par 2400 pixels reels correspond a une fenetre de 800 par 1200
        // points sur un ecran a deux fois la densite. L ajustement seul y
        // demanderait 15,4 Mo.
        let zone = TailleEnPixels(largeur: 1600, hauteur: 2400)
        let page = try decodeur.decoder(PageDeTest.standard, nom: "dense.jpg", dans: zone)

        #expect(page.octetsEnMemoire < 12_000_000)
        #expect(page.tailleDecodee.hauteur < zone.hauteur)
    }

    @Test("Un budget resserre resserre reellement le decodage")
    func budgetResserre() throws {
        let zone = TailleEnPixels(largeur: 4000, hauteur: 6000)
        let budget = BudgetDeDecodage(octetsParPage: 2_000_000)
        let page = try decodeur.decoder(PageDeTest.standard, nom: "vignette.jpg", dans: zone, budget: budget)

        #expect(page.octetsEnMemoire < 2_000_000)
    }

    // MARK: Ajustement a la zone

    @Test("Une petite zone gouverne le decodage avant le budget")
    func petiteZoneGouverne() throws {
        let zone = TailleEnPixels(largeur: 800, hauteur: 1200)
        let page = try decodeur.decoder(PageDeTest.standard, nom: "petite.jpg", dans: zone)

        #expect(page.tailleDecodee.largeur <= zone.largeur)
        #expect(page.tailleDecodee.hauteur <= zone.hauteur)
        #expect(page.tailleDecodee.plusGrandCote == zone.hauteur)
    }

    @Test("Le sous echantillonnage conserve le ratio de la page")
    func ratioConserve() throws {
        let zone = TailleEnPixels(largeur: 1000, hauteur: 1500)
        let page = try decodeur.decoder(PageDeTest.standard, nom: "ratio.jpg", dans: zone)

        let ratioDOrigine = Double(pageDeReference.largeur) / Double(pageDeReference.hauteur)
        let ratioDecode = Double(page.tailleDecodee.largeur) / Double(page.tailleDecodee.hauteur)

        #expect(abs(ratioDecode - ratioDOrigine) < 0.01)
    }

    @Test("Les dimensions se lisent sans rien decoder")
    func dimensionsSansDecodage() throws {
        let taille = try decodeur.dimensions(PageDeTest.standard, nom: "entete.jpg")

        #expect(taille == pageDeReference)
    }

    // MARK: Erreurs

    @Test("Des octets qui ne sont pas une image remontent une erreur nommee")
    func formatInconnu() {
        let donnees = Data("ceci n est pas une image".utf8)

        #expect(throws: ErreurDeDecodage.formatInconnu(nom: "faux.jpg")) {
            try decodeur.decoder(donnees, nom: "faux.jpg", dans: TailleEnPixels(largeur: 800, hauteur: 1200))
        }
    }

    @Test("Un fichier vide remonte une erreur plutot qu une image vide")
    func fichierVide() {
        #expect(throws: ErreurDeDecodage.formatInconnu(nom: "vide.jpg")) {
            try decodeur.decoder(Data(), nom: "vide.jpg", dans: TailleEnPixels(largeur: 800, hauteur: 1200))
        }
    }

    @Test("Une zone pas encore mesuree ne fait pas decoder la page entiere")
    func zoneNulle() throws {
        let page = try decodeur.decoder(PageDeTest.standard, nom: "zone-nulle.jpg", dans: .nulle)

        #expect(page.octetsEnMemoire < 12_000_000)
    }
}
