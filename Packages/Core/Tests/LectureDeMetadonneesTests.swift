import Core
import Foundation
import Testing

/// Couvre l ordre de priorite de la section 5.3, `ComicInfo.xml` d abord et
/// `ComicBookInfo` en secours, et la regle qui domine cette fonctionnalite :
/// un fichier de metadonnees casse n interrompt jamais l ouverture du chapitre.
struct LectureDeMetadonneesTests {
    private static let comicInfoComplet = """
    <ComicInfo><Series>Depuis le XML</Series><Number>9</Number>\
    <LanguageISO>fr</LanguageISO><Summary>Resume du XML.</Summary>\
    <Volume>2</Volume></ComicInfo>
    """

    private static let comicBookInfoComplet = """
    {"ComicBookInfo/1.0": {"series": "Depuis le commentaire", "issue": 3, \
    "volume": 7, "language": "en", "comments": "Resume du commentaire.", \
    "publisher": "Maison du Sud"}}
    """

    // MARK: Priorite

    @Test("Le ComicInfo.xml prime sur le commentaire de l archive")
    func comicInfoPrioritaire() throws {
        let document = DocumentDeTest(
            octetsDeMetadonnees: Data(Self.comicInfoComplet.utf8),
            commentaireDeConteneur: Self.comicBookInfoComplet
        )
        let lues = try #require(document.metadonnees)

        #expect(lues.serie == "Depuis le XML")
        #expect(lues.numero == "9")
        #expect(lues.volume == 2)
        #expect(lues.langue == "fr")
        #expect(lues.resume == "Resume du XML.")
    }

    @Test("Le commentaire comble les champs que le ComicInfo laisse vides")
    func commentaireComplete() throws {
        let document = DocumentDeTest(
            octetsDeMetadonnees: Data("<ComicInfo><Series>Depuis le XML</Series></ComicInfo>".utf8),
            commentaireDeConteneur: Self.comicBookInfoComplet
        )
        let lues = try #require(document.metadonnees)

        #expect(lues.serie == "Depuis le XML")
        #expect(lues.resume == "Resume du commentaire.")
        #expect(lues.editeur == "Maison du Sud")
        #expect(lues.volume == 7)
    }

    @Test("Sans ComicInfo, le commentaire de l archive fait foi")
    func secoursSeul() throws {
        let document = DocumentDeTest(commentaireDeConteneur: Self.comicBookInfoComplet)
        let lues = try #require(document.metadonnees)

        #expect(lues.serie == "Depuis le commentaire")
        #expect(lues.numero == "3")
    }

    @Test("Sans aucune des deux sources, il n y a pas de metadonnees")
    func aucuneSource() {
        #expect(DocumentDeTest().metadonnees == nil)
    }

    @Test("Un ComicInfo vide de sens ne masque pas le commentaire")
    func comicInfoInexploitable() {
        let document = DocumentDeTest(
            octetsDeMetadonnees: Data("<ComicInfo></ComicInfo>".utf8),
            commentaireDeConteneur: Self.comicBookInfoComplet
        )

        #expect(document.metadonnees?.serie == "Depuis le commentaire")
    }

    // MARK: Un fichier casse n interrompt jamais l ouverture

    @Test(
        "Aucun fichier du jeu ne fait echouer la lecture ni l acces aux pages",
        arguments: FichiersDeMetadonnees.tous
    )
    func aucunFichierNInterrompt(nom: String) throws {
        let octets = try #require(FichiersDeMetadonnees.octets(nom), "fichier \(nom) absent du paquet")
        let document = DocumentDeTest(octetsDeMetadonnees: octets)

        // La lecture des metadonnees ne leve pas : elle rend un optionnel.
        _ = document.metadonnees

        // Et le document reste servi apres coup, ce qui est le vrai critere.
        #expect(document.nombrePages == 3)
        #expect(try document.donneesPage(a: 0) == Data("page1.jpg".utf8))
        #expect(try document.toutesLesPages().count == 3)
    }

    @Test("Une lecture de metadonnees qui echoue laisse le chapitre lisible")
    func erreurDeLectureAbsorbee() throws {
        let document = DocumentDeTest(
            commentaireDeConteneur: Self.comicBookInfoComplet,
            erreurDeMetadonnees: .entreeCorrompue(nom: "ComicInfo.xml")
        )

        // L entree existe et sa lecture leve. Le secours prend le relais plutot
        // que de faire remonter l erreur jusqu a l ouverture du chapitre.
        #expect(document.metadonnees?.serie == "Depuis le commentaire")
        #expect(try document.donneesPage(a: 1) == Data("page2.jpg".utf8))
    }

    @Test("Une erreur de lecture sans secours ne rend rien et ne leve pas")
    func erreurDeLectureSansSecours() throws {
        let document = DocumentDeTest(erreurDeMetadonnees: .entreeCorrompue(nom: "ComicInfo.xml"))

        #expect(document.metadonnees == nil)
        #expect(try document.toutesLesPages().count == 3)
    }

    // MARK: Composition

    @Test("La composition de deux absences ne rend rien")
    func compositionVide() {
        #expect(LectureDeMetadonnees.composer(prioritaires: nil, secours: nil) == nil)
    }
}
