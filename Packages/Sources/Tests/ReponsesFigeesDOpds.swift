import Foundation

//
// ReponsesFigeesDOpds
//
// Les flux d un catalogue OPDS, dans les deux versions du protocole, recopies
// dans la forme que les serveurs rendent reellement et figes ici une fois pour
// toutes. Le serveur qui les sert vit dans `CatalogueOpdsDeTest`.
//
// Les defauts poses dans ces flux sont ceux de catalogues reels.
//
// La 1.2 porte un auteur repete deux fois, une categorie sans libelle, une
// entree sans titre, un lien relatif sans barre de tete, et un lien vers le
// document d une seule entree qui ne doit surtout pas etre pris pour un sous
// catalogue. Le premier chapitre annonce la diffusion page par page avec une
// numerotation a partir de zero, le second ne l annonce pas du tout : les deux
// chemins de lecture cohabitent dans la meme serie.
//
// La 2.0 porte une relation ecrite en liste plutot qu en chaine, un auteur en
// chaine simple d un cote et en objet nomme de l autre, des sujets melangeant
// les deux formes, et un groupe qui contient une serie de plus. Les quatre sont
// autorises par la norme et les quatre s observent.
//

/// Le jeu de flux de reference du catalogue OPDS de test.
enum ReponsesFigeesDOpds {
    /// Adresse du catalogue de test.
    static let adresse = URL(string: "https://opds.exemple.test")

    /// Adresse d un catalogue de reseau local, non chiffree.
    static let adresseEnClair = URL(string: "http://192.168.1.60:8080")

    // MARK: Chemins

    static let cheminDuCatalogueAtom = "opds/v1.2/series"
    static let cheminDuCatalogueJson = "opds/v2/series"

    static let cheminDeLaSerieAtom = "opds/v1.2/series/berserk"
    static let cheminDesNouveautesAtom = "opds/v1.2/series/nouveautes"
    static let cheminDeLaSerieJson = "opds/v2/series/berserk"

    static let cheminDuFichierDuPremierChapitre = "opds/v1.2/books/1/file"
    static let cheminDuFichierDuSecondChapitre = "opds/v1.2/books/2/file"

    /// Les pages rangees dans le conteneur du second chapitre.
    static let pagesDuSecondChapitre = ["001.jpg", "002.jpg"]

    // MARK: Catalogue en OPDS 1.2

    /// Premiere page du catalogue Atom, avec un lien vers la suivante.
    static let cataloguePage1 = """
    <?xml version="1.0" encoding="UTF-8"?>
    <feed xmlns="http://www.w3.org/2005/Atom" xmlns:dc="http://purl.org/dc/terms/"
          xmlns:pse="http://vaemendis.net/opds-pse/ns">
      <id>urn:tsuzuki:catalogue</id>
      <title>Catalogue de test</title>
      <updated>2026-01-05T09:00:00Z</updated>
      <link rel="self" href="/opds/v1.2/series"
            type="application/atom+xml;profile=opds-catalog;kind=acquisition"/>
      <link rel="next" href="/opds/v1.2/series?page=1&amp;jeton=suite-imprevisible"
            type="application/atom+xml;profile=opds-catalog;kind=acquisition"/>
      <link rel="http://opds-spec.org/sort/new" href="/opds/v1.2/series/nouveautes"
            type="application/atom+xml;profile=opds-catalog;kind=acquisition"/>
      <entry>
        <id>urn:tsuzuki:serie:berserk</id>
        <title>Berserk</title>
        <updated>2026-01-04T08:30:00Z</updated>
        <author><name>Kentaro Miura</name></author>
        <author><name>Kentaro Miura</name></author>
        <summary>Un mercenaire marque par un sacrifice.</summary>
        <category term="action" label="Action"/>
        <category term="fantasy" label="Fantasy"/>
        <category term=""/>
        <dc:language>ja</dc:language>
        <link rel="http://opds-spec.org/image" href="/opds/v1.2/series/berserk/couverture"
              type="image/jpeg"/>
        <link rel="subsection" href="/opds/v1.2/series/berserk"
              type="application/atom+xml;profile=opds-catalog;kind=acquisition"/>
      </entry>
      <entry>
        <id>urn:tsuzuki:serie:vinland</id>
        <title>Vinland Saga</title>
        <updated>2026-01-03T08:30:00Z</updated>
        <link rel="subsection" href="series/vinland"
              type="application/atom+xml;profile=opds-catalog;kind=acquisition"/>
      </entry>
      <entry>
        <id>urn:tsuzuki:serie:anonyme</id>
        <link rel="subsection" href="/opds/v1.2/series/anonyme"
              type="application/atom+xml;profile=opds-catalog;kind=acquisition"/>
      </entry>
    </feed>
    """

