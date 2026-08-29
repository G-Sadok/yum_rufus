import Core
import Foundation
import Sources

//
// DialecteAniList
//
// Le seul des quatre services qui ne parle pas REST. Tout passe par une adresse
// unique, en POST, avec une requete ecrite dans le corps.
//
// Cela change deux choses et deux seulement. Le chemin est toujours vide, et le
// corps porte la question. Le reste, la lecture du compte, le classement des
// resultats et la publication, se lit comme chez les trois autres.
//
// Les documents envoyes sont ecrits en dur et ne prennent aucune valeur par
// interpolation : les valeurs voyagent dans les variables. Une valeur
// interpolee dans un document de requete serait exactement le trou par lequel
// un titre contenant un guillemet casserait la requete, au mieux.
//

/// Le service qui repond a une adresse unique, en GraphQL.
public struct DialecteAniList: DialecteDeSuivi {
    public let service = ServiceDeSuivi.aniList

    public init() {}

    // MARK: Compte

    public func appelDuCompte() -> AppelDeSuivi {
        appel(document: Self.documentDuCompte, variables: [:])
    }

    public func compte(depuis reponse: ReponseHttp) throws -> CompteDeSuivi {
        let recu = try lireOuLever(ReponseDuCompte.self, depuis: reponse)

        return CompteDeSuivi(
            identifiant: String(recu.data.compteConnecte.id),
            pseudonyme: recu.data.compteConnecte.name
        )
    }

    // MARK: Recherche

    public func appelDeRecherche(titre: String) -> AppelDeSuivi {
        appel(document: Self.documentDeRecherche, variables: ["search": .texte(titre)])
    }

    public func series(depuis reponse: ReponseHttp) throws -> [SerieDeSuivi] {
        let recu = try lireOuLever(ReponseDeRecherche.self, depuis: reponse)

        return recu.data.tranche.media.map { media in
            SerieDeSuivi(
                id: String(media.id),
                titre: media.title.principal,
                titresAlternatifs: media.title.autres,
                annee: media.startDate?.year,
                nombreDeChapitres: media.chapters
            )
        }
    }

    // MARK: Publication

    public func appelDePublication(
        _ liaison: LiaisonSuivi,
        compte _: CompteDeSuivi,
        entreeExistante _: String?
    ) throws -> AppelDeSuivi {
        guard let identifiant = Int(liaison.identifiantDistant) else {
            throw ErreurDeSuivi.liaisonAbsente(service: service)
        }

        var variables: [String: ValeurDeVariable] = [
            "mediaId": .entier(identifiant),

            // Le service compte les chapitres en entiers. Un chapitre 12.5,
            // frequent dans les series a bonus, est donc annonce comme 12 :
            // arrondir au superieur declarerait lu un chapitre qui ne l est
            // pas, et le service ne rendrait jamais la difference.
            "progress": .entier(Int(liaison.chapitreVu.rounded(.down))),
            "status": .texte(Self.statut(liaison.statut)),
        ]

        if let note = liaison.note {
            variables["score"] = .decimal(note)
        }

        return appel(document: Self.documentDePublication, variables: variables)
    }

    // MARK: Construction

    /// Un appel GraphQL, toujours en POST sur la racine.
    private func appel(document: String, variables: [String: ValeurDeVariable]) -> AppelDeSuivi {
        let corps = (try? CorpsJson.encoder(RequeteGraphQL(query: document, variables: variables))) ?? Data()

        return AppelDeSuivi(methode: .post, corps: .json(corps))
    }

    /// Statut tel que le service le nomme.
    ///
    /// La relecture existe chez ce service, ce qui n est pas le cas des trois
    /// autres. Elle est donc conservee telle quelle plutot que ramenee a la
    /// lecture en cours.
    static func statut(_ statut: StatutDeSuivi) -> String {
        switch statut {
        case .enLecture: "CURRENT"
        case .termine: "COMPLETED"
        case .enPause: "PAUSED"
        case .abandonne: "DROPPED"
        case .prevu: "PLANNING"
        case .relecture: "REPEATING"
        }
    }

    private static let documentDuCompte = "query { Viewer { id name } }"

    private static let documentDeRecherche = """
    query ($search: String) {
      Page(perPage: 10) {
        media(search: $search, type: MANGA) {
          id
          title { romaji english native }
          startDate { year }
          chapters
        }
      }
    }
    """

    private static let documentDePublication = """
    mutation ($mediaId: Int, $progress: Int, $status: MediaListStatus, $score: Float) {
      SaveMediaListEntry(mediaId: $mediaId, progress: $progress, status: $status, score: $score) {
        id
        progress
      }
    }
    """
}

// MARK: Corps envoye

/// Une requete GraphQL, document et variables.
private struct RequeteGraphQL: Encodable {
    let query: String
    let variables: [String: ValeurDeVariable]
}

/// Une variable de requete, dans les trois formes que le service recoit.
///
/// L enumeration remplace un dictionnaire de valeurs quelconques, que Swift ne
/// sait pas encoder sans transtypage. Elle a un second interet : une variable
/// d un type que le service n attend pas ne compile pas.
private enum ValeurDeVariable: Encodable, Hashable {
    case texte(String)
    case entier(Int)
    case decimal(Double)

    func encode(to encodeur: Encoder) throws {
        var conteneur = encodeur.singleValueContainer()

        switch self {
        case let .texte(valeur): try conteneur.encode(valeur)
        case let .entier(valeur): try conteneur.encode(valeur)
        case let .decimal(valeur): try conteneur.encode(valeur)
        }
    }
}

// MARK: Corps recu

/// Reponse a la question du compte connecte.
private struct ReponseDuCompte: Decodable {
    let data: Donnees

    struct Donnees: Decodable {
        /// Le service nomme ce champ avec une majuscule, ce que le style du
        /// projet n accepte pas comme identifiant. La cle de codage fait la
        /// traduction, comme pour le point d echange de jeton.
        let compteConnecte: Compte

        enum CodingKeys: String, CodingKey {
            case compteConnecte = "Viewer"
        }

        struct Compte: Decodable {
            let id: Int
            let name: String
        }
    }
}

/// Reponse a une recherche de series.
private struct ReponseDeRecherche: Decodable {
    let data: Donnees

    struct Donnees: Decodable {
        let tranche: Tranche

        enum CodingKeys: String, CodingKey {
            case tranche = "Page"
        }

        struct Tranche: Decodable {
            let media: [Media]
        }
    }

    struct Media: Decodable {
        let id: Int
        let title: Titres
        let startDate: DateDeParution?
        let chapters: Int?

        struct Titres: Decodable {
            let romaji: String?
            let english: String?
            let native: String?

            /// Titre principal, le premier renseigne des trois.
            ///
            /// La romanisation passe devant l anglais, qui passe devant le
            /// titre original. C est l ordre dans lequel une bibliotheque
            /// francophone nomme ses dossiers, et donc celui qui donne le
            /// meilleur rapprochement.
            var principal: String {
                romaji ?? english ?? native ?? ""
            }

            /// Les autres titres publies, sans le principal ni les vides.
            var autres: [String] {
                [romaji, english, native]
                    .compactMap(\.self)
                    .filter { $0.isEmpty == false && $0 != principal }
            }
        }

        /// Le nom evite `Date` : un type imbrique de ce nom masquerait celui de
        /// Foundation dans toute la portee du fichier.
        struct DateDeParution: Decodable {
            let year: Int?
        }
    }
}
