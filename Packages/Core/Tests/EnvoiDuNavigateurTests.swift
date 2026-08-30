import Foundation
import Testing
@testable import Core

//
// EnvoiDuNavigateurTests
//
// Ce que le pont accepte de recevoir d une page ouverte dans le navigateur.
//
// Le corps vient de l exterieur, il est donc couvert comme une reponse de
// source : un corps valide, un corps malforme, un corps vide, un corps tronque,
// et les champs manquants. La difference avec une reponse de source est le
// refus par schema : ici, un corps parfaitement forme peut etre refuse pour ce
// qu il porte, et ce refus la est le premier verrou contre une lecture de
// fichier local demandee par une page web.
//

struct EnvoiDuNavigateurTests {
    @Test("Un envoi complet se lit")
    func envoiCompletSeLit() throws {
        let envoi = try EnvoiDuNavigateur.analyser(corps(
            adresse: "https://catalogue.exemple.net/serie/4217",
            titre: "Le Chant du Cygne"
        ))

        #expect(envoi.adresse.absoluteString == "https://catalogue.exemple.net/serie/4217")
        #expect(envoi.titre == "Le Chant du Cygne")
    }

    @Test("Les espaces autour du titre sont retires")
    func espacesAutourDuTitreRetires() throws {
        // Le retour a la ligne est celui que le JSON porte reellement, pas une
        // suite de deux caracteres : une page dont le titre tient sur deux
        // lignes arrive ainsi, et l espace interieur, lui, reste.
        let envoi = try EnvoiDuNavigateur.analyser(corps(titre: "  Le Chant  du Cygne \\n "))

        #expect(envoi.titre == "Le Chant  du Cygne")
    }

    @Test(
        "Une adresse qui n est pas en HTTPS est refusee",
        arguments: [
            "http://catalogue.exemple.net/serie/4217",
            "file:///Users/lecteur/Documents/serie.cbz",
            "ftp://catalogue.exemple.net/serie",
            "https:///serie/4217",
        ]
    )
    func adresseHorsHttpsRefusee(adresse: String) {
        #expect(throws: ErreurDuPont.adresseRefusee) {
            try EnvoiDuNavigateur.analyser(corps(adresse: adresse))
        }
    }

    @Test("Un titre vide est refuse")
    func titreVideRefuse() {
        #expect(throws: ErreurDuPont.envoiIllisible) {
            try EnvoiDuNavigateur.analyser(corps(titre: "   "))
        }
    }

    @Test("Un titre plus long que le plafond est refuse")
    func titreTropLongRefuse() {
        let long = String(repeating: "a", count: EnvoiDuNavigateur.plafondDuTitre + 1)

        #expect(throws: ErreurDuPont.envoiIllisible) {
            try EnvoiDuNavigateur.analyser(corps(titre: long))
        }
    }

    @Test("Un titre exactement au plafond passe")
    func titreAuPlafondPasse() throws {
        let long = String(repeating: "a", count: EnvoiDuNavigateur.plafondDuTitre)
        let envoi = try EnvoiDuNavigateur.analyser(corps(titre: long))

        #expect(envoi.titre.count == EnvoiDuNavigateur.plafondDuTitre)
    }

    @Test("Une adresse plus longue que le plafond est refusee")
    func adresseTropLongueRefusee() {
        let bourrage = String(repeating: "a", count: EnvoiDuNavigateur.plafondDeLAdresse)

        #expect(throws: ErreurDuPont.envoiIllisible) {
            try EnvoiDuNavigateur.analyser(corps(adresse: "https://exemple.net/" + bourrage))
        }
    }

    @Test(
        "Un corps qui n est pas un envoi est refuse",
        arguments: [
            "",
            "   ",
            "{",
            "{\"adresse\": \"https://exemple.net/serie\"}",
            "{\"titre\": \"Le Chant du Cygne\"}",
            "[]",
            "{\"adresse\": 42, \"titre\": \"Le Chant du Cygne\"}",
            "{\"adresse\": \"https://exemple.net/serie\", \"titre\": \"Le Chant",
        ]
    )
    func corpsIllisibleRefuse(texte: String) {
        #expect(throws: ErreurDuPont.envoiIllisible, "\(texte)") {
            try EnvoiDuNavigateur.analyser(Data(texte.utf8))
        }
    }

    @Test("Les champs en trop sont ignores")
    func champsEnTropIgnores() throws {
        let texte = """
        {"adresse": "https://exemple.net/serie", "titre": "Titre", "chapitres": 42}
        """
        let envoi = try EnvoiDuNavigateur.analyser(Data(texte.utf8))

        #expect(envoi.titre == "Titre")
    }

    @Test("La regle d acceptation d une adresse se lit aussi seule")
    func regleDAcceptationSeule() throws {
        let securisee = try #require(URL(string: "https://exemple.net/serie"))
        let majuscules = try #require(URL(string: "HTTPS://exemple.net/serie"))
        let enClair = try #require(URL(string: "http://exemple.net/serie"))
        let sansHote = try #require(URL(string: "https:///serie"))

        #expect(EnvoiDuNavigateur.accepte(securisee))
        #expect(EnvoiDuNavigateur.accepte(majuscules))
        #expect(EnvoiDuNavigateur.accepte(enClair) == false)
        #expect(EnvoiDuNavigateur.accepte(sansHote) == false)
    }

    /// Le corps JSON d un envoi, tel que l extension l ecrirait.
    private func corps(
        adresse: String = "https://catalogue.exemple.net/serie/4217",
        titre: String = "Le Chant du Cygne"
    ) -> Data {
        Data(
            """
            {"adresse": "\(adresse)", "titre": "\(titre)"}
            """.utf8
        )
    }
}
