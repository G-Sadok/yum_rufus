import Core
import Foundation
import Testing

/// Couvre la lecture du `ComicBookInfo` range dans le commentaire d une
/// archive, source de secours de la section 5.3.
struct AnalyseurDeComicBookInfoTests {
    private func analyser(_ nom: String) throws -> MetadonneesComic? {
        let octets = try #require(FichiersDeMetadonnees.octets(nom), "fichier \(nom) absent du paquet")

        return AnalyseurDeComicBookInfo.analyser(octets)
    }

    @Test("Un commentaire ComicBookInfo complet remplit les champs du modele")
    func commentaireComplet() throws {
        let lues = try #require(try analyser("comictagger-comicbookinfo.json"))

        #expect(lues.serie == "Chroniques de la Cite Basse")
        #expect(lues.titre == "Le Retour")
        #expect(lues.volume == 2)
        #expect(lues.langue == "fr")
        #expect(lues.resume == "La cite se reveille apres trois jours de silence.")
        #expect(lues.editeur == "Editions du Quai")
        #expect(lues.genres == ["science fiction", "drame"])
    }

    @Test("Un numero ecrit en nombre est rendu en texte sans decoration")
    func numeroEnNombre() throws {
        let lues = try #require(try analyser("comictagger-comicbookinfo.json"))

        #expect(lues.numero == "12")
        #expect(lues.numeroDecimal == 12)
    }

    @Test("Les intervenants sont repartis selon leur role")
    func intervenantsParRole() throws {
        let lues = try #require(try analyser("comictagger-comicbookinfo.json"))

        #expect(lues.auteurs == ["A. Mercier"])

        // L encreur est bien present dans le fichier. Le ranger avec les
        // dessinateurs gonflerait la fiche de serie avec des metiers que
        // l ecran ne distingue pas.
        #expect(lues.dessinateurs == ["A. Mercier"])
    }

    @Test("Le ComicBookInfo ne prononce jamais le sens de lecture")
    func aucunSensDeLecture() throws {
        let lues = try #require(try analyser("comictagger-comicbookinfo.json"))

        #expect(lues.sensDeLecture == nil)
    }

    @Test("Un commentaire coupe ne rend rien")
    func commentaireTronque() throws {
        #expect(try analyser("comicbookinfo-tronque.json") == nil)
    }

    @Test(
        "Un commentaire qui n est pas un ComicBookInfo ne rend rien",
        arguments: [
            "",
            "   ",
            "Archive creee le 12 mars",
            "{}",
            "{\"appID\":\"test\"}",
            "[1, 2, 3]",
            "{\"ComicBookInfo/1.0\": \"pas un objet\"}",
            "{\"ComicBookInfo/1.0\": {}}",
        ]
    )
    func commentaireSansMetadonnees(commentaire: String) {
        #expect(AnalyseurDeComicBookInfo.analyser(commentaire) == nil)
    }

    @Test("Une revision inconnue du format reste lisible")
    func revisionInconnue() {
        let commentaire = "{\"ComicBookInfo/2.0\": {\"series\": \"Apres Demain\", \"issue\": \"4\"}}"
        let lues = AnalyseurDeComicBookInfo.analyser(commentaire)

        #expect(lues?.serie == "Apres Demain")
        #expect(lues?.numero == "4")
    }

    @Test("Un champ du mauvais type ne coute que lui")
    func champDuMauvaisType() {
        // `volume` arrive ici en tableau et `credits` en chaine. Un decodage en
        // bloc rendrait nul et perdrait la serie, qui est parfaitement lisible.
        let commentaire = """
        {"ComicBookInfo/1.0": {"series": "Resilience", "volume": [1], \
        "credits": "A. Mercier", "comments": "Un resume valide."}}
        """
        let lues = AnalyseurDeComicBookInfo.analyser(commentaire)

        #expect(lues?.serie == "Resilience")
        #expect(lues?.resume == "Un resume valide.")
        #expect(lues?.volume == nil)
        #expect(lues?.auteurs.isEmpty == true)
    }
}
