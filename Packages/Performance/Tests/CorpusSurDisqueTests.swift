import Archive
import Core
import Foundation
import ImagePipeline
import Testing
@testable import BudgetsDePerformance

//
// CorpusSurDisqueTests
//
// Les chapitres du corpus doivent etre de vraies archives, pas des octets qui en
// ont l air.
//
// Les budgets d ouverture, de tourne de page et de memoire en lecture mesurent
// la lecture d un index central de ZIP et le decodage sous echantillonne d une
// image. Sur une archive que le lecteur du projet refuserait, ou sur une entree
// que le decodeur ne saurait pas lire, ces trois budgets ne mesureraient rien et
// passeraient au vert.
//

struct CorpusSurDisqueTests {
    private let pages = 3
    private let largeur = 240
    private let hauteur = 360

    @Test("Le CBZ produit est une archive que le lecteur du projet sait ouvrir")
    func archiveLisible() throws {
        let dossier = try dossierTemporaire()
        defer { try? FileManager.default.removeItem(at: dossier) }

        let chemin = dossier.appendingPathComponent("chapitre.cbz")
        try ecrire(vers: chemin, graine: 1)

        let document = try DocumentZip(contenuDe: chemin)

        #expect(document.nombrePages == pages)
        #expect(try document.referencePage(0).nom == "page000.jpg")
        #expect(try document.referencePage(pages - 1).nom == "page002.jpg")
    }

    @Test("Chaque page du CBZ se decode a la taille d affichage")
    func pagesDecodables() throws {
        let dossier = try dossierTemporaire()
        defer { try? FileManager.default.removeItem(at: dossier) }

        let chemin = dossier.appendingPathComponent("chapitre.cbz")
        try ecrire(vers: chemin, graine: 1)

        let document = try DocumentZip(contenuDe: chemin)
        let decodeur = DecodeurDePage()

        for index in 0..<document.nombrePages {
            let reference = try document.referencePage(index)
            let octets = try document.donneesPage(reference)
            let page = try decodeur.decoder(
                octets,
                nom: reference.nom,
                dans: CampagneDeBudgets.zoneDAffichage
            )

            #expect(page.tailleDOrigine == TailleEnPixels(largeur: largeur, hauteur: hauteur))
            #expect(page.tailleDecodee.plusGrandCote > 0)
        }
    }

    @Test("Une page pese ce que pese une planche scannee, ni plus ni moins")
    func densiteRealiste() throws {
        let dossier = try dossierTemporaire()
        defer { try? FileManager.default.removeItem(at: dossier) }

        // La densite se mesure sur une page a la taille d un vrai scan. Sur une
        // vignette, l en tete JPEG pese autant que l image et la mesure ne dit
        // plus rien.
        let largeurDUnScan = 1200
        let hauteurDUnScan = 1800
        let chemin = dossier.appendingPathComponent("scan.cbz")

        try EcrivainDeCbz.ecrire(
            vers: chemin,
            pages: 2,
            largeur: largeurDUnScan,
            hauteur: hauteurDUnScan,
            graine: 3
        )

        let document = try DocumentZip(contenuDe: chemin)
        let premiere = try document.donneesPage(document.referencePage(0))
        let seconde = try document.donneesPage(document.referencePage(1))
        let densite = Double(premiere.count) / Double(largeurDUnScan * hauteurDUnScan)

        // Les deux bornes gardent contre les deux derives opposees, chacune
        // capable de rendre les budgets d ouverture et de tourne de page faux.
        //
        // Trop bas, la page est un aplat : le decodeur n a presque rien a faire
        // et les budgets passent au vert quoi qu il arrive au code.
        //
        // Trop haut, la page est du bruit : aucun scan ne pese cela, et un
        // budget mesure la dessus est depasse par le jeu de test et non par le
        // lecteur. C est arrive, a 0,89 octet par pixel.
        #expect(densite > 0.02, "page trop plate : \(densite) octet par pixel")
        #expect(densite < 0.35, "page trop lourde pour un scan : \(densite) octet par pixel")
        #expect(premiere != seconde)
    }

    @Test("Deux ecritures depuis la meme graine rendent le meme fichier")
    func ecritureDeterministe() throws {
        let dossier = try dossierTemporaire()
        defer { try? FileManager.default.removeItem(at: dossier) }

        let premier = dossier.appendingPathComponent("premier.cbz")
        let second = dossier.appendingPathComponent("second.cbz")

        try ecrire(vers: premier, graine: 7)
        try ecrire(vers: second, graine: 7)

        #expect(try Data(contentsOf: premier) == Data(contentsOf: second))
    }

    @Test("La somme de controle independante est celle du format ZIP")
    func sommeDeControleConnue() {
        // Vecteurs de reference du CRC 32 du polynome 0xEDB88320, publies avec
        // le format. Ils valident la table sans la comparer a celle du projet.
        #expect(SommeCrc32Independante.calculer(Data()) == 0)
        #expect(SommeCrc32Independante.calculer(Data("123456789".utf8)) == 0xCBF4_3926)
        #expect(SommeCrc32Independante.calculer(Data("a".utf8)) == 0xE8B7_BE43)
    }

    private func ecrire(vers destination: URL, graine: UInt64) throws {
        try EcrivainDeCbz.ecrire(
            vers: destination,
            pages: pages,
            largeur: largeur,
            hauteur: hauteur,
            graine: graine
        )
    }

    private func dossierTemporaire() throws -> URL {
        let dossier = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("budgets-\(UUID().uuidString)", isDirectory: true)

        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)

        return dossier
    }
}
