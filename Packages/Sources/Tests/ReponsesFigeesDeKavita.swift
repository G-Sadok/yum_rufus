import Core
import Foundation
@testable import Sources

//
// ReponsesFigeesDeKavita
//
// Les reponses du serveur Kavita, recopiees dans la forme qu il rend reellement
// et figees ici une fois pour toutes.
//
// Comme celles de Komga, elles ne sont pas propres. Une serie n a pas de nom
// localise, une autre porte un statut de publication que nous ne connaissons
// pas, un genre est vide, un scenariste est cite deux fois, un chapitre n a que
// son intervalle, un autre voit son numero recopie dans son titre, un
// troisieme porte la date minimale que le serveur ecrit quand il ne connait
// aucune date, et un quatrieme est range hors volume sous la sentinelle des
// versions recentes. Chacun de ces defauts vient d un serveur reel.
//
// Le jeton merite une note. Il est fabrique et non recopie : un vrai jeton
// recopie porterait une echeance passee depuis longtemps, et le test ne
// prouverait plus rien le jour ou il expirerait. Il est donc construit autour de
// l horloge figee du serveur de test, ce qui rend l echeance reproductible. La
// fabrique et le montage vivent dans `ServeurKavitaDeTest`.
//

/// Le jeu de reponses de reference du serveur Kavita de test.
enum ReponsesFigeesDeKavita {
    /// Adresse du serveur de test.
    static let adresse = URL(string: "https://kavita.exemple.test")

    /// Adresse d un serveur de reseau local, non chiffree.
    static let adresseEnClair = URL(string: "http://192.168.1.30:5000")

    static let identifiantDeSerie = 17
    static let identifiantDuPremierChapitre = 401

    /// Reponse de la connexion, avec la cle d API des images.
    static func connexion(jeton: String) -> String {
        """
        {
          "username": "lecteur",
          "email": "lecteur@exemple.test",
          "token": "\(jeton)",
          "refreshToken": "rafraichissement-neuf",
          "apiKey": "\(ServeurKavitaDeTest.cleDApi)",
          "preferences": {"readingDirection": 0}
        }
        """
    }

    /// Reponse du rafraichissement, qui ne rappelle pas la cle d API.
    static func rafraichissement(jeton: String) -> String {
        """
        {
          "token": "\(jeton)",
          "refreshToken": "rafraichissement-suivant"
        }
        """
    }

    /// Premiere tranche du catalogue, avec une suite annoncee par l entete.
    static let premiereTrancheDeSeries = """
    [
      {
        "id": 17,
        "name": "berserk-vf",
        "originalName": "Berserk",
        "localizedName": "Berserk",
        "libraryId": 2,
        "format": 3
      },
      {
        "id": 23,
        "name": "vagabond",
        "originalName": "",
        "localizedName": "",
        "libraryId": 2,
        "format": 3
      }
    ]
    """

    /// Seconde tranche du catalogue, la derniere.
    static let secondeTrancheDeSeries = """
    [
      {
        "id": 31,
        "name": "pluto",
        "originalName": "PLUTO",
        "localizedName": "Pluto",
        "libraryId": 2,
        "format": 3
      }
    ]
    """

    /// Entete de pagination de la premiere tranche.
    static let paginationPremiereTranche = """
    {"currentPage": 1, "itemsPerPage": 2, "totalItems": 3, "totalPages": 2}
    """

    /// Entete de pagination de la derniere tranche.
    static let paginationDerniereTranche = """
    {"currentPage": 2, "itemsPerPage": 2, "totalItems": 3, "totalPages": 2}
    """

    /// Detail d une serie, tel que la fiche le demande.
    static let detailDeSerie = """
    {
      "id": 17,
      "name": "berserk-vf",
      "originalName": "Berserk",
      "localizedName": "Berserk",
      "libraryId": 2,
      "format": 3
    }
    """

    /// Metadonnees de la serie, servies par un point d entree separe.
    ///
    /// Le scenariste est cite deux fois, une fois comme auteur et une fois comme
    /// dessinateur, et un genre est vide.
    static let metadonneesDeSerie = """
    {
      "seriesId": 17,
      "summary": "Un mercenaire marque poursuit ceux qui l ont trahi.",
      "genres": [{"id": 4, "title": "Seinen"}, {"id": 9, "title": "Dark Fantasy"}, {"id": 12, "title": "  "}],
      "tags": [],
      "writers": [{"id": 1, "name": "Kentaro Miura"}],
      "pencillers": [{"id": 1, "name": "Kentaro Miura"}],
      "coverArtists": [{"id": 2, "name": "Studio Gaga"}],
      "publicationStatus": 0,
      "language": "ja",
      "releaseYear": 1989
    }
    """

