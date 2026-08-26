import Core
import Foundation
@testable import Sources

//
// ReponsesFigeesDeJellyfin
//
// Les reponses du serveur Jellyfin, recopiees dans la forme qu il rend
// reellement et figees ici une fois pour toutes.
//
// Comme celles de Komga et de Kavita, elles ne sont pas propres, et leurs
// defauts sont ceux d un serveur reel.
//
// Le serveur annonce trois bibliotheques, dont une seule contient des livres.
// Les deux autres sont la pour etre ecartees : c est le critere du tableau 4.2,
// et un jeu de reponses qui ne contiendrait que des livres ne prouverait rien.
//
// La liste des series porte un film au milieu des dossiers, la liste des
// chapitres porte un episode au milieu des livres. Les deux viennent du meme
// accident, une bibliotheque mal rangee par l utilisateur ou un serveur d une
// version voisine qui ignore le filtre demande.
//
// Un dossier n a pas de couverture, un genre est vide, un livre recopie son
// numero dans son nom, un autre ne porte aucun numero et laisse son nom le dire,
// un troisieme ne connait aucune date de parution et n a que sa date d ajout.
//
// Les dates sont ecrites avec les sept decimales de seconde de la plateforme du
// serveur, et non les trois d usage. C est ainsi qu il les serialise.
//

/// Le jeu de reponses de reference du serveur Jellyfin de test.
enum ReponsesFigeesDeJellyfin {
    /// Adresse du serveur de test.
    static let adresse = URL(string: "https://jellyfin.exemple.test")

    /// Adresse d un serveur de reseau local, non chiffree.
    static let adresseEnClair = URL(string: "http://192.168.1.42:8096")

    // MARK: Identifiants

    static let bibliothequeDeLivres = "bib-livres"
    static let bibliothequeDeFilms = "bib-films"
    static let bibliothequeDeMusique = "bib-musique"

    static let identifiantDeSerie = "serie-berserk"
    static let identifiantDuPremierChapitre = "livre-401"
    static let identifiantDuChapitreSansNumero = "livre-403"

    /// Les pages rangees dans le conteneur du premier chapitre.
    static let pagesDuPremierChapitre = ["001.jpg", "002.jpg", "003.jpg"]

    // MARK: Bibliotheques

    /// Les bibliotheques du serveur, dont une seule contient des livres.
    static let bibliotheques = """
    {
      "Items": [
        {
          "Id": "\(bibliothequeDeFilms)",
          "Name": "Films",
          "Type": "CollectionFolder",
          "CollectionType": "movies"
        },
        {
          "Id": "\(bibliothequeDeLivres)",
          "Name": "Livres",
          "Type": "CollectionFolder",
          "CollectionType": "books"
        },
        {
          "Id": "\(bibliothequeDeMusique)",
          "Name": "Musique",
          "Type": "CollectionFolder",
          "CollectionType": "music"
        }
      ],
      "TotalRecordCount": 3,
      "StartIndex": 0
    }
    """

    /// Un serveur dont aucune bibliotheque ne contient de livre.
    static let bibliothequesSansLivre = """
    {
      "Items": [
        {
          "Id": "\(bibliothequeDeFilms)",
          "Name": "Films",
          "Type": "CollectionFolder",
          "CollectionType": "movies"
        }
      ],
      "TotalRecordCount": 1,
      "StartIndex": 0
    }
    """

    // MARK: Catalogue

    /// Premiere tranche du catalogue, avec une suite annoncee par le total.
    static let premiereTrancheDeSeries = """
    {
      "Items": [
        {
          "Id": "\(identifiantDeSerie)",
          "Name": "Berserk",
          "Type": "Folder",
          "ChildCount": 3,
          "ImageTags": {"Primary": "etiquette-berserk"}
        },
        {
          "Id": "serie-vagabond",
          "Name": "Vagabond",
          "Type": "Folder",
          "ChildCount": 1,
          "ImageTags": {}
        }
      ],
      "TotalRecordCount": 3,
      "StartIndex": 0
    }
    """

    /// Seconde tranche du catalogue, la derniere.
    static let secondeTrancheDeSeries = """
    {
      "Items": [
        {
          "Id": "serie-pluto",
          "Name": "Pluto",
          "Type": "Folder",
          "ChildCount": 8,
          "ImageTags": {"Primary": "etiquette-pluto"}
        }
      ],
      "TotalRecordCount": 3,
      "StartIndex": 2
    }
    """