    /// Seconde et derniere page du catalogue Atom, sans lien vers une suite.
    static let cataloguePage2 = """
    <?xml version="1.0" encoding="UTF-8"?>
    <feed xmlns="http://www.w3.org/2005/Atom">
      <id>urn:tsuzuki:catalogue</id>
      <title>Catalogue de test</title>
      <link rel="self" href="/opds/v1.2/series?page=1"
            type="application/atom+xml;profile=opds-catalog;kind=acquisition"/>
      <entry>
        <id>urn:tsuzuki:serie:yotsuba</id>
        <title>Yotsuba</title>
        <link rel="subsection" href="/opds/v1.2/series/yotsuba"
              type="application/atom+xml;profile=opds-catalog;kind=acquisition"/>
      </entry>
    </feed>
    """

    /// Premiere page des chapitres d une serie, en Atom.
    ///
    /// Le premier chapitre annonce la diffusion page par page, le second non.
    /// Le lien vers le document de la seule entree du premier est la pour etre
    /// ignore : c est un `alternate` de type `entry`, pas un sous catalogue.
    static let seriePage1 = """
    <?xml version="1.0" encoding="UTF-8"?>
    <feed xmlns="http://www.w3.org/2005/Atom" xmlns:pse="http://vaemendis.net/opds-pse/ns">
      <id>urn:tsuzuki:serie:berserk</id>
      <title>Berserk</title>
      <link rel="self" href="/opds/v1.2/series/berserk"
            type="application/atom+xml;profile=opds-catalog;kind=acquisition"/>
      <link rel="next" href="/opds/v1.2/series/berserk?page=1"
            type="application/atom+xml;profile=opds-catalog;kind=acquisition"/>
      <entry>
        <id>urn:tsuzuki:livre:1</id>
        <title>Chapitre 1</title>
        <updated>2026-01-02T10:00:00Z</updated>
        <link rel="alternate" href="/opds/v1.2/books/1"
              type="application/atom+xml;type=entry;profile=opds-catalog"/>
        <link rel="http://opds-spec.org/acquisition" href="/opds/v1.2/books/1/file"
              type="application/vnd.comicbook+zip"/>
        <link rel="http://vaemendis.net/opds-pse/stream"
              href="/opds/v1.2/books/1/pages/{pageNumber}?zero_based=true&amp;maxWidth={maxWidth}"
              type="image/jpeg" pse:count="3"/>
      </entry>
      <entry>
        <id>urn:tsuzuki:livre:2</id>
        <title>Chapitre 2</title>
        <updated>2026-01-03T10:00:00Z</updated>
        <link rel="http://opds-spec.org/acquisition/open-access" href="/opds/v1.2/books/2/file"
              type="application/zip"/>
      </entry>
    </feed>
    """

    /// Seconde et derniere page des chapitres d une serie, en Atom.
    static let seriePage2 = """
    <?xml version="1.0" encoding="UTF-8"?>
    <feed xmlns="http://www.w3.org/2005/Atom">
      <id>urn:tsuzuki:serie:berserk</id>
      <title>Berserk</title>
      <entry>
        <id>urn:tsuzuki:livre:10</id>
        <title>Chapitre 10</title>
        <link rel="http://opds-spec.org/acquisition" href="/opds/v1.2/books/10/file"
              type="application/pdf"/>
      </entry>
    </feed>
    """

