import Core
import Foundation
import Sources

//
// DialecteMangaUpdates
//
// Le quatrieme service, celui que le tableau de la section 9 marque simplement
// connexion, sans OAuth.
//
// La difference se voit des la premiere ligne : la connexion presente un compte
// et un mot de passe a une adresse de l API, qui rend un jeton de session. Ce
// jeton se pose ensuite comme les trois autres, dans le meme entete. Tout ce
// qui suit la connexion est donc identique, et c est pour cela que la nature de
// connexion est une propriete du service et non un client separe.
//
// Le mot de passe ne survit pas a l appel. Il part une fois, dans le corps de
// la requete de connexion, et n est jamais range : seul le jeton rendu entre
// dans le trousseau. Une application qui garde le mot de passe pour pouvoir se
// reconnecter toute seule garde un secret qu elle n a plus aucune raison de
// detenir.
//

/// Le service qui se connecte par compte et mot de passe.
public struct DialecteMangaUpdates: DialecteDeSuivi {
    public let service = ServiceDeSuivi.mangaUpdates

    public init() {}

    // MARK: Connexion

    public func appelDeConnexionParIdentifiants(compte: String, motDePasse: String) -> AppelDeSuivi? {
        let corps = (try? CorpsJson.encoder(DemandeDeConnexion(compte: compte, motDePasse: motDePasse))) ?? Data()

        return AppelDeSuivi(chemin: "account/login", methode: .put, corps: .json(corps))
    }

    public func jeton(depuis reponse: ReponseHttp, le _: Date) throws -> IdentifiantsDeSource {
        let recu = try lireOuLever(ReponseDeConnexion.self, depuis: reponse)

        guard recu.context.jeton.isEmpty == false else {
            throw ErreurDeSuivi.reponseIllisible(service: service)
        }

        // Le service n annonce aucune echeance et n emet pas de jeton de
        // rafraichissement. Le jeton est donc employe jusqu au premier refus,
        // qui renvoie l utilisateur vers une nouvelle connexion.
        return .jeton(acces: recu.context.jeton)
    }

    // MARK: Compte

    public func appelDuCompte() -> AppelDeSuivi {
        AppelDeSuivi(chemin: "account/profile")
    }

    public func compte(depuis reponse: ReponseHttp) throws -> CompteDeSuivi {
        let recu = try lireOuLever(ProfilDeCompte.self, depuis: reponse)

        return CompteDeSuivi(identifiant: String(recu.identifiant), pseudonyme: recu.pseudonyme)
    }

    // MARK: Recherche

    public func appelDeRecherche(titre: String) -> AppelDeSuivi {
        let corps = (try? CorpsJson.encoder(DemandeDeRecherche(search: titre, perpage: 10))) ?? Data()

        return AppelDeSuivi(chemin: "series/search", methode: .post, corps: .json(corps))
    }

    public func series(depuis reponse: ReponseHttp) throws -> [SerieDeSuivi] {
        let recu = try lireOuLever(ReponseDeRecherche.self, depuis: reponse)

        return recu.results.map { resultat in
            SerieDeSuivi(
                id: String(resultat.record.identifiant),
                titre: resultat.record.titre,
                titresAlternatifs: [],
                annee: resultat.record.annee.flatMap { Int($0.prefix(4)) },
                nombreDeChapitres: nil
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

        let corps = try CorpsJson.encoder([
            MiseAJourDeListe(
                series: ReferenceDeSerie(identifiant: identifiant),
                listeVisee: Self.liste(liaison.statut),
                status: AvancementDeListe(chapter: Int(liaison.chapitreVu.rounded(.down)))
            ),
        ])

        return AppelDeSuivi(chemin: "lists/series/update", methode: .post, corps: .json(corps))
    }

    /// Numero de liste correspondant au statut.
    ///
    /// Le service ne nomme pas ses listes, il les numerote, et l ordre de ses
    /// numeros n a rien a voir avec l ordre de notre enumeration. La table est
    /// donc explicite. La relecture rejoint la lecture en cours, faute de liste
    /// dediee.
    static func liste(_ statut: StatutDeSuivi) -> Int {
        switch statut {
        case .enLecture, .relecture: 0
        case .prevu: 1
        case .termine: 2
        case .abandonne: 3
        case .enPause: 4
        }
    }
}

// MARK: Corps envoye

private struct DemandeDeConnexion: Encodable {
    let compte: String
    let motDePasse: String

    enum CodingKeys: String, CodingKey {
        case compte = "username"
        case motDePasse = "password"
    }
}

private struct DemandeDeRecherche: Encodable {
    let search: String
    let perpage: Int
}

private struct MiseAJourDeListe: Encodable {
    let series: ReferenceDeSerie
    let listeVisee: Int
    let status: AvancementDeListe

    enum CodingKeys: String, CodingKey {
        case series
        case listeVisee = "list_id"
        case status
    }
}

private struct ReferenceDeSerie: Encodable {
    let identifiant: Int

    enum CodingKeys: String, CodingKey {
        case identifiant = "series_id"
    }
}

private struct AvancementDeListe: Encodable {
    let chapter: Int
}

// MARK: Corps recu

private struct ReponseDeConnexion: Decodable {
    let context: Contexte

    struct Contexte: Decodable {
        let jeton: String

        enum CodingKeys: String, CodingKey {
            case jeton = "session_token"
        }
    }
}

private struct ProfilDeCompte: Decodable {
    let identifiant: Int
    let pseudonyme: String

    enum CodingKeys: String, CodingKey {
        case identifiant = "user_id"
        case pseudonyme = "username"
    }
}

private struct ReponseDeRecherche: Decodable {
    let results: [Resultat]

    struct Resultat: Decodable {
        let record: Fiche
    }

    struct Fiche: Decodable {
        let identifiant: Int
        let titre: String
        let annee: String?

        enum CodingKeys: String, CodingKey {
            case identifiant = "series_id"
            case titre = "title"
            case annee = "year"
        }
    }
}
