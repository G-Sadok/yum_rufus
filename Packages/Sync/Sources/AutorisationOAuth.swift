import Core
import CryptoKit
import Foundation

//
// AutorisationOAuth
//
// La moitie de la connexion qui ne parle pas au reseau : preparer la demande,
// et relire ce que le navigateur ramene.
//
// Elle est separee de l echange du code pour une raison de verification. Une
// demande d autorisation est une adresse, une redirection est une autre
// adresse, et les deux se comparent caractere par caractere dans un test sans
// qu aucun serveur ne soit necessaire. Ce qui reste, l echange proprement dit,
// se teste avec un transport fige.
//
// Deux protections vivent ici, et aucune des deux n est facultative.
//
// L etat, d abord. Il est tire au sort a chaque demande et doit revenir tel
// quel dans la redirection. Sans lui, n importe quelle application capable
// d ouvrir notre schema d URL pourrait nous faire echanger un code qu elle a
// obtenu ailleurs, et le compte connecte ne serait pas celui de l utilisateur.
//
// La preuve de cle ensuite, pour les services qui l acceptent. Le verifieur est
// tire au sort, seul son defi part dans la premiere adresse, et le verifieur ne
// sort qu au moment de l echange. Une application qui intercepterait la
// redirection tiendrait donc un code inutilisable.
//

/// Preuve de cle d une connexion, telle que la norme PKCE la definit.
///
/// Le type ne conforme ni a `Codable` ni a `CustomStringConvertible` par
/// accident : le verifieur est un secret le temps d une connexion, et la seule
/// facon de le lire est de nommer le champ.
public struct PreuveDeCle: Sendable, Hashable {
    /// Valeur tiree au sort, gardee jusqu a l echange du code.
    public let verifieur: String

    /// Ce qui part avec la demande d autorisation.
    public let defi: String

    /// Facon dont le defi a ete calcule.
    public let methode: MethodeDePreuveDeCle

    /// Construit la preuve a partir d un verifieur deja tire.
    public init(verifieur: String, methode: MethodeDePreuveDeCle) {
        self.verifieur = verifieur
        self.methode = methode

        switch methode {
        case .texteEnClair:
            defi = verifieur
        case .hachageSha256:
            defi = Data(SHA256.hash(data: Data(verifieur.utf8))).base64PourURL
        }
    }
}

/// Ce qu il faut retenir entre l ouverture du navigateur et son retour.
public struct DemandeDAutorisation: Sendable, Hashable {
    /// Service interroge.
    public let service: ServiceDeSuivi

    /// Adresse a ouvrir dans le navigateur.
    public let adresse: URL

    /// Valeur qui doit revenir dans la redirection.
    public let etat: String

    /// Preuve de cle, nulle pour les services qui n en demandent pas.
    public let preuve: PreuveDeCle?
}

/// Preparation et relecture d une autorisation OAuth 2.
public enum AutorisationOAuth {
    /// Longueur des valeurs tirees au sort, en octets avant encodage.
    ///
    /// Trente deux octets donnent quarante trois caracteres une fois encodes,
    /// ce qui est exactement le minimum que la norme impose au verifieur, et
    /// largement au dela de ce qu il faut a l etat.
    static let octetsTires = 32

    /// Prepare la demande d autorisation d un service.
    ///
    /// - Parameters:
    ///   - service: service a connecter.
    ///   - configuration: cles de l application chez ce service.
    ///   - tirage: source des valeurs aleatoires. Les tests en fournissent une
    ///     qui rend une suite connue, sans quoi l adresse produite changerait a
    ///     chaque execution et ne pourrait pas etre comparee.
    /// - Throws: `ErreurDeSuivi.serviceNonConfigure` quand la version installee
    ///   ne porte pas les cles du service, et quand le service ne se connecte
    ///   pas par le navigateur.
    public static func demande(
        pour service: ServiceDeSuivi,
        configuration: ConfigurationDesSuivis,
        tirage: TirageAleatoire = TirageAleatoireDuSysteme()
    ) throws -> DemandeDAutorisation {
        let descriptif = service.descriptif

        guard
            configuration.peutSeConnecter(service),
            let reglagesDuClient = configuration[service],
            let autorisation = descriptif.autorisation
        else {
            throw ErreurDeSuivi.serviceNonConfigure(service: service)
        }

        let etat = tirage.valeur(octets: octetsTires)
        let preuve = descriptif.preuveDeCle.map { methode in
            PreuveDeCle(verifieur: tirage.valeur(octets: octetsTires), methode: methode)
        }

        var parametres = [
            URLQueryItem(name: "client_id", value: reglagesDuClient.identifiantDeClient),
            URLQueryItem(name: "redirect_uri", value: reglagesDuClient.redirection.absoluteString),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "state", value: etat),
        ]

        if let preuve {
            parametres.append(URLQueryItem(name: "code_challenge", value: preuve.defi))
            parametres.append(URLQueryItem(name: "code_challenge_method", value: preuve.methode.rawValue))
        }

