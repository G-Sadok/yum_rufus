import Core
import Foundation
import Testing
@testable import ImagePipeline

//
// Couvre le second critere de la fonctionnalite : un format que Yum ne sait pas
// ouvrir donne une page de remplacement qui nomme sa cause, jamais un vide.
//
// Le point important n est pas qu une erreur soit levee, c est qu elle ne le
// soit pas. Un chapitre qui contient une page abimee doit rester lisible de
// bout en bout, et c est ce que verifie le dernier test de ce fichier.
//

struct PageDeRemplacementTests {
    private let decodeur = DecodeurDePage()
    private let zone = TailleEnPixels(largeur: 800, hauteur: 1200)

    // MARK: Fichiers reellement illisibles

    @Test("Un fichier tronque donne un remplacement qui nomme son format")
    func fichierTronque() throws {
        let octets = try #require(FichiersDeFormats.octets("page-tronquee.webp"))
        let resultat = decodeur.decoderOuRemplacer(octets, nom: "page-tronquee.webp", numeroDePage: 14, dans: zone)
        let remplacement = try #require(resultat.remplacementEventuel)

        #expect(remplacement.numeroDePage == 14)
        #expect(remplacement.nomDeLEntree == "page-tronquee.webp")
        #expect(remplacement.cause == .contenuIllisible(.webp))
        #expect(remplacement.format == .webp)
    }

    @Test("Un fichier qui n est d aucun format donne un remplacement, malgre son extension")
    func extensionTrompeuse() throws {
        let octets = try #require(FichiersDeFormats.octets("page-trompeuse.jpg"))
        let resultat = decodeur.decoderOuRemplacer(octets, nom: "page-trompeuse.jpg", numeroDePage: 3, dans: zone)
        let remplacement = try #require(resultat.remplacementEventuel)

        // L extension promet un JPEG, les octets ne promettent rien. Le message
        // ne doit pas nommer un format que le fichier ne porte pas.
        #expect(remplacement.cause == .formatInconnu)
        #expect(remplacement.format == nil)
    }

    @Test("Un SVG sans cadre donne un remplacement plutot qu une page vide")
    func svgSansCadre() throws {
        let octets = try #require(FichiersDeFormats.octets("page-sans-cadre.svg"))
        let resultat = decodeur.decoderOuRemplacer(octets, nom: "page-sans-cadre.svg", numeroDePage: 1, dans: zone)
        let remplacement = try #require(resultat.remplacementEventuel)

        #expect(remplacement.cause == .contenuIllisible(.svg))
    }

    @Test("Un fichier vide donne un remplacement, jamais une image de zero pixel")
    func fichierVide() throws {
        let resultat = decodeur.decoderOuRemplacer(Data(), nom: "vide.png", numeroDePage: 7, dans: zone)
        let remplacement = try #require(resultat.remplacementEventuel)

        #expect(remplacement.cause == .formatInconnu)
        #expect(resultat.image == nil)
    }

    // MARK: Format connu que l appareil ne sait pas lire

    @Test("Un format connu mais absent de l appareil est refuse avant tout decodage")
    func formatAbsentDeLAppareil() {
        // La prise en charge de JPEG XL depend de la version du systeme. Le jeu
        // de formats lisibles est donc injecte, seule facon de couvrir le cas
        // sur une machine qui, elle, sait lire le format.
        let lisibles = Set(FormatDImage.allCases).subtracting([.jpegXL])
        let cause = CauseDeRemplacement.refusAvantDecodage(format: .jpegXL, lisibles: lisibles)

        #expect(cause == .formatNonPrisEnCharge(.jpegXL))
    }

    @Test("Un format que l appareil sait lire n est jamais refuse d avance")
    func formatPrisEnCharge() {
        let cause = CauseDeRemplacement.refusAvantDecodage(
            format: .png,
            lisibles: Set(FormatDImage.allCases)
        )

        #expect(cause == nil)
    }

    @Test("Des octets sans format connu ne sont pas refuses d avance")
    func formatInconnuNonRefuse() {
        // Le decodeur garde sa chance : Image I/O reconnait des formats que le
        // catalogue ne liste pas, et une page lisible ne doit pas etre remplacee
        // parce que le catalogue est en retard.
        #expect(CauseDeRemplacement.refusAvantDecodage(format: nil, lisibles: []) == nil)
    }

    // MARK: Une page abimee n arrete pas le chapitre

    @Test("Une page abimee au milieu d un chapitre n empeche pas les autres de s ouvrir")
    func chapitreQuiContinue() throws {
        let abimee = try #require(FichiersDeFormats.octets("page-tronquee.webp"))
        let saine = try #require(FichiersDeFormats.octets("page.png"))
        let chapitre = [saine, abimee, saine]

        let resultats = chapitre.enumerated().map { rang, octets in
            decodeur.decoderOuRemplacer(
                octets,
                nom: "page\(rang).bin",
                numeroDePage: rang + 1,
                dans: zone
            )
        }

        #expect(resultats.compactMap(\.image).count == 2)
        #expect(resultats.compactMap(\.remplacementEventuel).count == 1)
        #expect(resultats[1].remplacementEventuel?.numeroDePage == 2)
    }

    @Test("Une page lisible n est jamais remplacee")
    func pageLisible() throws {
        let octets = try #require(FichiersDeFormats.octets("page.avif"))
        let resultat = decodeur.decoderOuRemplacer(octets, nom: "page.avif", numeroDePage: 1, dans: zone)

        #expect(resultat.remplacementEventuel == nil)
        #expect(resultat.image != nil)
    }
}
