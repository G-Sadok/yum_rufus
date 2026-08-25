import Core
import Foundation
import Testing

/// Couvre la lecture de `ComicInfo.xml`, source prioritaire de la section 5.3
/// du cahier de developpement.
///
/// Les fichiers viennent tous de `Tests/Fichiers`, voir `FichiersDeMetadonnees`
/// pour ce que chacun apporte.
struct AnalyseurDeComicInfoTests {
    /// Analyse un fichier du jeu, en echouant si le fichier manque du paquet.
    private func analyser(_ nom: String) throws -> MetadonneesComic? {
        let octets = try #require(FichiersDeMetadonnees.octets(nom), "fichier \(nom) absent du paquet")

        return AnalyseurDeComicInfo.analyser(octets)
    }

    // MARK: Fichiers bien formes

    @Test("Un ComicInfo occidental complet remplit tous les champs du modele")
    func occidentalComplet() throws {
        let lues = try #require(try analyser("comicrack-occidental.xml"))

        #expect(lues.serie == "Chroniques de la Cite Basse")
        #expect(lues.titre == "Le Retour")
        #expect(lues.numero == "12")
        #expect(lues.volume == 2)
        #expect(lues.langue == "fr")
        #expect(lues.resume?.hasPrefix("La cite se reveille apres trois jours de silence.") == true)
        #expect(lues.auteurs == ["A. Mercier"])
        #expect(lues.dessinateurs == ["A. Mercier"])
        #expect(lues.genres == ["Science Fiction", "Drame"])
        #expect(lues.editeur == "Editions du Quai")
        #expect(lues.nombrePagesAnnonce == 32)
        #expect(lues.sensDeLecture == .gaucheDroite)
    }

    @Test("Le bloc Pages ne se melange pas aux champs de la racine")
    func blocPagesIgnore() throws {
        let lues = try #require(try analyser("comicrack-occidental.xml"))

        // Les elements `Page` sont lus apres tous les champs du document. S ils
        // etaient traites comme des champs de la racine, ils laisseraient
        // derriere eux un element en cours jamais referme, et le document se
        // terminerait sur un etat different de celui qui a servi a lire les
        // champs precedents.
        #expect(lues.titre == "Le Retour")
        #expect(lues.numero == "12")
        #expect(lues.nombrePagesAnnonce == 32)
    }

    @Test("Un balisage en ligne dans un resume ne coupe pas la valeur")
    func balisageEnLigneDansLeResume() {
        // Cas courant : un outil de catalogage laisse passer du balisage dans
        // le resume. Traiter ces elements imbriques comme des champs perdrait
        // tout le texte qui precede le premier d entre eux.
        let octets = Data(
            "<ComicInfo><Summary>Avant <b>pendant</b> apres</Summary></ComicInfo>".utf8
        )

        #expect(AnalyseurDeComicInfo.analyser(octets)?.resume == "Avant pendant apres")
    }

    @Test("Un element imbrique ne devient pas un champ de la racine")
    func champImbriqueIgnore() {
        let octets = Data(
            """
            <ComicInfo><Series>Racine</Series>\
            <Pages><Page><Number>999</Number></Page></Pages></ComicInfo>
            """.utf8
        )
        let lues = AnalyseurDeComicInfo.analyser(octets)

        #expect(lues?.serie == "Racine")
        #expect(lues?.numero == nil)
    }

    @Test("Un ComicInfo de manga declare son sens de lecture et son resume litteral")
    func mangaAvecSectionLitterale() throws {
        let lues = try #require(try analyser("kavita-manga.xml"))

        #expect(lues.serie == "Yoru no Hikari")
        #expect(lues.numero == "3.5")
        #expect(lues.numeroDecimal == 3.5)
        #expect(lues.volume == 4)
        #expect(lues.langue == "ja")
        #expect(lues.resume?.hasPrefix("Un interlude sans dialogue") == true)
        #expect(lues.sensDeLecture == .droiteGauche)
    }

    // MARK: Encodages

    @Test("Un ComicInfo en ISO-8859-1 rend ses accents intacts")
    func encodageIsoLatin() throws {
        let lues = try #require(try analyser("latin1.xml"))

        #expect(lues.serie == "Les Éclaireurs de Brière")
        #expect(lues.editeur == "Ateliers du Héron")
        #expect(lues.resume?.hasPrefix("Élodie découvre un sentier") == true)
        #expect(lues.resume?.hasSuffix("le plus proche disparaît.") == true)
        #expect(lues.volume == 1)
        #expect(lues.langue == "fr")
    }

