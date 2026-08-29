import Core
import Foundation
import Sources

//
// EchangeDeJeton
//
// Le seul endroit ou un code, un mot de passe ou un jeton de rafraichissement
// se transforme en jeton d acces.
//
// Il est separe du client parce que deux appelants s en servent, et qu ils ne
// vivent pas au meme niveau. La connexion l appelle une fois, au retour du
// navigateur. Le renouvellement l appelle depuis la couche d identite, au
// milieu d une requete deja partie. Les faire passer par le meme code garantit
// que le jeton renouvele est range comme le premier, avec son echeance et son
// jeton de rafraichissement, et non a moitie.
//
// L echange n emprunte pas `ClientHttp`. Le client pose une preuve d identite
// sur chaque requete et sait la renouveler en cas de refus : c est exactement
// ce qu il ne faut pas faire ici, ou le refus est la reponse a interpreter et
// non un incident a rattraper.
//

/// Transforme une autorisation en jeton range dans le trousseau.
struct EchangeDeJeton: Sendable {
    /// Service interroge.
    let service: ServiceDeSuivi

    /// Dialecte qui sait lire la reponse du service.
    let dialecte: any DialecteDeSuivi

    /// Transport reel ou fige.
    let transport: any TransportHttp

    /// Horloge, injectee pour que l echeance calculee soit comparable en test.
    let maintenant: @Sendable () -> Date

    /// Echange les champs d un formulaire contre un jeton.
    ///
    /// - Throws: `ErreurDeSuivi.autorisationRefusee` quand le service refuse en
    ///   nommant sa raison, `ErreurDeSuivi.reponseIllisible` quand il refuse
    ///   sans rien dire ou repond autre chose qu un jeton.
    func executer(champs: [URLQueryItem]) async throws -> IdentifiantsDeSource {
        var requete = URLRequest(url: service.descriptif.jeton)
        requete.httpMethod = MethodeHttp.post.rawValue
        requete.setValue("application/json", forHTTPHeaderField: "Accept")
        requete.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        requete.httpBody = Data(FormulaireEncode.corps(champs).utf8)

        return try await lire(transport.executer(requete))
    }

    /// Echange un compte et un mot de passe contre un jeton de session.
    ///
    /// - Throws: `ErreurDeSuivi.serviceNonConfigure` quand le service ne se
    ///   connecte pas de cette facon.
    func executer(compte: String, motDePasse: String) async throws -> IdentifiantsDeSource {
        guard let appel = dialecte.appelDeConnexionParIdentifiants(compte: compte, motDePasse: motDePasse) else {
            throw ErreurDeSuivi.serviceNonConfigure(service: service)
        }

        var requete = URLRequest(url: service.descriptif.jeton)
        requete.httpMethod = appel.methode.rawValue
        requete.setValue("application/json", forHTTPHeaderField: "Accept")

        if case let .json(donnees) = appel.corps {
            requete.httpBody = donnees
            requete.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        return try await lire(transport.executer(requete))
    }

    /// Lit la reponse du point d echange.
    private func lire(_ reponse: ReponseHttp) throws -> IdentifiantsDeSource {
        guard reponse.code < 400 else {
            throw ErreurDeSuivi.autorisationRefusee(service: service, motif: Self.motif(de: reponse))
        }

        return try dialecte.jeton(depuis: reponse, le: maintenant())
    }

    /// Motif du refus, tel que la norme le fait porter au corps.
    ///
    /// Le code de statut sert de repli. Il ne dit pas grand chose, mais il dit
    /// toujours quelque chose, et un motif vide dans un message d erreur laisse
    /// l utilisateur devant une phrase inachevee.
    private static func motif(de reponse: ReponseHttp) -> String {
        guard
            let objet = try? JSONSerialization.jsonObject(with: reponse.corps) as? [String: Any],
            let motif = objet["error"] as? String,
            motif.isEmpty == false
        else {
            return "code \(reponse.code)"
        }

        return motif
    }
}

/// Encodage d un formulaire dans le corps d une requete.
enum FormulaireEncode {
    /// Le corps d un formulaire, champs encodes et joints par des esperluettes.
    ///
    /// Le plus est reencode a la main apres coup. `URLComponents` le laisse
    /// passer tel quel, ce qui est correct dans une adresse mais faux dans un
    /// corps de formulaire, ou le serveur le relit comme une espace. Un jeton
    /// de rafraichissement contenant un plus se retrouverait alors coupe en
    /// deux, et le renouvellement echouerait une fois sur soixante quatre sans
    /// jamais etre reproductible.
    static func corps(_ champs: [URLQueryItem]) -> String {
        var composants = URLComponents()
        composants.queryItems = champs

        return (composants.percentEncodedQuery ?? "").replacingOccurrences(of: "+", with: "%2B")
    }
}
