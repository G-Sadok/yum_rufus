import Core
import Foundation
import Testing
@testable import ImagePipeline

//
// Couvre la promesse de la section 5.2 : chacun des douze formats s ouvre, et
// s ouvre dans le bon sens.
//
// L assertion ne porte pas seulement sur les dimensions. Une image retournee,
// transposee ou videe garde ses dimensions, et c est exactement ce que
// produisent les erreurs de decodage silencieuses. Les quatre coins de la rampe
// diagonale du jeu de fichiers les distinguent tous.
//

struct FormatsEtendusTests {
    private let decodeur = DecodeurDePage()

    /// Ecart tolere sur un ton, sur 255.
    ///
    /// Large, parce que le lot melange des formats sans perte, des formats avec
    /// perte et une palette de 256 couleurs, et que la conversion en gris passe
    /// par un profil colorimetrique. Assez serre pour qu un coin noir ne puisse
    /// pas passer pour un coin blanc, ce que le test cherche.
    private let tolerance = 40.0

    // MARK: Chaque format s affiche

    @Test("Chaque format de la section 5.2 se decode a la bonne taille", arguments: FichiersDeFormats.pages)
    func chaqueFormatSeDecode(fichier: (nom: String, format: FormatDImage)) throws {
        let octets = try #require(FichiersDeFormats.octets(fichier.nom))
        let page = try decodeur.decoder(octets, nom: fichier.nom, dans: FichiersDeFormats.taille)

        #expect(page.tailleDOrigine == FichiersDeFormats.taille)
        #expect(page.tailleDecodee == FichiersDeFormats.taille)
    }

    @Test("Chaque format rend la rampe dans le bon sens", arguments: FichiersDeFormats.pages)
    func chaqueFormatRendLaRampe(fichier: (nom: String, format: FormatDImage)) throws {
        let octets = try #require(FichiersDeFormats.octets(fichier.nom))
        let page = try decodeur.decoder(octets, nom: fichier.nom, dans: FichiersDeFormats.taille)
        let coins = try #require(CoinsDeRampe(page.image))

        #expect(abs(coins.hautGauche - 13) < tolerance, "haut gauche de \(fichier.nom)")
        #expect(abs(coins.hautDroit - 128) < tolerance, "haut droit de \(fichier.nom)")
        #expect(abs(coins.basGauche - 128) < tolerance, "bas gauche de \(fichier.nom)")
        #expect(abs(coins.basDroit - 242) < tolerance, "bas droit de \(fichier.nom)")
        #expect(coins.hautGauche < coins.hautDroit)
        #expect(coins.hautDroit < coins.basDroit)
    }

    @Test("Les dimensions se lisent sans decoder, dans chaque format", arguments: FichiersDeFormats.pages)
    func dimensionsSansDecodage(fichier: (nom: String, format: FormatDImage)) throws {
        let octets = try #require(FichiersDeFormats.octets(fichier.nom))

        #expect(try decodeur.dimensions(octets, nom: fichier.nom) == FichiersDeFormats.taille)
    }

    @Test("Le format annonce par le fichier est celui que le catalogue reconnait", arguments: FichiersDeFormats.pages)
    func formatReconnu(fichier: (nom: String, format: FormatDImage)) throws {
        let octets = try #require(FichiersDeFormats.octets(fichier.nom))

        #expect(FormatDImage.depuis(octets: octets) == fichier.format)
    }

    // MARK: Le jeu de fichiers couvre tout

    @Test("Le jeu de fichiers couvre les douze formats du catalogue")
    func jeuComplet() {
        let couverts = Set(FichiersDeFormats.pages.map(\.format))

        #expect(couverts == Set(FormatDImage.allCases))
    }

    @Test("Chaque fichier du jeu est present et non vide")
    func fichiersPresents() throws {
        for fichier in FichiersDeFormats.pages {
            let octets = try #require(FichiersDeFormats.octets(fichier.nom), "fichier absent : \(fichier.nom)")
            #expect(octets.isEmpty == false)
        }
    }

    // MARK: Prise en charge par l appareil

    @Test("Tous les formats du catalogue sont lisibles sur cet appareil")
    func toutEstLisibleIci() {
        #expect(SupportDesFormats.absents.isEmpty, "formats absents : \(SupportDesFormats.absents)")
    }

    @Test("SVG est declare lisible bien qu Image I/O l ignore")
    func svgTenuParLePaquet() {
        #expect(SupportDesFormats.estLisible(.svg))
    }

    // MARK: Animation

    @Test("Un APNG rend sa premiere image, pas la seconde")
    func apngRendLaPremiereImage() throws {
        // Le jeu de fichiers porte une seconde image inversee. La confondre avec
        // la premiere rendrait une rampe a l envers, que les coins reperent.
        let octets = try #require(FichiersDeFormats.octets("page.apng"))
        let page = try decodeur.decoder(octets, nom: "page.apng", dans: FichiersDeFormats.taille)
        let coins = try #require(CoinsDeRampe(page.image))

        #expect(coins.hautGauche < coins.basDroit)
    }

    @Test("Un GIF et un APNG sont annonces animes, les autres non")
    func formatsAnimes() {
        #expect(FormatDImage.gif.estAnime)
        #expect(FormatDImage.apng.estAnime)
        #expect(FormatDImage.png.estAnime == false)
        #expect(FormatDImage.webp.estAnime == false)
    }
}