    /// Metadonnees d une serie dont le statut nous est inconnu.
    static let metadonneesInconnues = """
    {
      "seriesId": 23,
      "summary": "   ",
      "genres": [],
      "writers": [],
      "pencillers": [],
      "coverArtists": [],
      "publicationStatus": 42,
      "language": ""
    }
    """

    /// Les volumes de la serie, rendus dans le desordre par le serveur.
    ///
    /// Le volume deux arrive avant le volume un, et le paquet des chapitres
    /// hors volume arrive au milieu sous la sentinelle des versions recentes.
    /// Trie sur le seul numero de chapitre, l ordre de lecture serait faux.
    static let volumesDeLaSerie = """
    [
      {
        "id": 92,
        "name": "2",
        "minNumber": 2,
        "chapters": [
          {
            "id": 403,
            "range": "3-4",
            "pages": 12,
            "title": "3-4",
            "titleName": "",
            "releaseDate": "0001-01-01T00:00:00"
          }
        ]
      },
      {
        "id": 99,
        "name": "-100000",
        "minNumber": 2147483647,
        "chapters": [
          {
            "id": 404,
            "number": "5",
            "minNumber": 5,
            "pages": 0,
            "title": "Hors volume",
            "titleName": "Hors volume",
            "releaseDate": null
          }
        ]
      },
      {
        "id": 91,
        "name": "1",
        "minNumber": 1,
        "chapters": [
          {
            "id": 401,
            "number": "1",
            "minNumber": 1,
            "pages": 3,
            "title": "L oeuf du roi",
            "titleName": "L oeuf du roi",
            "releaseDate": "1990-11-26T00:00:00"
          },
          {
            "id": 402,
            "number": "2",
            "minNumber": 2,
            "pages": 20,
            "title": "2",
            "titleName": "",
            "releaseDate": "1991-03-08T00:00:00"
          }
        ]
      }
    ]
    """

    /// Ce que le serveur sait du premier chapitre au moment de l ouvrir.
    static let infoDuPremierChapitre = """
    {
      "chapterNumber": "1",
      "volumeNumber": "1",
      "volumeId": 91,
      "seriesId": 17,
      "libraryId": 2,
      "seriesName": "Berserk",
      "chapterTitle": "L oeuf du roi",
      "pages": 3,
      "isSpecial": false
    }
    """

    /// Une progression en cours sur le premier chapitre.
    static let progressionEnCours = """
    {
      "volumeId": 91,
      "chapterId": 401,
      "pageNum": 1,
      "seriesId": 17,
      "libraryId": 2,
      "lastModifiedUtc": "2026-02-03T18:24:05.123Z"
    }
    """

    /// Un chapitre jamais ouvert : page zero et aucune date.
    static let progressionAbsente = """
    {
      "volumeId": 91,
      "chapterId": 401,
      "pageNum": 0,
      "seriesId": 17,
      "libraryId": 2,
      "lastModifiedUtc": null
    }
    """

    /// Un chapitre que le serveur considere comme lu.
    static let progressionTerminee = """
    {
      "volumeId": 91,
      "chapterId": 401,
      "pageNum": 3,
      "seriesId": 17,
      "libraryId": 2,
      "lastModifiedUtc": "2026-02-04T07:10:00Z"
    }
    """

    /// Ce que la recherche rend, dans une enveloppe qui n est pas celle du
    /// catalogue.
    static let resultatsDeRecherche = """
    {
      "series": [
        {"seriesId": 17, "name": "berserk-vf", "localizedName": "Berserk", "libraryId": 2},
        {"seriesId": 23, "name": "vagabond", "localizedName": "", "libraryId": 2}
      ],
      "collections": [],
      "persons": [],
      "tags": []
    }
    """

    /// Une reponse qui n est pas du JSON, celle d un proxy qui sert une page web.
    static let malformee = """
    <!DOCTYPE html><html><head><title>502 Bad Gateway</title></head><body></body></html>
    """

    /// Un catalogue coupe en plein milieu.
    static let troncature = """
    [{"id": 17, "name": "ber
    """
}
