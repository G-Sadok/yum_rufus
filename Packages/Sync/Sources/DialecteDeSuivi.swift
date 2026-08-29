import Core
import Foundation
import Sources

//
// DialecteDeSuivi
//
// Ce qui change d un service a l autre, isole de ce qui ne change pas.
//
// Les quatre services font les memes trois choses : dire quel compte est
// connecte, chercher une serie, publier une progression. Ils ne les font pas de
// la meme facon. L un parle GraphQL sur une adresse unique, deux parlent REST
// avec des noms de champs differents, le quatrieme range ses listes par
// numero. Ecrire quatre clients complets aurait donne quatre traitements du
// jeton refuse, du corps tronque et de la reponse vide, alors qu il n y a
// aucune raison qu ils different.
//
// Le dialecte ne parle donc a personne. Il decrit un appel et relit une
// reponse. C est `ClientDeSuivi` qui envoie, qui pose le jeton, qui le
// renouvelle et qui verifie ce qui revient, une seule fois pour les quatre.
//
// Deux services demandent une lecture avant l ecriture, parce que leur mise a
// jour porte sur une entree de bibliotheque et non sur la serie. Le protocole
// le prevoit avec un appel prealable facultatif, plutot que par un cas
// particulier cache dans le client : un service qui n en a pas besoin rend nul,
// et rien d autre ne change.
//

/// Corps d une requete adressee a un service de suivi.
public enum CorpsDAppel: Sendable, Hashable {
    /// Aucun corps.
    case aucun

    /// Document JSON, avec son type de contenu.
    case json(Data)

    /// Formulaire encode dans l adresse, ce que les points d echange de jeton
    /// exigent et ce qu un des quatre services attend aussi pour ses ecritures.
    case formulaire([URLQueryItem])
}

/// Une requete a envoyer a un service de suivi.
public struct AppelDeSuivi: Sendable, Hashable {
    /// Chemin ajoute a la racine de l API du service.
    public let chemin: String

    /// Parametres de l adresse.
    public let parametres: [URLQueryItem]

    /// Verbe HTTP.
    public let methode: MethodeHttp

    /// Corps envoye.
    public let corps: CorpsDAppel

    public init(
        chemin: String = "",
        parametres: [URLQueryItem] = [],
        methode: MethodeHttp = .get,
        corps: CorpsDAppel = .aucun
    ) {
        self.chemin = chemin
        self.parametres = parametres
        self.methode = methode
        self.corps = corps
    }
}

/// Ce qu un service de suivi comprend, service par service.
public protocol DialecteDeSuivi: Sendable {
    /// Service que ce dialecte sait parler.
    var service: ServiceDeSuivi { get }

    /// Appel qui demande quel compte est connecte.
    func appelDuCompte() -> AppelDeSuivi

    /// Compte lu dans la reponse.
    func compte(depuis reponse: ReponseHttp) throws -> CompteDeSuivi

    /// Appel qui cherche une serie par son titre.
    func appelDeRecherche(titre: String) -> AppelDeSuivi

    /// Entrees de catalogue lues dans la reponse.
    func series(depuis reponse: ReponseHttp) throws -> [SerieDeSuivi]

    /// Appel qui retrouve l entree de bibliotheque deja posee pour cette serie.
    ///
    /// Rend nul quand le service ecrit directement sur la serie, ce qui est le
    /// cas de deux services sur quatre.
    func appelDeLEntreeExistante(_ liaison: LiaisonSuivi, compte: CompteDeSuivi) -> AppelDeSuivi?

    /// Identifiant de l entree existante, nul quand le service n en a aucune.
    func entreeExistante(depuis reponse: ReponseHttp) throws -> String?

    /// Appel qui publie la progression.
    ///
    /// - Parameter entreeExistante: identifiant rendu par l appel prealable,
    ///   nul quand il n y en avait pas ou que le service n en demande pas.
    func appelDePublication(
        _ liaison: LiaisonSuivi,
        compte: CompteDeSuivi,
        entreeExistante: String?
    ) throws -> AppelDeSuivi

