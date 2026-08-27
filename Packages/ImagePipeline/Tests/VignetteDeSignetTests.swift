import Core
import Foundation
import ImageIO
import Testing
@testable import ImagePipeline

//
// Couvre la vignette qu un signet conserve de la page marquee.
//
// Le critere de la fonctionnalite dit que le signet enregistre une vignette. Le
// piege du domaine dit comment : une page de 3000 par 4500 fait 54 Mo une fois
// decodee, et la produire en pleine resolution pour en tirer une image de 198
// pixels ferait tomber l application avant d avoir ecrit le fichier.
//

struct VignetteDeSignetTests {
    /// Dimensions du fichier ecrit, lues sans le decoder.
    private func dimensions(de url: URL) throws -> TailleEnPixels {
        let donnees = try Data(contentsOf: url)
        let source = try DecodeurDePage.source(de: donnees, nom: url.lastPathComponent)

        return try DecodeurDePage.dimensions(de: source, nom: url.lastPathComponent)
    }

    @Test("Poser un signet ecrit un fichier de vignette dans le dossier des vignettes")
    func vignetteEcrite() throws {
        let dossier = DossierDeTest.creer()
        defer { DossierDeTest.supprimer(dossier) }

        let fabrique = FabriqueDeVignettesDeSignet(dossier: dossier)
        let signet = UUID()

        let nom = try fabrique.produire(PageDeTest.standard, nom: "014.jpg", pour: signet)
        let url = try #require(fabrique.url(de: nom))

        #expect(nom == "\(signet.uuidString.lowercased()).jpg")
        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(try Data(contentsOf: url).isEmpty == false)
    }

    @Test("La vignette est bornee au cote d affichage, jamais decodee en pleine resolution")
    func vignetteSousEchantillonnee() throws {
        let dossier = DossierDeTest.creer()
        defer { DossierDeTest.supprimer(dossier) }

        let fabrique = FabriqueDeVignettesDeSignet(dossier: dossier)
        let nom = try fabrique.produire(PageDeTest.standard, nom: "014.jpg", pour: UUID())
        let url = try #require(fabrique.url(de: nom))
        let taille = try dimensions(de: url)

        #expect(taille.plusGrandCote <= FabriqueDeVignettesDeSignet.coteMaximalEnPixels)
        #expect(taille.estVide == false)

        // La page de reference fait 3000 par 4500, ratio deux tiers. La vignette
        // le conserve : une vignette etiree se verrait immediatement dans la
        // liste, ou toutes les pages ont le meme format.
        let ratio = Double(taille.largeur) / Double(taille.hauteur)
        #expect(abs(ratio - 3000.0 / 4500.0) < 0.02)
    }

    @Test("La vignette pese quelques kilooctets, pas les 54 Mo de la page")
    func vignetteLegere() throws {
        let dossier = DossierDeTest.creer()
        defer { DossierDeTest.supprimer(dossier) }

        let fabrique = FabriqueDeVignettesDeSignet(dossier: dossier)
        let nom = try fabrique.produire(PageDeTest.standard, nom: "014.jpg", pour: UUID())
        let url = try #require(fabrique.url(de: nom))

        #expect(DossierDeTest.octetsSurLeDisque(dossier) > 0)
        #expect(try Data(contentsOf: url).count < 200_000)
    }

    @Test("Une page illisible ne laisse aucun fichier derriere elle")
    func pageIllisible() {
        let dossier = DossierDeTest.creer()
        defer { DossierDeTest.supprimer(dossier) }

        let fabrique = FabriqueDeVignettesDeSignet(dossier: dossier)

        #expect(throws: ErreurDeDecodage.formatInconnu(nom: "abime.jpg")) {
            try fabrique.produire(Data([0xAA, 0xBB, 0xCC]), nom: "abime.jpg", pour: UUID())
        }

        #expect(DossierDeTest.octetsSurLeDisque(dossier) == 0)
    }

    @Test("Un nom relu dans une sauvegarde ne peut pas designer un fichier hors du dossier")
    func nomHorsDuDossierRefuse() {
        let dossier = DossierDeTest.creer()
        defer { DossierDeTest.supprimer(dossier) }

        let fabrique = FabriqueDeVignettesDeSignet(dossier: dossier)

        #expect(fabrique.url(de: "../trousseau.json") == nil)
        #expect(fabrique.url(de: "sous/dossier.jpg") == nil)
        #expect(fabrique.url(de: "") == nil)
        #expect(fabrique.url(de: "vignette.jpg") != nil)
    }

    @Test("Retirer un signet efface sa vignette, et une vignette absente ne fait rien echouer")
    func suppressionDeLaVignette() throws {
        let dossier = DossierDeTest.creer()
        defer { DossierDeTest.supprimer(dossier) }

        let fabrique = FabriqueDeVignettesDeSignet(dossier: dossier)
        let nom = try fabrique.produire(PageDeTest.standard, nom: "014.jpg", pour: UUID())
        let url = try #require(fabrique.url(de: nom))

        fabrique.supprimer(nom)
        #expect(FileManager.default.fileExists(atPath: url.path) == false)

        fabrique.supprimer(nom)
        fabrique.supprimer("jamais-produite.jpg")
    }

    @Test("Poser deux fois un signet sur la meme page reecrit le meme fichier")
    func memeSignetMemeFichier() throws {
        let dossier = DossierDeTest.creer()
        defer { DossierDeTest.supprimer(dossier) }

        let fabrique = FabriqueDeVignettesDeSignet(dossier: dossier)
        let signet = UUID()

        let premier = try fabrique.produire(PageDeTest.standard, nom: "014.jpg", pour: signet)
        let second = try fabrique.produire(PageDeTest.standard, nom: "014.jpg", pour: signet)

        #expect(premier == second)

        let contenu = try FileManager.default.contentsOfDirectory(atPath: dossier.path)
        #expect(contenu.count == 1)
    }
}