    /// Une tranche ou le serveur a laisse passer un film malgre le filtre.
    static let trancheDeSeriesAvecIntrus = """
    {
      "Items": [
        {
          "Id": "\(identifiantDeSerie)",
          "Name": "Berserk",
          "Type": "Folder",
          "ChildCount": 3,
          "ImageTags": {"Primary": "etiquette-berserk"}
        },
        {
          "Id": "film-egare",
          "Name": "Un film egare",
          "Type": "Movie",
          "ImageTags": {"Primary": "etiquette-film"}
        }
      ],
      "TotalRecordCount": 2,
      "StartIndex": 0
    }
    """

    /// La fiche d une serie, demandee par son identifiant.
    ///
    /// Un genre est vide, et l afficher ferait une puce sans texte sur la fiche.
    static let detailDeSerie = """
    {
      "Items": [
        {
          "Id": "\(identifiantDeSerie)",
          "Name": "Berserk",
          "Type": "Folder",
          "Overview": "Un mercenaire marque poursuit ceux qui l ont trahi.",
          "Genres": ["Seinen", "Dark Fantasy", "   "],
          "ChildCount": 3,
          "ImageTags": {"Primary": "etiquette-berserk"}
        }
      ],
      "TotalRecordCount": 1,
      "StartIndex": 0
    }
    """

    /// La reponse du serveur quand aucun element ne porte cet identifiant.
    static let aucunElement = """
    {"Items": [], "TotalRecordCount": 0, "StartIndex": 0}
    """

    // MARK: Chapitres

    /// Les chapitres de la serie, avec un episode video au milieu.
    static let chapitresDeLaSerie = """
    {
      "Items": [
        {
          "Id": "\(identifiantDuPremierChapitre)",
          "Name": "Berserk Vol.1",
          "Type": "Book",
          "IndexNumber": 1,
          "Container": "cbz",
          "Path": "/livres/berserk/vol1.cbz",
          "PremiereDate": "1990-11-26T00:00:00.0000000Z",
          "DateCreated": "2024-05-04T00:00:00.0000000Z"
        },
        {
          "Id": "livre-402",
          "Name": "2",
          "Type": "Book",
          "IndexNumber": 2,
          "Container": "cbz",
          "Path": "/livres/berserk/vol2.cbz",
          "PremiereDate": "1991-03-08T00:00:00.0000000Z"
        },
        {
          "Id": "episode-egare",
          "Name": "Un episode egare",
          "Type": "Episode",
          "IndexNumber": 7,
          "Container": "mkv",
          "Path": "/films/serie/s01e07.mkv"
        },
        {
          "Id": "\(identifiantDuChapitreSansNumero)",
          "Name": "Berserk Chapitre 3",
          "Type": "Book",
          "Path": "/livres/berserk/ch3.cbz",
          "DateCreated": "2024-05-04T00:00:00.0000000Z"
        }
      ],
      "TotalRecordCount": 4,
      "StartIndex": 0
    }
    """

    /// La fiche du premier chapitre, demandee par son identifiant.
    static let detailDuPremierChapitre = """
    {
      "Items": [
        {
          "Id": "\(identifiantDuPremierChapitre)",
          "Name": "Berserk Vol.1",
          "Type": "Book",
          "IndexNumber": 1,
          "Container": "cbz",
          "Path": "/livres/berserk/vol1.cbz"
        }
      ],
      "TotalRecordCount": 1,
      "StartIndex": 0
    }
    """

    /// Un livre dont le serveur ne nomme ni le format ni le chemin.
    static let detailSansFormat = """
    {
      "Items": [
        {
          "Id": "\(identifiantDuPremierChapitre)",
          "Name": "Berserk Vol.1",
          "Type": "Book",
          "IndexNumber": 1
        }
      ],
      "TotalRecordCount": 1,
      "StartIndex": 0
    }
    """

    // MARK: Reponses cassees

    /// Une reponse qui n est pas du JSON, celle d un proxy qui sert une page web.
    static let malformee = """
    <!DOCTYPE html><html><head><title>502 Bad Gateway</title></head><body></body></html>
    """

    /// Une reponse de service, acceptee mais qui ne decrit aucune tranche.
    ///
    /// C est ce que rend une adresse qui pointe vers un autre service.
    static let etrangere = """
    {"status": "ok", "service": "autre chose que Jellyfin"}
    """

    /// Un catalogue coupe en plein milieu.
    static let troncature = """
    {"Items": [{"Id": "serie-ber
    """
}