    /// Appel qui echange un compte et un mot de passe contre un jeton.
    ///
    /// Rend nul pour les services qui passent par le navigateur.
    func appelDeConnexionParIdentifiants(compte: String, motDePasse: String) -> AppelDeSuivi?

    /// Jeton lu dans la reponse du point d echange.
    func jeton(depuis reponse: ReponseHttp, le maintenant: Date) throws -> IdentifiantsDeSource
}

extension DialecteDeSuivi {
    /// Aucun appel prealable, le cas des services qui ecrivent sur la serie.
    public func appelDeLEntreeExistante(_: LiaisonSuivi, compte _: CompteDeSuivi) -> AppelDeSuivi? {
        nil
    }

    public func entreeExistante(depuis _: ReponseHttp) throws -> String? {
        nil
    }

    /// Aucune connexion par identifiants, le cas des trois services OAuth.
    public func appelDeConnexionParIdentifiants(compte _: String, motDePasse _: String) -> AppelDeSuivi? {
        nil
    }

    /// Lecture du jeton d un point d echange OAuth 2.
    ///
    /// Les trois services OAuth repondent la meme chose, parce que la norme le
    /// dit. Le seul point ou ils different est l echeance : l un l annonce en
    /// secondes, l autre pas du tout, et un jeton sans echeance est employe
    /// jusqu au premier refus.
    public func jeton(depuis reponse: ReponseHttp, le maintenant: Date) throws -> IdentifiantsDeSource {
        let recu = try lireOuLever(ReponseDeJetonOAuth.self, depuis: reponse)

        guard recu.acces.isEmpty == false else {
            throw ErreurDeSuivi.reponseIllisible(service: service)
        }

        return .jeton(
            acces: recu.acces,
            rafraichissement: recu.rafraichissement,
            expiration: recu.dureeEnSecondes.map { maintenant.addingTimeInterval(TimeInterval($0)) }
        )
    }

    /// Decode un corps deja valide, en traduisant l echec dans le domaine des
    /// suivis.
    ///
    /// `ClientHttp.decoder` distingue deja le corps vide du corps illisible,
    /// et c est sa distinction qui compte pour le diagnostic. Elle est ramenee
    /// ici a une seule erreur de suivi, parce qu une reponse vide et une
    /// reponse illisible se reparent pareil du point de vue de l utilisateur :
    /// il n y a rien a corriger, il faut reessayer.
    public func lireOuLever<Valeur: Decodable>(_ type: Valeur.Type, depuis reponse: ReponseHttp) throws -> Valeur {
        do {
            return try ClientHttp.decoder(type, depuis: reponse)
        } catch {
            throw ErreurDeSuivi.reponseIllisible(service: service)
        }
    }
}

/// Reponse d un point d echange de jeton OAuth 2.
///
/// Les champs portent les noms du domaine et non ceux du fil : la norme ecrit
/// `access_token`, que le style du projet n accepte pas comme identifiant, et
/// les cles de codage font la traduction au seul endroit ou elle a un sens.
struct ReponseDeJetonOAuth: Decodable {
    let acces: String
    let rafraichissement: String?
    let dureeEnSecondes: Int?

    enum CodingKeys: String, CodingKey {
        case acces = "access_token"
        case rafraichissement = "refresh_token"
        case dureeEnSecondes = "expires_in"
    }
}

/// Corps JSON d une requete, encode une fois pour toutes.
///
/// L encodeur trie les cles. Sans cela, deux executions produiraient deux
/// corps differents pour le meme appel, et un test qui compare le corps envoye
/// echouerait une fois sur deux sans que rien n ait change.
enum CorpsJson {
    static func encoder(_ valeur: some Encodable) throws -> Data {
        let encodeur = JSONEncoder()
        encodeur.outputFormatting = [.sortedKeys]

        return try encodeur.encode(valeur)
    }
}
