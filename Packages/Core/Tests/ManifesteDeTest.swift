import CryptoKit
import Foundation
@testable import Core

//
// ManifesteDeTest
//
// Le manifeste de reference des tests d extensions, et de quoi le signer.
//
// Il emploie **toutes** les cles du langage declaratif, et c est la raison de sa
// taille. La lecture stricte refuse le paquet des la premiere cle qu elle ne
// connait pas : un manifeste de reference qui n en emploierait que la moitie
// laisserait passer sans bruit une cle oubliee dans `MotsClesDuManifeste`, et
// le refus n apparaitrait que chez un utilisateur, sur un manifeste reel.
//

enum ManifesteDeTest {
    /// Le manifeste complet, sous sa forme JSON.
    static let json = """
    {
      "format": 1,
      "identifiant": "exemple.catalogue",
      "nom": "Catalogue Exemple",
      "version": "1.4",
      "langue": "fr",
      "capacites": ["recherche", "pagination", "plusieursLangues", "telechargement"],
      "domaines": ["api.exemple.net", "*.images.exemple.net"],
      "icone": "icone.png",
      "regles": {
        "adresseDeBase": "https://api.exemple.net",
        "pageDeDepart": 1,
        "formatDeDate": "yyyy-MM-dd",
        "recherche": {
          "requete": {
            "chemin": "/recherche",
            "parametres": [
              { "nom": "q", "valeur": "{texteRecherche}" },
              { "nom": "page", "valeur": "{page}" },
              { "nom": "lang", "valeur": "{langue}" }
            ],
            "format": "json"
          },
          "elements": { "json": "$.results[*]" },
          "champs": {
            "identifiant": { "json": "$.id" },
            "titre": { "json": "$.title" },
            "auteurs": { "json": "$.authors[*]" },
            "resume": { "json": "$.summary" },
            "genres": { "json": "$.genres[*]" },
            "statut": { "json": "$.status" },
            "langue": { "json": "$.lang" },
            "couverture": { "json": "$.cover" },
            "nombreChapitres": { "json": "$.chapterCount" }
          },
          "pagination": { "listePleine": 20 }
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
              "pagination": { "lienSuivant": { "json": "$.next" } }
            }
          },
          {
            "section": "populaires",
            "regle": {
              "requete": { "chemin": "/populaires", "format": "json" },
              "elements": { "json": "$.results[*]" },
              "champs": {
                "identifiant": { "json": "$.id" },
                "titre": { "json": "$.title" }
              },
              "pagination": { "totalAnnonce": { "json": "$.total" }, "tailleDePage": 20 }
            }
          }
        ],
        "details": {
          "requete": { "chemin": "/series/{identifiantSerie}", "format": "json" },
          "element": { "json": "$.serie" },
          "champs": {
            "identifiant": { "json": "$.id" },
            "titre": { "json": "$.title" }
          }
        },
        "chapitres": {
          "requete": { "chemin": "/series/{identifiantSerie}/chapitres", "format": "json" },
          "elements": { "json": "$.items[*]" },
          "champs": {
            "identifiant": { "json": "$.id" },
            "numero": { "json": "$.number" },
            "titre": { "json": "$.title" },
            "langue": { "json": "$.lang" },
            "datePublication": { "json": "$.published" },
            "nombrePages": { "json": "$.pageCount" }
          },
          "ordreInverse": true
        },
        "pages": {
          "requete": { "chemin": "/chapitres/{identifiantChapitre}/pages", "format": "html" },
          "elements": { "html": "div.page" },
          "champs": {
            "emplacement": { "html": "img", "attribut": "src" }
          }
        }
      }
    }
    """

    /// Les octets du manifeste complet.
    static var donnees: Data {
        Data(json.utf8)
    }

    /// Le manifeste complet, deja lu.
    static func manifeste() throws -> ManifesteDExtension {
        try ManifesteDExtension.lire(donnees)
    }

    /// Le manifeste complet, avec une entree ajoutee a la racine.
    ///
    /// Sert a jouer un paquet qui essaie de faire passer autre chose que des
    /// regles declaratives.
    static func avec(entree: String, valeur: String) -> Data {
        let ouverture = json.firstIndex(of: "{")

        guard let ouverture else {
            return donnees
        }

        var modifie = json
        modifie.insert(contentsOf: "\n  \"\(entree)\": \(valeur),", at: json.index(after: ouverture))

        return Data(modifie.utf8)
    }

    /// Le manifeste complet, avec une valeur remplacee par une autre.
    static func enRemplacant(_ ancienne: String, par nouvelle: String) -> Data {
        Data(json.replacingOccurrences(of: ancienne, with: nouvelle).utf8)
    }
}

//
// SignatureDeTest
//
// Un signataire jetable. La cle est produite a chaque appel : figer une cle
// privee dans le depot serait un secret en clair, ce que le controle 8 refuse
// a juste titre, et cette cle la ne protege rien puisqu elle vit le temps d un
// test.
//

struct SignataireDeTest {
    let cle: Curve25519.Signing.PrivateKey

    init() {
        cle = Curve25519.Signing.PrivateKey()
    }

    /// La cle publique, sous la forme que le trousseau conserve.
    var clePublique: Data {
        cle.publicKey.rawRepresentation
    }

    /// Le trousseau qui fait confiance a ce signataire, et a lui seul.
    var trousseau: TrousseauDeClesDePublication {
        TrousseauDeClesDePublication(cles: [clePublique])
    }

    /// Signe des octets de manifeste et rend l enveloppe du paquet.
    func enveloppe(de manifeste: Data) throws -> Data {
        let signature = try cle.signature(for: manifeste)

        return try PaquetDExtensionSigne(
            manifeste: manifeste,
            signature: signature,
            clePublique: clePublique
        ).enveloppe()
    }
}
