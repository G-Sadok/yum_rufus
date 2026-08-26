import Core
import Foundation
@testable import Sources

//
// ReponsesFigeesDeKomga
//
// Les reponses du serveur, recopiees dans la forme que Komga rend reellement et
// figees ici une fois pour toutes.
//
// Elles ne sont pas propres, et c est voulu. Le resume de la premiere serie est
// une chaine de blancs, la langue de la seconde est vide, son statut porte un
// mot que nous ne connaissons pas, un livre n a pas de numero trie, un autre
// n a aucune metadonnee, une page n annonce pas sa taille, et la liste des
// pages arrive dans le desordre. Chacun de ces defauts vient d un serveur reel
// et chacun casse une implementation ecrite contre une reponse ideale.
//

/// Le jeu de reponses de reference du serveur de test.
enum ReponsesFigeesDeKomga {
    /// Adresse du serveur de test.
    static let adresse = URL(string: "https://komga.exemple.test")

    static let identifiantDeSerie = "0G2P1RQF3W2XK"
    static let identifiantDuPremierLivre = "0H4T7ZC1MB9DE"

    /// Reponse du point d entree du compte, celui de la verification.
    static let compte = """
    {
      "id": "0FZ8N6QW2ARTB",
      "email": "lecteur@exemple.test",
      "roles": ["USER", "FILE_DOWNLOAD", "PAGE_STREAMING"]
    }
    """

    /// Premiere tranche du catalogue, avec une suite annoncee.
    static let premiereTrancheDeSeries = """
    {
      "content": [
        {
          "id": "0G2P1RQF3W2XK",
          "libraryId": "0FYT4KMD8VNQZ",
          "name": "berserk-vf",
          "booksCount": 3,
          "metadata": {
            "status": "ONGOING",
            "title": "Berserk",
            "titleSort": "Berserk",
            "summary": "   ",
            "genres": ["Seinen", "Dark Fantasy"],
            "language": "ja"
          },
          "booksMetadata": {
            "authors": [
              {"name": "Kentaro Miura", "role": "writer"},
              {"name": "Kentaro Miura", "role": "penciller"},
              {"name": "Studio Gaga", "role": "inker"}
            ],
            "summary": "Un mercenaire marque poursuit ceux qui l ont trahi."
          }
        },
        {
          "id": "0G9L5XDS1PVCM",
          "libraryId": "0FYT4KMD8VNQZ",
          "name": "vagabond",
          "booksCount": 0,
          "metadata": {
            "status": "EN_ATTENTE_DE_TRADUCTION",
            "title": "",
            "summary": "",
            "genres": [],
            "language": ""
          }
        }
      ],
      "number": 0,
      "size": 2,
      "totalElements": 3,
      "totalPages": 2,
      "first": true,
      "last": false,
      "empty": false
    }
    """

    /// Seconde tranche du catalogue, la derniere.
    static let secondeTrancheDeSeries = """
    {
      "content": [
        {
          "id": "0GBW3JHN7QK4R",
          "libraryId": "0FYT4KMD8VNQZ",
          "name": "pluto",
          "booksCount": 8,
          "metadata": {
            "status": "ENDED",
            "title": "Pluto",
            "summary": "Une enquete menee par un robot.",
            "genres": ["Science fiction"],
            "language": "ja"
          },
          "booksMetadata": {
            "authors": [{"name": "Naoki Urasawa", "role": "writer"}],
            "summary": ""
          }
        }
      ],
      "number": 1,
      "size": 2,
      "totalElements": 3,
      "totalPages": 2,
      "first": false,
      "last": true,
      "empty": false
    }
    """

    /// Detail d une serie, tel que la fiche le demande.
    static let detailDeSerie = """
    {
      "id": "0G2P1RQF3W2XK",
      "libraryId": "0FYT4KMD8VNQZ",
      "name": "berserk-vf",
      "booksCount": 3,
      "metadata": {
        "status": "ONGOING",
        "title": "Berserk",
        "summary": "   ",
        "genres": ["Seinen", "Dark Fantasy"],
        "language": "ja"
      },
      "booksMetadata": {
        "authors": [
          {"name": "Kentaro Miura", "role": "writer"},
          {"name": "Studio Gaga", "role": "inker"}
        ],
        "summary": "Un mercenaire marque poursuit ceux qui l ont trahi."
      }
    }
    """

