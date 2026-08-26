import Core
import Foundation
@testable import Sources

//
// CatalogueDeclaratifDeTest
//
// Un catalogue complet decrit en regles declaratives, et le serveur fige qui
// lui repond.
//
// Le manifeste et les reponses sont ecrits ensemble parce qu ils se verifient
// l un l autre : une regle qui cherche `$.results[*]` dans un document qui
// publie `data` rendrait une source vide, et c est exactement le genre de
// desaccord que ces tests doivent faire echouer.
//
// Le catalogue melange volontairement les deux formats. Les listes sont en
// JSON, les pages d un chapitre sont en HTML, comme chez les catalogues reels
// qui exposent une API pour leur index et rien pour leur lecteur.
//

enum CatalogueDeclaratifDeTest {
    /// Le manifeste du catalogue de test.
    static let manifeste = """
    {
      "format": 1,
      "identifiant": "exemple.catalogue",
      "nom": "Catalogue Exemple",
      "version": "1.4",
      "langue": "fr",
      "capacites": ["recherche", "pagination", "telechargement"],
      "domaines": ["api.exemple.net", "*.images.exemple.net"],
      "regles": {
        "adresseDeBase": "https://api.exemple.net",
        "pageDeDepart": 1,
        "recherche": {
          "requete": {
            "chemin": "/recherche",
            "parametres": [
              { "nom": "q", "valeur": "{texteRecherche}" },
              { "nom": "page", "valeur": "{page}" }
            ],
            "format": "json"
          },
          "elements": { "json": "$.results[*]" },
          "champs": {
            "identifiant": { "json": "$.id" },
            "titre": { "json": "$.title" },
            "auteurs": { "json": "$.authors[*]" },
            "statut": { "json": "$.status" },
            "couverture": { "json": "$.cover" },
            "nombreChapitres": { "json": "$.chapterCount" }
          },
          "pagination": { "totalAnnonce": { "json": "$.total" }, "tailleDePage": 1 }
        },
        "sections": [
          {
            "section": "recentes",
            "regle": {
              "requete": { "chemin": "/recentes", "format": "json" },
              "elements": { "json": "$.results[*]" },
              "champs": {
                "identifiant": { "json": "$.id" },
                "titre": { "json": "$.title" }
              },
              "pagination": { "listePleine": 2 }
            }
          }
        ],
        "details": {
          "requete": { "chemin": "/series/{identifiantSerie}", "format": "json" },
          "element": { "json": "$.serie" },
          "champs": {
            "identifiant": { "json": "$.id" },
            "titre": { "json": "$.title" },
            "resume": { "json": "$.summary" }
          }
        },
        "chapitres": {
          "requete": { "chemin": "/series/{identifiantSerie}/chapitres", "format": "json" },
          "elements": { "json": "$.items[*]" },
          "champs": {
            "identifiant": { "json": "$.id" },
            "numero": { "json": "$.number" },
            "titre": { "json": "$.title" },
            "datePublication": { "json": "$.published" }
          },
          "ordreInverse": true
        },
        "pages": {
          "requete": { "chemin": "/chapitres/{identifiantChapitre}/pages", "format": "html" },
          "elements": { "html": "div.page > img" },
          "champs": {
            "emplacement": { "html": "img", "attribut": "src" }
          }
        }
      }
    }
    """

    /// Le manifeste lu.
    static func lu() throws -> ManifesteDExtension {
        try ManifesteDExtension.lire(Data(manifeste.utf8))
    }

    /// Instant de confirmation des tests, fixe pour que rien ne depende de
    /// l horloge de la machine.
    static let instantDeConfirmation = Date(timeIntervalSince1970: 1_700_000_000)

    /// L extension installee, avec la confirmation de ses domaines.
    static func installee(le instant: Date = instantDeConfirmation) throws -> ExtensionInstallee {
        let manifeste = try lu()
        let confirmation = ConfirmationDesDomaines(
            avertissement: AvertissementDInstallation(manifeste: manifeste),
            instant: instant
        )

        return try InstallateurDExtensions().installer(manifeste, confirmation: confirmation)
    }

    // MARK: Reponses figees

    static let recherche = """
    {
      "results": [
        {
          "id": 12,
          "title": "Serie de reference",
          "authors": ["Une autrice", "Un auteur"],
          "status": "Ongoing",
          "cover": "/couvertures/12.jpg",
          "chapterCount": 42
        }
      ],
      "total": 3
    }
    """

    static let recentes = """
    { "results": [{ "id": "a", "title": "Une" }, { "id": "b", "title": "Deux" }] }
    """

    static let details = """
    { "serie": { "id": "12", "title": "Serie de reference", "summary": "Un resume" } }
    """

    /// Les chapitres, publies du plus recent au plus ancien.
    static let chapitres = """
    {
      "items": [
        { "id": "c-2", "number": 2, "title": "Deuxieme", "published": "2024-02-01T00:00:00Z" },
        { "id": "c-1", "number": 1, "title": "Premier", "published": "2024-01-01T00:00:00Z" }
      ]
    }
    """

    /// Les pages, dans une page HTML mal fermee comme une vraie.
    static let pages = """
    <!DOCTYPE html>
    <html><body>
      <script>var pieges = "<div class=\\"page\\"><img src=/piege.jpg>";</script>
      <div class=page><img src="/p/1.jpg" alt=Premiere>
      <div class="page grande"><img src='https://images.exemple.net/p/2.jpg'>
      <div class="vignette"><img src="/miniature.jpg"></div>
    </body></html>
    """

    /// Le serveur fige qui sert ce catalogue.
    static func serveur() -> TransportEspion {
        TransportEspion([
            .json("https://api.exemple.net/recherche", recherche),
            .json("https://api.exemple.net/recentes", recentes),
            .json("https://api.exemple.net/series/12/chapitres", chapitres),
            .json("https://api.exemple.net/series/12", details),
            .init(
                "https://api.exemple.net/chapitres/c-1/pages",
                ReponseHttp(code: 200, entetes: ["Content-Type": "text/html"], corps: Data(pages.utf8))
            ),
        ])
    }
}
