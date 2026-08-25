import Archive
import Core
import Foundation
import Testing

/// Verifie la section 5.3 sur un conteneur reel plutot que sur un faux : le
/// `ComicInfo.xml` est vraiment range dans un ZIP, le `ComicBookInfo` est
/// vraiment ecrit dans le commentaire de l enregistrement de fin.
struct MetadonneesDArchiveTests {
    private static let comicBookInfo = """
    {"ComicBookInfo/1.0": {"series": "Depuis le commentaire", "issue": 3, \
    "language": "en", "comments": "Resume du commentaire."}}
    """

    private func archive(
        comicInfo: Data?,
        commentaire: String = ""
    ) throws -> DocumentZip {
        var entrees = [
            EntreeDeTest("page1.jpg", contenu: PagesDeTest.contenu(1, taille: 32)),
            EntreeDeTest("page2.jpg", contenu: PagesDeTest.contenu(2, taille: 32)),
        ]
        if let comicInfo {
            entrees.append(EntreeDeTest("ComicInfo.xml", contenu: comicInfo))
        }

        let octets = ConstructeurDeZip.archive(entrees, commentaire: commentaire).octets

        return try DocumentZip(source: OctetsEnMemoire(octets, nom: "tome.cbz"))
    }

    @Test("Un CBZ rend les metadonnees de son ComicInfo.xml")
    func metadonneesDuFichier() throws {
        let comicInfo = Data(
            """
            <ComicInfo><Series>Yoru no Hikari</Series><Number>4</Number>\
            <Volume>2</Volume><LanguageISO>ja</LanguageISO>\
            <Summary>Le chapitre suivant.</Summary>\
            <Manga>YesAndRightToLeft</Manga></ComicInfo>
            """.utf8
        )
        let lues = try #require(try archive(comicInfo: comicInfo).metadonnees)

        #expect(lues.serie == "Yoru no Hikari")
        #expect(lues.numero == "4")
        #expect(lues.volume == 2)
        #expect(lues.langue == "ja")
        #expect(lues.resume == "Le chapitre suivant.")
        #expect(lues.sensDeLecture == .droiteGauche)
    }

    @Test("Sans ComicInfo.xml, le commentaire du ZIP prend le relais")
    func metadonneesDuCommentaire() throws {
        let document = try archive(comicInfo: nil, commentaire: Self.comicBookInfo)
        let lues = try #require(document.metadonnees)

        #expect(lues.serie == "Depuis le commentaire")
        #expect(lues.numero == "3")
        #expect(lues.resume == "Resume du commentaire.")
    }

    @Test("Un ComicInfo.xml casse ne bloque pas l ouverture et laisse le secours agir")
    func comicInfoCasseNInterromptPas() throws {
        // La copie s arrete au milieu de `Number`. `Series` est ferme avant la
        // cassure, `Number` ne l est pas.
        let casse = Data("<ComicInfo><Series>Serie Fermee</Series><Number>4".utf8)
        let document = try archive(comicInfo: casse, commentaire: Self.comicBookInfo)

        // Les pages restent servies, c est le vrai critere de la section 5.3.
        #expect(document.nombrePages == 2)
        #expect(try document.donneesPage(a: 0) == PagesDeTest.contenu(1, taille: 32))

        // Le fragment ferme du XML prime, le commentaire comble le reste.
        let lues = try #require(document.metadonnees)
        #expect(lues.serie == "Serie Fermee")
        #expect(lues.resume == "Resume du commentaire.")

        // Un element ouvert et jamais ferme ne rend pas sa valeur partielle :
        // le numero vient donc du commentaire, pas du fragment.
        #expect(lues.numero == "3")
    }

    @Test("Un ComicInfo.xml qui n est pas du XML ne bloque pas l ouverture")
    func comicInfoIllisible() throws {
        let binaire = Data([0x00, 0x01, 0x02, 0x03, 0xFF, 0xFE])
        let document = try archive(comicInfo: binaire)

        #expect(document.metadonnees == nil)
        #expect(document.nombrePages == 2)
        #expect(try document.toutesLesPages().count == 2)
    }

    @Test("Une archive sans metadonnees ni commentaire n en invente pas")
    func aucuneMetadonnee() throws {
        #expect(try archive(comicInfo: nil).metadonnees == nil)
    }

    @Test("Un ComicInfo.xml dont les octets sont corrompus laisse le chapitre lisible")
    func comicInfoCorrompu() throws {
        var entree = EntreeDeTest(
            "ComicInfo.xml",
            contenu: Data("<ComicInfo><Series>Jamais lue</Series></ComicInfo>".utf8)
        )
        // La somme de controle annoncee est fausse : la lecture de cette entree
        // leve, alors que l index de l archive la donne pour presente.
        entree.crcForce = 0xDEAD_BEEF

        let octets = ConstructeurDeZip.archive(
            [EntreeDeTest("page1.jpg", contenu: PagesDeTest.contenu(1, taille: 32)), entree],
            commentaire: Self.comicBookInfo
        ).octets
        let document = try DocumentZip(source: OctetsEnMemoire(octets, nom: "tome.cbz"))

        #expect(document.metadonnees?.serie == "Depuis le commentaire")
        #expect(try document.donneesPage(a: 0) == PagesDeTest.contenu(1, taille: 32))
    }
}