    /// Premiere tranche des livres d une serie, avec une suite annoncee.
    static let premiereTrancheDeLivres = """
    {
      "content": [
        {
          "id": "0H4T7ZC1MB9DE",
          "seriesId": "0G2P1RQF3W2XK",
          "name": "Tome 01",
          "media": {"status": "READY", "mediaType": "application/zip", "pagesCount": 3},
          "metadata": {
            "title": "L oeuf du roi",
            "number": "1",
            "numberSort": 1.0,
            "releaseDate": "1990-11-26"
          },
          "readProgress": {
            "page": 2,
            "completed": false,
            "readDate": "2026-02-03T18:24:05.123Z"
          }
        },
        {
          "id": "0H6D2VAK5NPXL",
          "seriesId": "0G2P1RQF3W2XK",
          "name": "Tome 02 bonus",
          "media": {"status": "UNKNOWN", "mediaType": "application/zip", "pagesCount": 0},
          "metadata": {
            "title": "",
            "number": "2.5",
            "releaseDate": null
          }
        }
      ],
      "number": 0,
      "size": 2,
      "totalElements": 3,
      "totalPages": 2,
      "first": true,
      "last": false,
      "empty": false
    }
    """

    /// Seconde tranche des livres, la derniere, avec un livre sans metadonnees.
    static let secondeTrancheDeLivres = """
    {
      "content": [
        {
          "id": "0H8K9WEB3RTMY",
          "seriesId": "0G2P1RQF3W2XK",
          "media": {"status": "READY", "mediaType": "application/zip", "pagesCount": 12}
        }
      ],
      "number": 1,
      "size": 2,
      "totalElements": 3,
      "totalPages": 2,
      "first": false,
      "last": true,
      "empty": false
    }
    """

    /// Les pages d un livre, rendues dans le desordre par le serveur.
    static let pagesDuLivre = """
    [
      {
        "number": 2, "fileName": "002.jpg", "mediaType": "image/jpeg",
        "width": 1600, "height": 2300, "sizeBytes": 204800
      },
      {
        "number": 1, "fileName": "001.jpg", "mediaType": "image/jpeg",
        "width": 1600, "height": 2300, "sizeBytes": 102400
      },
      {"number": 3, "fileName": "003.png", "mediaType": "image/png", "width": 1600, "height": 2300}
    ]
    """

    /// Un livre dont le serveur tient une progression en cours.
    static let livreEnCoursDeLecture = """
    {
      "id": "0H4T7ZC1MB9DE",
      "seriesId": "0G2P1RQF3W2XK",
      "name": "Tome 01",
      "media": {"status": "READY", "mediaType": "application/zip", "pagesCount": 20},
      "metadata": {"title": "L oeuf du roi", "number": "1", "numberSort": 1.0},
      "readProgress": {
        "page": 7,
        "completed": false,
        "readDate": "2026-02-03T18:24:05.123Z",
        "created": "2026-02-01T09:00:00",
        "lastModified": "2026-02-03T18:24:05"
      }
    }
    """

    /// Le meme livre, que le serveur declare lu.
    static let livreLu = """
    {
      "id": "0H4T7ZC1MB9DE",
      "seriesId": "0G2P1RQF3W2XK",
      "name": "Tome 01",
      "media": {"status": "READY", "mediaType": "application/zip", "pagesCount": 20},
      "metadata": {"title": "L oeuf du roi", "number": "1", "numberSort": 1.0},
      "readProgress": {"page": 20, "completed": true, "readDate": "2026-02-04T07:10:00Z"}
    }
    """

    /// Le meme livre, jamais ouvert : aucune progression n accompagne la reponse.
    static let livreJamaisOuvert = """
    {
      "id": "0H4T7ZC1MB9DE",
      "seriesId": "0G2P1RQF3W2XK",
      "name": "Tome 01",
      "media": {"status": "READY", "mediaType": "application/zip", "pagesCount": 20},
      "metadata": {"title": "L oeuf du roi", "number": "1", "numberSort": 1.0}
    }
    """

