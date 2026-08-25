import Core
import Foundation
import Testing

/// Couvre le modele de metadonnees lui meme : conversion du numero, fusion des
/// deux sources, et report sur les entites du catalogue.
struct MetadonneesComicTests {
    // MARK: Numero

    @Test(
        "Un numero decimal est converti, un numero textuel ne l est pas",
        arguments: [
            ("12", 12.0),
            ("3.5", 3.5),
            ("  7 ", 7.0),
            ("10,5", 10.5),
            ("12 (of 24)", 12.0),
            ("0", 0.0),
        ]
    )
    func numeroConverti(brut: String, attendu: Double) {
        #expect(MetadonneesComic(numero: brut).numeroDecimal == attendu)
    }

    @Test(
        "Un numero sans tete numerique ne devient pas zero",
        arguments: ["Annual", "HS", "", "   ", "Special Edition"]
    )
    func numeroNonConverti(brut: String) {
        // Rendre zero rangerait ces chapitres avant le premier de la serie.
        #expect(MetadonneesComic(numero: brut).numeroDecimal == nil)
    }

    @Test("Un modele sans numero n en invente pas")
    func numeroAbsent() {
        #expect(MetadonneesComic().numeroDecimal == nil)
    }

    // MARK: Vacuite

    @Test("Un modele sans aucun champ se declare vide")
    func vacuite() {
        #expect(MetadonneesComic().estVide)
        #expect(MetadonneesComic(serie: "S").estVide == false)
        #expect(MetadonneesComic(volume: 1).estVide == false)
        #expect(MetadonneesComic(genres: ["Drame"]).estVide == false)
        #expect(MetadonneesComic(sensDeLecture: .droiteGauche).estVide == false)
    }

    // MARK: Fusion

    @Test("Le secours comble les trous sans jamais ecraser")
    func fusionComble() {
        let prioritaires = MetadonneesComic(serie: "Prioritaire", numero: "1")
        let secours = MetadonneesComic(
            serie: "Secours",
            numero: "99",
            volume: 4,
            langue: "en",
            resume: "Resume de secours.",
            auteurs: ["A. Mercier"],
            genres: ["Drame"]
        )
        let fusion = prioritaires.complete(par: secours)

        #expect(fusion.serie == "Prioritaire")
        #expect(fusion.numero == "1")
        #expect(fusion.volume == 4)
        #expect(fusion.langue == "en")
        #expect(fusion.resume == "Resume de secours.")
        #expect(fusion.auteurs == ["A. Mercier"])
        #expect(fusion.genres == ["Drame"])
    }

    @Test("Une liste deja remplie n est pas completee par celle du secours")
    func fusionDesListes() {
        let prioritaires = MetadonneesComic(auteurs: ["Sato"])
        let fusion = prioritaires.complete(par: MetadonneesComic(auteurs: ["Ono", "Ashida"]))

        // Concatener produirait une liste de trois noms dont deux viennent
        // d une source que la section 5.3 declare secondaire.
        #expect(fusion.auteurs == ["Sato"])
    }

    // MARK: Report sur le modele

    @Test("Les metadonnees alimentent la serie sans effacer ce qui existe")
    func reportSurLaSerie() {
        let serie = Manga(
            sourceId: UUID(),
            identifiantDistant: "local://tome",
            titre: "Titre de repli",
            auteurs: [],
            resume: nil,
            genres: []
        )
        let lues = MetadonneesComic(
            serie: "Yoru no Hikari",
            langue: "ja",
            resume: "Un interlude sans dialogue.",
            auteurs: ["Haruna Sato"],
            dessinateurs: ["Haruna Sato"],
            genres: ["Tranche de vie"],
            sensDeLecture: .droiteGauche
        )
        let mis = lues.appliquer(a: serie)

        #expect(mis.titre == "Yoru no Hikari")
        #expect(mis.langue == "ja")
        #expect(mis.resume == "Un interlude sans dialogue.")
        #expect(mis.auteurs == ["Haruna Sato"])
        #expect(mis.dessinateurs == ["Haruna Sato"])
        #expect(mis.genres == ["Tranche de vie"])
        #expect(mis.sensLectureForce == .droiteGauche)
        #expect(mis.id == serie.id)
    }

    @Test("Un champ absent des metadonnees ne vide pas celui de la serie")
    func reportPartielSurLaSerie() {
        let serie = Manga(
            sourceId: UUID(),
            identifiantDistant: "local://tome",
            titre: "Titre existant",
            auteurs: ["Auteur existant"],
            resume: "Resume existant.",
            genres: ["Genre existant"],
            langue: "fr"
        )
        let mis = MetadonneesComic(numero: "3").appliquer(a: serie)

        #expect(mis.titre == "Titre existant")
        #expect(mis.resume == "Resume existant.")
        #expect(mis.langue == "fr")
        #expect(mis.auteurs == ["Auteur existant"])
        #expect(mis.genres == ["Genre existant"])
    }

    @Test("Un sens de lecture choisi par l utilisateur prime sur le fichier")
    func sensDeLectureNonEcrase() {
        let serie = Manga(
            sourceId: UUID(),
            identifiantDistant: "local://tome",
            titre: "Serie",
            sensLectureForce: .gaucheDroite
        )
        let mis = MetadonneesComic(sensDeLecture: .droiteGauche).appliquer(a: serie)

        #expect(mis.sensLectureForce == .gaucheDroite)
    }

    @Test("Les metadonnees alimentent le chapitre")
    func reportSurLeChapitre() {
        let chapitre = Chapitre(
            mangaId: UUID(),
            identifiantDistant: "local://tome/3",
            numero: 0,
            nombrePages: 18,
            ordreDansSerie: 2
        )
        let lues = MetadonneesComic(titre: "Chapitre bonus", numero: "3.5", langue: "ja")
        let mis = lues.appliquer(a: chapitre)

        #expect(mis.titre == "Chapitre bonus")
        #expect(mis.numero == 3.5)
        #expect(mis.langue == "ja")

        // Le conteneur fait foi sur le nombre de pages, jamais le fichier de
        // metadonnees, dont le PageCount est frequemment errone.
        #expect(mis.nombrePages == 18)
    }

    @Test("Un numero textuel laisse le numero du chapitre inchange")
    func chapitreSansNumeroExploitable() {
        let chapitre = Chapitre(
            mangaId: UUID(),
            identifiantDistant: "local://tome/annual",
            numero: 12,
            ordreDansSerie: 11
        )
        let mis = MetadonneesComic(numero: "Annual").appliquer(a: chapitre)

        #expect(mis.numero == 12)
    }
}