    @Test("Une marque d ordre en tete ne perturbe pas la lecture")
    func encodageAvecMarqueDOrdre() throws {
        let lues = try #require(try analyser("utf8-bom.xml"))

        #expect(lues.serie == "Hoshi no Kioku")
        #expect(lues.titre == "Le train de 5 h 40")
        #expect(lues.volume == 3)
        #expect(lues.langue == "ja")
        #expect(lues.resume?.contains("星 の 記憶") == true)
        #expect(lues.sensDeLecture == .droiteGauche)
        #expect(lues.genres == ["Mystere", "Tranche de vie"])
    }

    // MARK: Fichiers pauvres ou casses

    @Test("Un ComicInfo reduit rend ce qu il porte et rien de plus")
    func fichierMinimal() throws {
        let lues = try #require(try analyser("minimal.xml"))

        #expect(lues.serie == "Sans Fioritures")
        #expect(lues.numero == "1")
        #expect(lues.volume == nil)
        #expect(lues.langue == nil)
        #expect(lues.resume == nil)
        #expect(lues.sensDeLecture == nil)
    }

    @Test("Un ComicInfo coupe rend les champs fermes avant la cassure")
    func fichierTronque() throws {
        let lues = try #require(try analyser("tronque.xml"))

        #expect(lues.serie == "Archive Interrompue")
        #expect(lues.numero == "5")
        #expect(lues.volume == 2)
        #expect(lues.langue == "fr")

        // Le resume est coupe au milieu de sa valeur, son element ne se ferme
        // jamais. Rendre le fragment donnerait une phrase tronquee sur la fiche
        // de serie, sans que rien ne signale qu elle est incomplete.
        #expect(lues.resume == nil)
    }

    @Test("Un fichier qui n est pas un ComicInfo ne rend rien")
    func fichierEtranger() throws {
        #expect(try analyser("page-html.xml") == nil)
    }

    @Test("Un fichier vide ne rend rien")
    func fichierVide() throws {
        #expect(try analyser("vide.xml") == nil)
    }

    @Test("Des octets qui ne sont pas du texte ne rendent rien")
    func octetsBinaires() {
        let octets = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46])

        #expect(AnalyseurDeComicInfo.analyser(octets) == nil)
    }

    // MARK: Champ Manga

    @Test(
        "Seules les valeurs qui tranchent produisent un sens de lecture",
        arguments: [
            ("YesAndRightToLeft", SensDeLecture.droiteGauche),
            ("yesandrighttoleft", SensDeLecture.droiteGauche),
            ("No", SensDeLecture.gaucheDroite),
        ]
    )
    func sensDeLectureTranche(valeur: String, attendu: SensDeLecture) {
        let octets = Data("<ComicInfo><Manga>\(valeur)</Manga></ComicInfo>".utf8)

        #expect(AnalyseurDeComicInfo.analyser(octets)?.sensDeLecture == attendu)
    }

    @Test(
        "Une valeur qui ne tranche pas laisse le reglage global decider",
        arguments: ["Yes", "Unknown", "", "Peut etre"]
    )
    func sensDeLectureIndecis(valeur: String) {
        let octets = Data(
            "<ComicInfo><Series>S</Series><Manga>\(valeur)</Manga></ComicInfo>".utf8
        )

        #expect(AnalyseurDeComicInfo.analyser(octets)?.sensDeLecture == nil)
    }

    // MARK: Entites et casse

    @Test("Les entites XML sont resolues plutot que rendues telles quelles")
    func entitesResolues() {
        let octets = Data(
            "<ComicInfo><Series>Nuit &amp; Jour</Series><Summary>&#233;t&#233;</Summary></ComicInfo>"
                .utf8
        )
        let lues = AnalyseurDeComicInfo.analyser(octets)

        #expect(lues?.serie == "Nuit & Jour")
        #expect(lues?.resume == "été")
    }

    @Test("Les noms d elements sont lus sans tenir compte de la casse")
    func casseDesElements() {
        let octets = Data("<comicinfo><SERIES>Casse</SERIES></comicinfo>".utf8)

        #expect(AnalyseurDeComicInfo.analyser(octets)?.serie == "Casse")
    }
}
