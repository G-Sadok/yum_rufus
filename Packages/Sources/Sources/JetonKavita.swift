import Core
import Foundation

//
// JetonKavita
//
// Le jeton d acces d une session Kavita, et la lecture de son echeance.
//
// L echeance est le seul point interessant du fichier. Kavita ne la publie
// nulle part dans le corps de sa reponse de connexion : elle est ecrite dans le
// jeton lui meme, au format JWT, sous la revendication `exp`. La lire coute une
// decoupe et un decodage, et elle evite de decouvrir l expiration par un 401 au
// milieu d un chapitre. Le refus reste traite, parce qu un serveur qui change
// d horloge existe, mais il devient le cas rare au lieu du cas normal.
//
// La signature du jeton n est pas verifiee, et c est volontaire. Verifier une
// signature demande la cle du serveur, que le client n a pas et ne doit pas
// avoir. Le jeton n est pas une preuve ici, c est un laissez passer opaque que
// le serveur, lui, verifie. La seule chose qu on y lit est une date, et une
// date fausse ne fait que declencher un rafraichissement inutile.
//

/// Le jeton d une session Kavita, avec de quoi le renouveler.
struct JetonKavita: Sendable, Hashable {
    /// Le jeton d acces, tel qu il part dans l entete `Authorization`.
    let acces: String

    /// Le jeton de rafraichissement, quand le serveur en a emis un.
    let rafraichissement: String?

    /// Instant a partir duquel le serveur refusera le jeton d acces.
    ///
    /// Nul quand le jeton n est pas lisible comme un JWT. Le jeton est alors
    /// employe jusqu au premier refus, ce qui reste correct mais coute une
    /// requete perdue a chaque expiration.
    let expiration: Date?

    /// La cle d API du compte, que Kavita rend en meme temps que le jeton.
    ///
    /// Elle n est pas une seconde forme d authentification pour les requetes de
    /// l API : elle sert aux adresses d images, que la chaine d images demande
    /// elle meme et sur lesquelles aucun entete ne peut etre pose. C est cette
    /// cle, et non le jeton, qui fait qu une page continue de s afficher
    /// pendant qu une session se renouvelle.
    let cleDApi: String?

    /// L entete d identite que ce jeton produit.
    var entete: EnteteDIdentite {
        EnteteDIdentite(nom: "Authorization", valeur: "Bearer " + acces)
    }

    /// Les identifiants correspondants, tels qu ils se rangent dans le trousseau.
    var identifiants: IdentifiantsDeSource {
        .jeton(acces: acces, rafraichissement: rafraichissement, expiration: expiration)
    }

    /// Vrai quand le jeton vaut encore, marge de securite comprise.
    ///
    /// La marge existe parce que la requete part apres la verification, pas
    /// pendant. Sans elle, un jeton valable une demi seconde passerait le
    /// controle et se ferait refuser sur le fil.
    func estUtilisable(a instant: Date, marge: TimeInterval) -> Bool {
        guard let expiration else {
            return true
        }

        return expiration.timeIntervalSince(instant) > marge
    }

    /// Construit le jeton depuis ce que le serveur vient de repondre.
    ///
    /// - Parameter cleDApi: la cle deja connue, employee quand la reponse n en
    ///   porte aucune. Une reponse de rafraichissement ne rappelle pas la cle,
    ///   et la perdre a chaque renouvellement casserait l affichage des pages
    ///   exactement au moment ou la session vient d etre reparee.
    /// - Throws: `ErreurReseau.authentificationRefusee` quand la reponse ne
    ///   porte aucun jeton. Un corps accepte mais vide de jeton veut dire que
    ///   l adresse ne designe pas un serveur Kavita, pas que la connexion a
    ///   reussi.
    init(_ reponse: JetonDeKavita, cleDApi: String?) throws {
        guard let acces = reponse.token?.sansBlancs else {
            throw ErreurReseau.authentificationRefusee
        }

        self.acces = acces
        rafraichissement = reponse.refreshToken?.sansBlancs
        expiration = LecteurDeJetonJwt.expiration(de: acces)
        self.cleDApi = reponse.apiKey?.sansBlancs ?? cleDApi
    }

    /// Construit le jeton depuis ce que le trousseau porte.
    ///
    /// Rend nul quand les identifiants ranges ne sont pas un jeton, ce qui est
    /// le cas normal d une source configuree par compte et mot de passe.
    init?(_ identifiants: IdentifiantsDeSource) {
        guard case let .jeton(acces, rafraichissement, expiration) = identifiants else {
            return nil
        }

        self.acces = acces
        self.rafraichissement = rafraichissement
        // L echeance rangee prime sur celle du jeton : c est elle que la source
        // a ecrite au dernier renouvellement, et un jeton illisible en JWT n en
        // a pas d autre.
        self.expiration = expiration ?? LecteurDeJetonJwt.expiration(de: acces)
        // Le trousseau ne range aucune cle d API a cote d un jeton. La source
        // configuree ainsi lit ses pages avec l entete d identite, ce qui
        // fonctionne tant que le jeton vaut, et non pendant son renouvellement.
        cleDApi = nil
    }
}

// MARK: - Lecture de l echeance

/// Lecture de la revendication d echeance d un jeton JWT.
enum LecteurDeJetonJwt {
    /// L instant d expiration porte par le jeton, ou nul.
    ///
    /// Rend nul des que quoi que ce soit sort de l ordinaire : trois segments
    /// attendus, un corps en base64 dans sa variante d URL, un objet JSON, une
    /// revendication `exp` numerique. Aucun de ces echecs n est une erreur a
    /// remonter, ils veulent tous dire la meme chose, l echeance est inconnue.
    static func expiration(de jeton: String) -> Date? {
        let segments = jeton.split(separator: ".", omittingEmptySubsequences: false)

        guard segments.count == 3, let charge = donnees(base64Url: String(segments[1])) else {
            return nil
        }
        guard let lue = try? JSONDecoder().decode(ChargeUtileJwt.self, from: charge), let echeance = lue.exp else {
            return nil
        }

        return Date(timeIntervalSince1970: echeance)
    }

    /// Decode un segment de JWT, ecrit en base64 dans sa variante d URL.
    ///
    /// Les deux caracteres qui changent sont remis a leur place et le
    /// remplissage est reconstitue : la variante d URL le supprime, et
    /// `Data(base64Encoded:)` refuse une chaine dont la longueur n est pas un
    /// multiple de quatre.
    private static func donnees(base64Url texte: String) -> Data? {
        var normalise = texte
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let reste = normalise.count % 4

        if reste > 0 {
            normalise += String(repeating: "=", count: 4 - reste)
        }

        return Data(base64Encoded: normalise)
    }
}

/// La seule revendication d un JWT qui interesse le client.
private struct ChargeUtileJwt: Decodable {
    /// Echeance en secondes depuis le premier janvier 1970.
    let exp: Double?
}
