import Core
import Foundation

//
// ClientWebDav
//
// Le client du seul des trois partages qui parle HTTP. Il ne reutilise pas
// `ClientHttp`, et la raison tient en une phrase : une reponse Digest depend de
// la methode et du chemin de la requete, alors que `ClientHttp` pose une preuve
// d identite construite avant de savoir ou la requete va.
//
// La negociation suit la norme plutot que l habitude. La premiere requete part
// sans aucune preuve d identite. Le serveur repond `401` avec ses defis, le
// client choisit le plus solide, et rejoue. Le schema retenu est ensuite pose
// d avance sur toutes les requetes suivantes, ce qui ramene le cout de la
// negociation a un aller retour par session.
//
// Envoyer une authentification basique d avance aurait economise cet aller
// retour. Ce n est pas fait, et c est delibere : le mot de passe partirait alors
// vers un serveur dont on ne sait pas encore ce qu il accepte, y compris quand
// il n attend que du Digest et n aurait jamais du le voir passer en clair.
//
// Un `401` recu alors qu un defi est deja connu veut dire que le `nonce` a
// expire. La requete est rejouee une fois avec le defi neuf, une seule : un
// second refus ne vient plus d un `nonce` perime mais d un mot de passe faux, et
// boucler serait la meilleure facon de faire bloquer le compte.
//

/// Ce que l utilisateur a saisi pour un partage WebDAV.
public enum IdentifiantsWebDav: Sendable, Hashable {
    /// Le serveur ne demande rien.
    case aucuns

    /// Compte et mot de passe, quel que soit le schema que le serveur exige.
    case compte(compte: String, motDePasse: String)
}

/// Schema d authentification retenu apres la reponse du serveur.
private enum SchemaRetenu: Sendable {
    case basique
    case digest(DefiDigest)
}