        guard var composants = URLComponents(url: autorisation, resolvingAgainstBaseURL: false) else {
            throw ErreurDeSuivi.serviceNonConfigure(service: service)
        }

        composants.queryItems = parametres

        guard let adresse = composants.url else {
            throw ErreurDeSuivi.serviceNonConfigure(service: service)
        }

        return DemandeDAutorisation(service: service, adresse: adresse, etat: etat, preuve: preuve)
    }

    /// Lit le code d autorisation dans l adresse par laquelle le navigateur
    /// revient.
    ///
    /// - Throws: `ErreurDeSuivi.autorisationRefusee` quand le service dit
    ///   pourquoi il refuse, `ErreurDeSuivi.etatDeRedirectionInattendu` quand
    ///   l etat ne correspond pas a la demande, et
    ///   `ErreurDeSuivi.autorisationAbandonnee` quand la redirection ne porte
    ///   ni code ni motif.
    public static func code(depuis redirection: URL, pour demande: DemandeDAutorisation) throws -> String {
        let parametres = URLComponents(url: redirection, resolvingAgainstBaseURL: false)?.queryItems ?? []

        func valeur(_ nom: String) -> String? {
            parametres.first { $0.name == nom }?.value
        }

        if let motif = valeur("error") {
            throw ErreurDeSuivi.autorisationRefusee(service: demande.service, motif: motif)
        }

        // L etat est verifie avant le code, et non apres. Verifier le code
        // d abord reviendrait a accepter de traiter une redirection dont on
        // sait deja qu elle ne vient pas de la demande envoyee.
        guard valeur("state") == demande.etat else {
            throw ErreurDeSuivi.etatDeRedirectionInattendu(service: demande.service)
        }

        guard let code = valeur("code"), code.isEmpty == false else {
            throw ErreurDeSuivi.autorisationAbandonnee(service: demande.service)
        }

        return code
    }

    /// Champs envoyes pour echanger un code contre un jeton.
    ///
    /// Le secret n est ajoute que pour les services qui l exigent. L envoyer a
    /// un service qui attend une preuve de cle ferait echouer l echange, et
    /// l omettre chez celui qui l attend aussi.
    public static func champsDEchange(
        pour demande: DemandeDAutorisation,
        code: String,
        configuration: ConfigurationDesSuivis
    ) throws -> [URLQueryItem] {
        guard let reglagesDuClient = configuration[demande.service] else {
            throw ErreurDeSuivi.serviceNonConfigure(service: demande.service)
        }

        var champs = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "client_id", value: reglagesDuClient.identifiantDeClient),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: reglagesDuClient.redirection.absoluteString),
        ]

        if let secret = reglagesDuClient.secretDeClient {
            champs.append(URLQueryItem(name: "client_secret", value: secret))
        }
        if let preuve = demande.preuve {
            champs.append(URLQueryItem(name: "code_verifier", value: preuve.verifieur))
        }

        return champs
    }

    /// Champs envoyes pour renouveler un jeton expire.
    public static func champsDeRafraichissement(
        pour service: ServiceDeSuivi,
        jetonDeRafraichissement: String,
        configuration: ConfigurationDesSuivis
    ) throws -> [URLQueryItem] {
        guard let reglagesDuClient = configuration[service] else {
            throw ErreurDeSuivi.serviceNonConfigure(service: service)
        }

        var champs = [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "client_id", value: reglagesDuClient.identifiantDeClient),
            URLQueryItem(name: "refresh_token", value: jetonDeRafraichissement),
        ]

        if let secret = reglagesDuClient.secretDeClient {
            champs.append(URLQueryItem(name: "client_secret", value: secret))
        }

        return champs
    }
}

/// Source des valeurs tirees au sort d une connexion.
///
/// Le protocole existe pour les tests. Une adresse d autorisation qui contient
/// deux valeurs aleatoires ne se compare a rien tant que le tirage n est pas
/// remplacable, et un test qui ne compare pas l adresse ne verifie pas grand
/// chose.
public protocol TirageAleatoire: Sendable {
    /// Une valeur encodee en base 64 pour URL, tiree sur ce nombre d octets.
    func valeur(octets: Int) -> String
}

/// Le tirage reel, celui du generateur du systeme.
public struct TirageAleatoireDuSysteme: TirageAleatoire {
    public init() {}

    public func valeur(octets: Int) -> String {
        var brut = Data(count: 0)

        for _ in 0..<max(1, octets) {
            brut.append(UInt8.random(in: UInt8.min...UInt8.max))
        }

        return brut.base64PourURL
    }
}

extension Data {
    /// Encodage base 64 pour URL, sans remplissage, tel que la norme l exige.
    ///
    /// Les trois substitutions ne sont pas un detail : un `+` ou un `/` dans un
    /// parametre d adresse se fait reinterpreter par le serveur, et le defi
    /// recu ne correspond alors plus au verifieur envoye plus tard.
    var base64PourURL: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
