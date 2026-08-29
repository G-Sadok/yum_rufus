import Core
import Foundation

//
// ClientHttp
//
// Ce qui separe une reponse acceptable d une reponse a rejeter, et ce qui
// transforme des octets en valeurs. Commun a toutes les sources REST du projet,
// Komga d abord, Kavita et Jellyfin ensuite.
//
// Il ne connait aucune API. Il sait construire une adresse, y poser une preuve
// d identite, verifier ce qui revient, et decoder. Ce partage n est pas un
// confort : les quatre cas que la strategie de test exige, reponse malformee,
// vide, tronquee et code d erreur, se traitent exactement pareil pour les
// quatre sources, et les ecrire quatre fois garantirait quatre comportements.
//
// L ordre des verifications est volontaire. Le code de statut d abord, parce
// qu un corps d erreur n a pas a etre decode comme un succes. La troncature
// ensuite, parce qu un JSON coupe se decode parfois sans lever, en rendant un
// objet incomplet. Le corps vide enfin, parce qu il est indiscernable d un
// document illisible une fois passe au decodeur.
//
// La preuve d identite n est pas posee a la construction de la requete mais a
// son execution, et c est ce qui rend le rafraichissement de jeton possible.
// Une requete construite reste donc anonyme tant qu elle n est pas partie, ce
// qui permet de la rejouer telle quelle avec une preuve neuve apres un refus,
// sans avoir a retirer un entete perime dont on ne connaitrait plus le nom.
//

/// Ce que le client presente au serveur pour prouver qui il est.
///
/// Le type est distinct de `IdentifiantsDeSource` : celui la dit ce que
/// l utilisateur a saisi, celui ci dit ce qui part sur le fil. Une cle d API se
/// pose dans un entete dont le nom depend du serveur, et ce nom appartient a la
/// source, pas au trousseau.
public enum AuthentificationHttp: Sendable, Hashable {
    /// Le serveur ne demande rien.
    case aucune

    /// Compte et mot de passe, poses dans un entete `Authorization: Basic`.
    case basique(compte: String, motDePasse: String)

    /// Entete libre, pour les serveurs qui nomment eux memes leur cle.
    case entete(nom: String, valeur: String)

    /// L entete a poser, ou nul quand il n y a rien a prouver.
    var enteteDIdentite: EnteteDIdentite? {
        switch self {
        case .aucune:
            nil
        case let .basique(compte, motDePasse):
            EnteteDIdentite(
                nom: "Authorization",
                valeur: "Basic " + Data("\(compte):\(motDePasse)".utf8).base64EncodedString()
            )
        case let .entete(nom, valeur):
            EnteteDIdentite(nom: nom, valeur: valeur)
        }
    }
}

/// Client REST minimal, commun aux sources qui parlent a un serveur.
public struct ClientHttp: Sendable {
    /// Adresse a laquelle tous les chemins s ajoutent.
    public let base: URL

    private let transport: any TransportHttp
    private let identite: any IdentiteHttp

    /// Instant de reference, pour lire un `Retry-After` exprime en date.
    ///
    /// Il est injecte plutot que lu de l horloge, sans quoi le delai calcule
    /// pour une date fixe changerait a chaque execution du test.
    private let maintenant: @Sendable () -> Date

    /// Construit le client sur une preuve d identite qui ne change pas.
    ///
    /// - Throws: `ErreurReseau.transportNonChiffre` quand l adresse est en clair
    ///   et que l utilisateur n a pas confirme l exception de la section 11.
    public init(
        base: URL,
        transport: any TransportHttp,
        authentification: AuthentificationHttp = .aucune,
        accepteLeHttpEnClair: Bool = false,
        maintenant: @escaping @Sendable () -> Date = Date.init
    ) throws {
        try self.init(
            base: base,
            transport: transport,
            identite: IdentiteFixe(authentification: authentification),
            accepteLeHttpEnClair: accepteLeHttpEnClair,
            maintenant: maintenant
        )
    }

    /// Construit le client sur une preuve d identite qui sait se renouveler.
    ///
    /// - Throws: `ErreurReseau.transportNonChiffre` quand l adresse est en clair
    ///   et que l utilisateur n a pas confirme l exception de la section 11.
    public init(
        base: URL,
        transport: any TransportHttp,
        identite: any IdentiteHttp,
        accepteLeHttpEnClair: Bool = false,
        maintenant: @escaping @Sendable () -> Date = Date.init
    ) throws {
        let schema = base.scheme?.lowercased()

        // Le refus est ici et non a chaque requete : une adresse en clair est
        // une propriete de la configuration, et la verifier a chaque appel
        // reviendrait a esperer que personne n oublie un chemin.
        if schema != "https", accepteLeHttpEnClair == false {
            throw ErreurReseau.transportNonChiffre
        }

        self.base = base
        self.transport = transport
        self.identite = identite
        self.maintenant = maintenant
    }