    // MARK: Catalogue en OPDS 2.0

    /// Premiere page du catalogue JSON, avec un groupe et un lien suivant.
    static let catalogueJsonPage1 = """
    {
      "metadata": {"title": "Catalogue de test", "numberOfItems": 3},
      "links": [
        {"rel": "self", "href": "/opds/v2/series", "type": "application/opds+json"},
        {"rel": ["next"], "href": "/opds/v2/series?page=1", "type": "application/opds+json"}
      ],
      "navigation": [
        {"href": "/opds/v2/series/berserk", "title": "Berserk", "type": "application/opds+json"},
        {"href": "series/vinland", "title": "Vinland Saga", "type": "application/opds+json"}
      ],
      "groups": [
        {
          "metadata": {"title": "Nouveautes"},
          "navigation": [
            {"href": "/opds/v2/series/yotsuba", "title": "Yotsuba", "type": "application/opds+json"}
          ]
        }
      ]
    }
    """

    /// Seconde et derniere page du catalogue JSON.
    static let catalogueJsonPage2 = """
    {
      "metadata": {"title": "Catalogue de test"},
      "links": [
        {"rel": "self", "href": "/opds/v2/series?page=1", "type": "application/opds+json"}
      ],
      "navigation": [
        {"href": "/opds/v2/series/pluto", "title": "Pluto", "type": "application/opds+json"}
      ]
    }
    """

    /// Les chapitres d une serie, en JSON, sur un seul flux.
    static let serieJson = """
    {
      "metadata": {"title": "Berserk"},
      "links": [
        {"rel": "self", "href": "/opds/v2/series/berserk", "type": "application/opds+json"}
      ],
      "publications": [
        {
          "metadata": {
            "title": "Chapitre 1",
            "identifier": "urn:tsuzuki:livre:1",
            "author": "Kentaro Miura",
            "subject": ["Action", {"name": "Fantasy"}],
            "language": "ja",
            "numberOfPages": 3,
            "published": "2026-01-02T10:00:00Z",
            "description": "Le premier chapitre."
          },
          "links": [
            {
              "rel": "http://opds-spec.org/acquisition",
              "href": "/opds/v2/books/1/file",
              "type": "application/vnd.comicbook+zip"
            },
            {
              "rel": "http://vaemendis.net/opds-pse/stream",
              "href": "/opds/v2/books/1/pages/{pageNumber}",
              "type": "image/jpeg",
              "properties": {"count": 3}
            }
          ],
          "images": [
            {"href": "/opds/v2/books/1/couverture", "type": "image/jpeg"}
          ]
        },
        {
          "metadata": {"title": "Chapitre 2", "author": [{"name": "Kentaro Miura"}]},
          "links": [
            {
              "rel": "http://opds-spec.org/acquisition/open-access",
              "href": "/opds/v2/books/2/file",
              "type": "application/zip"
            }
          ]
        }
      ]
    }
    """

    // MARK: Reponses defectueuses

    /// Un document XML bien forme qui ne decrit aucun flux.
    static let documentSansFlux = """
    <?xml version="1.0" encoding="UTF-8"?>
    <html><body><h1>Authentification requise</h1></body></html>
    """

    /// Un flux Atom coupe en plein milieu d une entree.
    ///
    /// Ce qui precede la cassure reste exploitable, et c est le comportement
    /// attendu : une page de catalogue amputee de sa fin vaut mieux qu une
    /// source muette.
    static let fluxTronque = """
    <?xml version="1.0" encoding="UTF-8"?>
    <feed xmlns="http://www.w3.org/2005/Atom">
      <title>Catalogue de test</title>
      <entry>
        <id>urn:tsuzuki:serie:berserk</id>
        <title>Berserk</title>
        <link rel="subsection" href="/opds/v1.2/series/berserk"
              type="application/atom+xml;profile=opds-catalog"/>
      </entry>
      <entry>
        <id>urn:tsuzuki:serie:vinl
    """
}