/// Client HTTP dedie a WebDAV, qui sait repondre aux defis Basic et Digest.
actor ClientWebDav {
    /// Profondeur demandee au listage d un dossier.
    ///
    /// Un seul niveau. La profondeur infinie ferait rendre par le serveur toute
    /// la bibliotheque en une reponse, ce qui est exactement ce que l analyse a
    /// deux niveaux de la section 4.2 n a pas besoin de payer.
    static let profondeurDUnNiveau = "1"

    /// Corps de la requete `PROPFIND`, qui ne demande que les trois proprietes
    /// dont l analyse a besoin.
    ///
    /// Demander `allprop` aurait ete plus court a ecrire et beaucoup plus cher a
    /// recevoir : certains serveurs y joignent les verrous, les droits et les
    /// proprietes personnalisees de chaque entree.
    static let corpsDeListage = """
    <?xml version="1.0" encoding="utf-8"?>
    <D:propfind xmlns:D="DAV:">
      <D:prop>
        <D:resourcetype/>
        <D:getcontentlength/>
        <D:getlastmodified/>
      </D:prop>
    </D:propfind>
    """

    /// Adresse du partage, dossier racine compris.
    nonisolated let base: URL

    private let transport: any TransportHttp
    private let identifiants: IdentifiantsWebDav
    private let cnonce: @Sendable () -> String

    private var schema: SchemaRetenu?
    private var compteur: UInt32 = 0

    /// Construit le client sur l adresse d un partage.
    ///
    /// - Throws: `ErreurReseau.transportNonChiffre` quand l adresse est en clair
    ///   et que l utilisateur n a pas confirme l exception de la section 11.
    init(
        base: URL,
        transport: any TransportHttp,
        identifiants: IdentifiantsWebDav = .aucuns,
        accepteLeHttpEnClair: Bool = false,
        cnonce: @escaping @Sendable () -> String = ClientWebDav.cnonceAleatoire
    ) throws {
        if base.scheme?.lowercased() != "https", accepteLeHttpEnClair == false {
            throw ErreurReseau.transportNonChiffre
        }

        self.base = base
        self.transport = transport
        self.identifiants = identifiants
        self.cnonce = cnonce
    }

    /// Valeur aleatoire cote client, renouvelee a chaque defi.
    static let cnonceAleatoire: @Sendable () -> String = {
        var octets = Data(count: 16)
        octets.withUnsafeMutableBytes { tampon in
            for indice in 0..<tampon.count {
                tampon[indice] = UInt8.random(in: 0...255)
            }
        }

        return octets.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: Requetes

    /// Liste le contenu direct d un dossier du partage.
    ///
    /// - Throws: `ErreurReseau.reponseIllisible` quand le document rendu n est
    ///   pas une reponse multi statuts, `.reponseVide` quand le serveur repond
    ///   sans corps, et les cas de code de statut pour tout le reste.
    func lister(
        _ chemin: String,
        profondeur: String = ClientWebDav.profondeurDUnNiveau
    ) async throws -> [ReponseWebDav] {
        let reponse = try await executer(
            methode: .propfind,
            chemin: chemin,
            entetes: ["Depth": profondeur, "Content-Type": "application/xml; charset=utf-8"],
            corps: Data(Self.corpsDeListage.utf8)
        )

        guard reponse.corps.isEmpty == false else {
            throw ErreurReseau.reponseVide
        }
        guard let entrees = AnalyseWebDav.analyser(reponse.corps) else {
            throw ErreurReseau.reponseIllisible
        }

        return entrees
    }

    /// Rend une plage d octets d un fichier du partage.
    ///
    /// - Parameter longueur: nombre d octets demandes. La reponse peut etre plus
    ///   courte en fin de fichier, et plus longue chez un serveur qui ignore
    ///   l en tete `Range` ; l appelant tranche.
    func lire(_ chemin: String, a offset: UInt64, longueur: Int) async throws -> Data {
        guard longueur > 0 else {
            return Data()
        }

        let fin = offset + UInt64(longueur) - 1
        let reponse = try await executer(
            methode: .get,
            chemin: chemin,
            entetes: ["Range": "bytes=\(offset)-\(fin)"],
            corps: nil
        )

        return reponse.corps
    }

    /// Rend les entetes d une ressource, sans son contenu.
    func entetes(de chemin: String) async throws -> ReponseHttp {
        try await executer(methode: .head, chemin: chemin, entetes: [:], corps: nil)
    }

    // MARK: Execution

    /// Envoie une requete, en repondant au defi d authentification si besoin.
    func executer(
        methode: MethodeHttp,
        chemin: String,
        entetes: [String: String],
        corps: Data?
    ) async throws -> ReponseHttp {
        try Task.checkCancellation()

        let adresse = try Self.adresse(base: base, chemin: chemin)
        let uri = Self.uri(de: adresse)
        let premiere = try await envoyer(
            methode: methode,
            adresse: adresse,
            uri: uri,
            entetes: entetes,
            corps: corps
        )

        guard premiere.code == 401 || premiere.code == 407 else {
            try valider(premiere)

            return premiere
        }

        // Le defi est relu a chaque refus, y compris quand un schema etait deja
        // retenu : c est le seul moyen d obtenir le `nonce` neuf apres son
        // expiration, et rejouer avec l ancien serait refuse a l identique.
        guard retenir(premiere) else {
            throw ErreurReseau.authentificationRefusee
        }

        try Task.checkCancellation()

        let seconde = try await envoyer(
            methode: methode,
            adresse: adresse,
            uri: uri,
            entetes: entetes,
            corps: corps
        )

        try valider(seconde)

        return seconde
    }

    /// Construit la requete, y pose la preuve d identite courante, et l envoie.
    private func envoyer(
        methode: MethodeHttp,
        adresse: URL,
        uri: String,
        entetes: [String: String],
        corps: Data?
    ) async throws -> ReponseHttp {
        var requete = URLRequest(url: adresse)
        requete.httpMethod = methode.rawValue
        requete.httpBody = corps

        for entete in entetes {
            requete.setValue(entete.value, forHTTPHeaderField: entete.key)
        }
        if let preuve = preuve(methode: methode.rawValue, uri: uri) {
            requete.setValue(preuve, forHTTPHeaderField: "Authorization")
        }

        return try await transport.executer(requete)
    }

    /// La valeur de l entete `Authorization` pour cette requete, ou nul quand
    /// aucun schema n est encore retenu.
    private func preuve(methode: String, uri: String) -> String? {
        guard case let .compte(compte, motDePasse) = identifiants, let schema else {
            return nil
        }

        switch schema {
        case .basique:
            return "Basic " + Data("\(compte):\(motDePasse)".utf8).base64EncodedString()
        case let .digest(defi):
            compteur += 1

            return ReponseDigest(
                compte: compte,
                motDePasse: motDePasse,
                defi: defi,
                methode: methode,
                uri: uri,
                cnonce: cnonce(),
                compteur: compteur
            ).entete()
        }
    }

    /// Retient le schema annonce par un refus, et dit si un nouvel essai a un
    /// sens.
    private func retenir(_ reponse: ReponseHttp) -> Bool {
        guard case .compte = identifiants else {
            // Sans identifiants, repondre au defi n a rien a proposer. Le dire
            // tout de suite evite une seconde requete qui serait refusee pareil.
            return false
        }

        let entete = reponse.entete("WWW-Authenticate") ?? reponse.entete("Proxy-Authenticate")

        if let defi = DefiDigest.meilleur(dans: entete) {
            schema = .digest(defi)
            compteur = 0

            return true
        }
        guard let entete, entete.lowercased().contains("basic") else {
            return false
        }

        // Un serveur qui n annonce que Basic apres un premier envoi anonyme
        // merite un essai avec le mot de passe, et un seul.
        guard case .basique = schema else {
            schema = .basique

            return true
        }

        return false
    }

    /// Rejette une reponse que le partage ne doit pas analyser.
    private func valider(_ reponse: ReponseHttp) throws {
        if let erreur = ErreurReseau.depuis(codeHttp: reponse.code) {
            throw erreur
        }
    }

    // MARK: Adresses

    /// Assemble l adresse d un chemin relatif au partage.
    ///
    /// - Throws: `ErreurReseau.serveurIntrouvable` quand l assemblage ne produit
    ///   aucune adresse valable.
    static func adresse(base: URL, chemin: String) throws -> URL {
        let propre = chemin.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let complete = propre.isEmpty ? base : base.appending(path: propre)

        guard URLComponents(url: complete, resolvingAgainstBaseURL: false) != nil else {
            throw ErreurReseau.serveurIntrouvable
        }

        return complete
    }

    /// Le chemin tel qu il part sur la ligne de requete, parametres compris.
    ///
    /// C est la valeur que la norme Digest appelle `digest-uri`. Un serveur qui
    /// la compare a sa propre ligne de requete refuse une reponse calculee sur
    /// l adresse complete, schema et hote compris.
    static func uri(de adresse: URL) -> String {
        guard let composants = URLComponents(url: adresse, resolvingAgainstBaseURL: false) else {
            return adresse.path
        }

        let chemin = composants.percentEncodedPath.isEmpty ? "/" : composants.percentEncodedPath

        guard let requete = composants.percentEncodedQuery else {
            return chemin
        }

        return chemin + "?" + requete
    }
}