    // MARK: Construction des requetes

    /// Construit la requete qui interroge un chemin de l API.
    ///
    /// Le chemin est ajoute a l adresse de base, ce qui laisse fonctionner un
    /// serveur publie derriere un sous chemin de proxy inverse. Une URL
    /// reconstruite depuis la racine perdrait ce sous chemin, et la source
    /// repondrait vide sans dire pourquoi.
    ///
    /// La requete rendue ne porte aucune preuve d identite. C est `executer(_:)`
    /// qui la pose, juste avant le depart, pour pouvoir rejouer la meme requete
    /// avec une preuve neuve quand le serveur refuse la premiere.
    public func requete(
        chemin: String,
        parametres: [URLQueryItem] = [],
        methode: MethodeHttp = .get,
        corpsJson: Data? = nil
    ) throws -> URLRequest {
        var requete = try URLRequest(url: Self.adresse(base: base, chemin: chemin, parametres: parametres))
        requete.httpMethod = methode.rawValue
        requete.setValue("application/json", forHTTPHeaderField: "Accept")

        if let corpsJson {
            requete.httpBody = corpsJson
            requete.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        return requete
    }

    /// Assemble une adresse a partir d une base, d un chemin et de parametres.
    ///
    /// - Throws: `ErreurReseau.serveurIntrouvable` quand l assemblage ne produit
    ///   aucune adresse valable.
    public static func adresse(base: URL, chemin: String, parametres: [URLQueryItem] = []) throws -> URL {
        let complete = base.appending(path: chemin)

        guard var composants = URLComponents(url: complete, resolvingAgainstBaseURL: false) else {
            throw ErreurReseau.serveurIntrouvable
        }

        if parametres.isEmpty == false {
            composants.queryItems = parametres
        }

        guard let assemblee = composants.url else {
            throw ErreurReseau.serveurIntrouvable
        }

        return assemblee
    }

    /// La requete qui rapporte les octets d une adresse deja construite.
    ///
    /// Sert aux images de page, dont l adresse est portee par `PageDistante` et
    /// non recalculee a partir d un chemin. La preuve d identite y est posee
    /// comme sur les autres requetes : un serveur protege refuse une image tout
    /// autant qu un document JSON.
    ///
    /// Elle est posee ici et non a l execution parce que cette requete la n est
    /// pas executee par le client : elle est rendue a la chaine d images, qui
    /// l envoie elle meme. Demander la preuve maintenant garantit qu elle est
    /// fraiche au moment ou la page part.
    public func requeteBrute(_ adresse: URL) async throws -> URLRequest {
        var requete = URLRequest(url: adresse)

        try await Self.poser(identite.entete(), sur: &requete)

        return requete
    }

    // MARK: Interrogation

    /// Interroge le serveur et decode la reponse.
    ///
    /// - Throws: `ErreurReseau`, dans le cas nomme qui correspond a ce qui s est
    ///   passe.
    public func lire<Valeur: Decodable>(
        _ type: Valeur.Type,
        chemin: String,
        parametres: [URLQueryItem] = [],
        methode: MethodeHttp = .get,
        corpsJson: Data? = nil
    ) async throws -> Valeur {
        try await lireAvecReponse(
            type,
            chemin: chemin,
            parametres: parametres,
            methode: methode,
            corpsJson: corpsJson
        ).valeur
    }

    /// Interroge le serveur, decode la reponse et rend aussi la reponse brute.
    ///
    /// Sert aux serveurs qui portent leur pagination dans un entete plutot que
    /// dans le corps, Kavita en tete. Sans elle, la source devrait deviner
    /// l existence d une page suivante en comptant les elements recus, ce qui
    /// demande une requete vide de plus chaque fois que le total tombe juste.
    public func lireAvecReponse<Valeur: Decodable>(
        _ type: Valeur.Type,
        chemin: String,
        parametres: [URLQueryItem] = [],
        methode: MethodeHttp = .get,
        corpsJson: Data? = nil
    ) async throws -> (valeur: Valeur, reponse: ReponseHttp) {
        let reponse = try await executer(
            requete(chemin: chemin, parametres: parametres, methode: methode, corpsJson: corpsJson)
        )

        return try (Self.decoder(type, depuis: reponse), reponse)
    }

    /// Envoie une requete dont la reponse ne porte rien a decoder.
    ///
    /// Le corps n est pas lu du tout, pas meme pour verifier qu il est vide :
    /// Komga repond 204 sans corps a une publication de progression, et un
    /// serveur place derriere un proxy peut y ajouter une page d etat.
    public func envoyer(
        chemin: String,
        methode: MethodeHttp,
        corpsJson: Data? = nil
    ) async throws {
        _ = try await executer(requete(chemin: chemin, methode: methode, corpsJson: corpsJson))
    }

    /// Execute une requete deja construite et verifie ce qui revient.
    ///
    /// Un refus d identifiants declenche un renouvellement de la preuve
    /// d identite et un seul nouvel essai. Un seul, parce qu une preuve neuve
    /// refusee a son tour ne l est pas parce qu elle est vieille : elle l est
    /// parce que le compte n a pas le droit, et reessayer en boucle serait la
    /// meilleure facon de faire bloquer ce compte par le serveur.
    public func executer(_ requete: URLRequest) async throws -> ReponseHttp {
        try Task.checkCancellation()

        let presentee = try await identite.entete()

        do {
            return try await envoyer(requete, avec: presentee)
        } catch ErreurReseau.authentificationRefusee {
            guard let renouvelee = await identite.renouveler(apres: presentee) else {
                throw ErreurReseau.authentificationRefusee
            }

            try Task.checkCancellation()

            return try await envoyer(requete, avec: renouvelee)
        }
    }

    /// Pose la preuve sur une copie de la requete, l envoie et valide la reponse.
    ///
    /// La preuve est posee sur une copie de la requete d origine et non sur
    /// celle qui vient de partir : reprendre la premiere laisserait l ancien
    /// entete en place quand le renouvellement change de nom d entete.
    private func envoyer(_ requete: URLRequest, avec entete: EnteteDIdentite?) async throws -> ReponseHttp {
        var partante = requete
        Self.poser(entete, sur: &partante)

        let reponse = try await transport.executer(partante)

        try valider(reponse)

        return reponse
    }

    /// Pose l entete d identite sur une requete, quand il y en a un.
    private static func poser(_ entete: EnteteDIdentite?, sur requete: inout URLRequest) {
        guard let entete else {
            return
        }

        requete.setValue(entete.valeur, forHTTPHeaderField: entete.nom)
    }

    // MARK: Verification

    /// Rejette une reponse que la source ne doit pas analyser.
    ///
    /// - Throws: `ErreurReseau.tropDeRequetes`, `.authentificationRefusee`,
    ///   `.ressourceIntrouvable` et les autres cas de code de statut, puis
    ///   `.reponseTronquee` quand le corps est plus court que ce que le serveur
    ///   annonce.
    public func valider(_ reponse: ReponseHttp) throws {
        if let erreur = ErreurReseau.depuis(
            codeHttp: reponse.code,
            nouvelEssaiApres: ErreurReseau.secondesAvantNouvelEssai(
                reponse.entete("Retry-After"),
                maintenant: maintenant()
            )
        ) {
            throw erreur
        }

        try Self.verifierLaLongueur(reponse)
    }

    /// Leve quand le corps recu est plus court que la longueur annoncee.
    ///
    /// Une reponse plus longue que son entete n est pas rejetee : elle vient
    /// d un serveur qui compte mal, pas d une connexion coupee, et la refuser
    /// rendrait la source inutilisable pour une erreur qui ne perd rien.
    private static func verifierLaLongueur(_ reponse: ReponseHttp) throws {
        guard
            let annoncee = reponse.entete("Content-Length").flatMap(Int.init),
            annoncee > reponse.corps.count
        else {
            return
        }

        throw ErreurReseau.reponseTronquee
    }

    // MARK: Decodage

    /// Decode le corps d une reponse deja validee.
    ///
    /// Le corps vide est traite avant le decodage et non apres : un decodeur
    /// rend la meme erreur pour zero octet et pour du HTML, alors que les deux
    /// se reparent differemment, l un en reessayant, l autre en corrigeant
    /// l adresse de la source.
    /// Elle est publique depuis les services de suivi : ils construisent leurs
    /// requetes eux memes, parce que deux d entre eux n envoient pas du JSON,
    /// mais ils doivent lire ce qui revient exactement comme les sources.
    public static func decoder<Valeur: Decodable>(
        _ type: Valeur.Type,
        depuis reponse: ReponseHttp
    ) throws -> Valeur {
        guard reponse.corps.isEmpty == false else {
            throw ErreurReseau.reponseVide
        }
        guard let valeur = try? JSONDecoder().decode(type, from: reponse.corps) else {
            throw ErreurReseau.reponseIllisible
        }

        return valeur
    }
}
