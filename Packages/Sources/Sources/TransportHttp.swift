import Core
import Foundation

//
// TransportHttp
//
// La seule couche du projet qui touche reellement le reseau, et la couture par
// laquelle les tests la remplacent.
//
// Elle existe pour une raison precise, exigee par la strategie de test : une
// reponse figee par source, plus une reponse malformee, plus une reponse vide,
// plus une reponse tronquee. Aucune de ces quatre ne se fabrique avec
// `URLSession` sans lancer un serveur, et un test qui lance un serveur mesure
// le serveur autant que le code. Le protocole rend les quatre triviales.
//
// La reponse est reduite a trois champs, code, entetes et octets, plutot que de
// rendre `HTTPURLResponse`. Ce type ne se construit pas sans URL, ses entetes se
// lisent dans un dictionnaire non type, et un double de test devrait en
// fabriquer un pour chaque cas. Trois champs se comparent et se figent.
//

/// Verbe HTTP, limite a ceux que les sources du projet emploient.
public enum MethodeHttp: String, Sendable, Hashable {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case delete = "DELETE"
}

/// Ce qu un serveur a repondu, reduit a ce dont les sources ont besoin.
public struct ReponseHttp: Sendable, Hashable {
    /// Code de statut HTTP.
    public let code: Int

    /// Entetes, dont les noms sont ramenes en minuscules.
    ///
    /// La norme dit que les noms d entetes ne tiennent pas compte de la casse,
    /// et les serveurs en profitent : Komga envoie `Content-Length`, un proxy
    /// place devant lui peut envoyer `content-length`. Normaliser a la lecture
    /// evite que la recherche d un entete depende du chemin qu a pris la
    /// reponse.
    public let entetes: [String: String]

    public let corps: Data

    public init(code: Int, entetes: [String: String] = [:], corps: Data = Data()) {
        self.code = code
        self.entetes = entetes.reduce(into: [:]) { table, entete in
            table[entete.key.lowercased()] = entete.value
        }
        self.corps = corps
    }

    /// Valeur d un entete, quelle que soit la casse sous laquelle il est arrive.
    public func entete(_ nom: String) -> String? {
        entetes[nom.lowercased()]
    }
}

/// Ce qui porte une requete jusqu au serveur et rend sa reponse.
///
/// L implementation livree est `TransportURLSession`. Les tests en fournissent
/// une autre, qui rend des reponses figees sans jamais ouvrir de connexion.
public protocol TransportHttp: Sendable {
    /// Execute la requete et rend la reponse du serveur.
    ///
    /// - Throws: `ErreurReseau`, jamais `URLError`. La traduction se fait ici,
    ///   une fois, pour que les couches au dessus n aient plus que des cas
    ///   nommes a traiter.
    func executer(_ requete: URLRequest) async throws -> ReponseHttp
}

/// Le transport reel, pose sur `URLSession`.
public struct TransportURLSession: TransportHttp {
    /// Delai au dela duquel une requete est abandonnee.
    ///
    /// Quinze secondes, la meme valeur que le delai du registre de sources et
    /// que la limite imposee aux extensions par la section 4.3. Deux delais
    /// differents feraient qu une source lente serait tantot declaree muette par
    /// le registre, tantot en echec de transport, selon laquelle des deux
    /// horloges gagne.
    public static let delaiParDefaut: TimeInterval = 15

    private let session: URLSession

    /// Construit le transport sur une session dediee.
    ///
    /// La session n est pas `URLSession.shared` par defaut : les sources
    /// distantes ne doivent pas mettre en cache leurs reponses, sans quoi une
    /// progression publiee puis relue reviendrait telle qu elle etait avant la
    /// publication.
    public init(session: URLSession? = nil) {
        guard let session else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            configuration.timeoutIntervalForRequest = Self.delaiParDefaut
            self.session = URLSession(configuration: configuration)

            return
        }

        self.session = session
    }

    public func executer(_ requete: URLRequest) async throws -> ReponseHttp {
        let recue: (Data, URLResponse)

        do {
            recue = try await session.data(for: requete)
        } catch {
            throw ErreurReseau.depuis(error) ?? .echecDeTransport(code: 0)
        }

        guard let http = recue.1 as? HTTPURLResponse else {
            // Une reponse qui n est pas HTTP vient d un schema d URL que la
            // source n a pas a servir. La traiter comme un succes ferait
            // analyser des octets dont personne ne sait d ou ils viennent.
            throw ErreurReseau.reponseIllisible
        }

        return ReponseHttp(code: http.statusCode, entetes: Self.entetes(de: http), corps: recue.0)
    }

    /// Ramene les entetes d une reponse dans un dictionnaire de chaines.
    ///
    /// `allHeaderFields` est un dictionnaire non type dont les cles sont des
    /// `AnyHashable`. Les entrees qui ne sont pas des chaines des deux cotes
    /// sont ecartees plutot que forcees : elles n existent pas en HTTP, et un
    /// transtypage force pour un cas impossible est un plantage en attente.
    private static func entetes(de reponse: HTTPURLResponse) -> [String: String] {
        reponse.allHeaderFields.reduce(into: [:]) { table, entete in
            guard let nom = entete.key as? String, let valeur = entete.value as? String else {
                return
            }

            table[nom] = valeur
        }
    }
}
