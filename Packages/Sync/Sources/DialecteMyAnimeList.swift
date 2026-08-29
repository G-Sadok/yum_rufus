import Core
import Foundation
import Sources

//
// DialecteMyAnimeList
//
// Un service REST classique, a deux details pres.
//
// Le premier : la publication n envoie pas de JSON mais un formulaire. C est la
// raison pour laquelle `AppelDeSuivi` porte un corps a trois formes plutot
// qu un simple document JSON.
//
// Le second : la liste des champs rendus par une recherche est vide par defaut.
// Un appel sans `fields` rend des titres et rien d autre, ni annee ni nombre de
// chapitres, et le rapprochement perd les deux signaux qui departagent une
// serie de son remake. Les champs sont donc demandes explicitement.
//

/// Le service REST dont les ecritures passent par un formulaire.
public struct DialecteMyAnimeList: DialecteDeSuivi {
    public let service = ServiceDeSuivi.myAnimeList

    public init() {}

    // MARK: Compte

    public func appelDuCompte() -> AppelDeSuivi {
        AppelDeSuivi(chemin: "users/@me")
    }

    public func compte(depuis reponse: ReponseHttp) throws -> CompteDeSuivi {
        let recu = try lireOuLever(ReponseDuCompte.self, depuis: reponse)

        return CompteDeSuivi(identifiant: String(recu.id), pseudonyme: recu.name)
    }

    // MARK: Recherche

    public func appelDeRecherche(titre: String) -> AppelDeSuivi {
        AppelDeSuivi(
            chemin: "manga",
            parametres: [
                URLQueryItem(name: "q", value: titre),
                URLQueryItem(name: "limit", value: "10"),
                URLQueryItem(name: "fields", value: "alternative_titles,start_date,num_chapters"),
            ]
        )
    }

    public func series(depuis reponse: ReponseHttp) throws -> [SerieDeSuivi] {
        let recu = try lireOuLever(ReponseDeRecherche.self, depuis: reponse)

        return recu.data.map { entree in
            SerieDeSuivi(
                id: String(entree.node.id),
                titre: entree.node.titre,
                titresAlternatifs: entree.node.titresAlternatifs?.tous ?? [],
                annee: entree.node.annee,
                nombreDeChapitres: entree.node.nombreDeChapitres
            )
        }
    }

    // MARK: Publication

    public func appelDePublication(
        _ liaison: LiaisonSuivi,
        compte _: CompteDeSuivi,
        entreeExistante _: String?
    ) throws -> AppelDeSuivi {
        guard liaison.identifiantDistant.isEmpty == false else {
            throw ErreurDeSuivi.liaisonAbsente(service: service)
        }

        var champs = [
            URLQueryItem(name: "num_chapters_read", value: String(Int(liaison.chapitreVu.rounded(.down)))),
            URLQueryItem(name: "status", value: Self.statut(liaison.statut)),
        ]

        if let note = liaison.note {
            champs.append(URLQueryItem(name: "score", value: String(Int(note.rounded()))))
        }

        return AppelDeSuivi(
            chemin: "manga/\(liaison.identifiantDistant)/my_list_status",
            methode: .patch,
            corps: .formulaire(champs)
        )
    }

    /// Statut tel que le service le nomme.
    ///
    /// La relecture est ramenee a la lecture en cours : le service la porte
    /// dans un drapeau separe et non dans le statut, et inventer une valeur
    /// qu il ne connait pas ferait refuser toute la mise a jour.
    static func statut(_ statut: StatutDeSuivi) -> String {
        switch statut {
        case .enLecture, .relecture: "reading"
        case .termine: "completed"
        case .enPause: "on_hold"
        case .abandonne: "dropped"
        case .prevu: "plan_to_read"
        }
    }
}

// MARK: Corps recu

private struct ReponseDuCompte: Decodable {
    let id: Int
    let name: String
}

private struct ReponseDeRecherche: Decodable {
    let data: [Entree]

    struct Entree: Decodable {
        let node: Fiche
    }

    struct Fiche: Decodable {
        let id: Int
        let titre: String
        let titresAlternatifs: TitresAlternatifs?
        let dateDeParution: String?
        let nombreDeChapitres: Int?

        /// Annee lue au debut de la date de parution.
        ///
        /// Le service ecrit la date en entier quand il la connait, et parfois
        /// l annee seule. Prendre les quatre premiers caracteres couvre les
        /// deux formes sans imposer un analyseur de date pour un entier.
        var annee: Int? {
            dateDeParution.flatMap { Int($0.prefix(4)) }
        }

        enum CodingKeys: String, CodingKey {
            case id
            case titre = "title"
            case titresAlternatifs = "alternative_titles"
            case dateDeParution = "start_date"
            case nombreDeChapitres = "num_chapters"
        }
    }

    struct TitresAlternatifs: Decodable {
        let synonymes: [String]?
        let anglais: String?
        let japonais: String?

        var tous: [String] {
            ((synonymes ?? []) + [anglais, japonais].compactMap(\.self)).filter { $0.isEmpty == false }
        }

        enum CodingKeys: String, CodingKey {
            case synonymes = "synonyms"
            case anglais = "en"
            case japonais = "ja"
        }
    }
}