    /// Une reponse qui n est pas du JSON, celle d un proxy qui sert une page web.
    static let malformee = """
    <!DOCTYPE html><html><head><title>502 Bad Gateway</title></head><body></body></html>
    """

    /// Un catalogue coupe en plein milieu.
    static let troncature = """
    {"content": [{"id": "0G2P1RQF3W2XK", "name": "ber
    """
}

// MARK: - Montage d une source de test

/// Ce qu il faut pour interroger une source Komga sans serveur.
struct ServeurKomgaDeTest {
    let transport: TransportFige
    let magasin = MagasinDIdentifiantsEnMemoire()
    let id = SourceID()
    let nom = "Komga de test"

    /// Compte et mot de passe de la source, tels qu ils seront ranges dans le
    /// trousseau volatil des tests.
    static let compte = "lecteur"
    static let motDePasse = "phrase-de-passe-de-test"

    /// Adresse d un serveur de reseau local, non chiffree.
    static let adresseEnClair = URL(string: "http://192.168.1.20:25600")

    init(_ regles: [RegleDeTransport]) {
        transport = TransportFige(regles)
    }

    /// Les regles qui servent un catalogue complet, de la connexion aux pages.
    ///
    /// L ordre compte : la premiere regle qui correspond gagne, et le chemin
    /// d une page de livre se termine par celui du livre. Les regles les plus
    /// precises viennent donc d abord.
    static var reglesCompletes: [RegleDeTransport] {
        let serie = ReponsesFigeesDeKomga.identifiantDeSerie
        let livre = ReponsesFigeesDeKomga.identifiantDuPremierLivre

        return [
            .json(.get, "api/v1/users/me", ReponsesFigeesDeKomga.compte),
            .json(.get, "api/v1/books/\(livre)/pages", ReponsesFigeesDeKomga.pagesDuLivre),
            .json(.get, "api/v1/books/\(livre)", ReponsesFigeesDeKomga.livreEnCoursDeLecture),
            .json(
                .get,
                "api/v1/series/\(serie)/books",
                ReponsesFigeesDeKomga.premiereTrancheDeLivres,
                quand: ["page": "0"]
            ),
            .json(
                .get,
                "api/v1/series/\(serie)/books",
                ReponsesFigeesDeKomga.secondeTrancheDeLivres,
                quand: ["page": "1"]
            ),
            .json(.get, "api/v1/series/\(serie)", ReponsesFigeesDeKomga.detailDeSerie),
            .json(
                .get,
                "api/v1/series",
                ReponsesFigeesDeKomga.premiereTrancheDeSeries,
                quand: ["page": "0"]
            ),
            .json(
                .get,
                "api/v1/series",
                ReponsesFigeesDeKomga.secondeTrancheDeSeries,
                quand: ["page": "1"]
            ),
            .sansContenu(.patch, "read-progress"),
            .sansContenu(.delete, "read-progress"),
        ]
    }

    /// La source, avec ses identifiants deja ranges dans le trousseau.
    func source(
        authentification: NatureDAuthentification = .basique,
        adresse: URL? = ReponsesFigeesDeKomga.adresse,
        accepteLeHttpEnClair: Bool = false,
        tailleDePage: Int = 2
    ) async throws -> SourceKomga {
        await magasin.enregistrer(Self.identifiants(authentification), pour: id)

        return try SourceKomga(
            id: id,
            nom: nom,
            configuration: ConfigurationDeSource(
                adresse: adresse,
                authentification: authentification,
                accepteLeHttpEnClair: accepteLeHttpEnClair
            ),
            magasin: magasin,
            transport: transport,
            tailleDePage: tailleDePage
        )
    }

    private static func identifiants(_ nature: NatureDAuthentification) -> IdentifiantsDeSource {
        switch nature {
        case .aucune: .aucun
        case .basique: .basique(compte: compte, motDePasse: motDePasse)
        case .cleDApi: .cleDApi("cle-de-test")
        case .jeton: .jeton(acces: "jeton-de-test")
        }
    }
}
