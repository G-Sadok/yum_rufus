import Core
import Foundation

//
// IdentiteHttp
//
// Ce qui prouve au serveur qui parle, et ce qui sait le prouver a nouveau quand
// la preuve a expire.
//
// Le protocole existe pour une seule source, Kavita, et il est pourtant place
// dans la couche commune. La raison tient au sens du mot expiration. Un mot de
// passe et une cle d API valent jusqu a ce que l utilisateur les change, ils se
// posent donc une fois pour toutes a la construction du client. Un jeton JWT,
// lui, cesse de valoir au bout de quelques minutes, et la seule facon de ne pas
// interrompre une lecture est de le renouveler la ou la requete part, pas la ou
// la source est configuree.
//
// Le renouvellement recoit la preuve que le serveur vient de refuser, et c est
// ce parametre qui fait toute la difference. Quand dix pages partent ensemble
// et se font refuser ensemble, la premiere renouvelle, les neuf autres
// constatent que la preuve courante n est deja plus celle qu on leur a refusee
// et reprennent la nouvelle. Sans ce parametre, dix requetes de connexion
// partiraient pour une seule expiration, et le serveur en refuserait la moitie.
//

/// L entete qui porte la preuve d identite d une requete.
///
/// Le type remplace le couple de chaines anonyme employe auparavant : il se
/// compare, ce dont le renouvellement a besoin pour reconnaitre une preuve deja
/// remplacee, et il se nomme, ce qu un tuple ne fait pas dans une signature de
/// protocole.
public struct EnteteDIdentite: Sendable, Hashable {
    /// Nom de l entete HTTP, tel que le serveur l attend.
    public let nom: String

    /// Valeur complete de l entete, prefixe compris.
    public let valeur: String

    public init(nom: String, valeur: String) {
        self.nom = nom
        self.valeur = valeur
    }
}

/// Ce qui fournit la preuve d identite des requetes d un client, et la renouvelle.
public protocol IdentiteHttp: Sendable {
    /// L entete a poser sur la prochaine requete.
    ///
    /// Rend nul quand le serveur ne demande rien. Peut declencher une connexion
    /// au serveur d authentification quand aucune preuve valable n est retenue.
    ///
    /// - Throws: `ErreurReseau.authentificationRefusee` quand la preuve ne peut
    ///   pas etre obtenue, et les autres cas d `ErreurReseau` quand c est le
    ///   transport qui a echoue.
    func entete() async throws -> EnteteDIdentite?

    /// Renouvelle la preuve apres un refus du serveur.
    ///
    /// - Parameter refusee: la preuve que le serveur vient de refuser, ou nul
    ///   quand la requete n en portait aucune. Une preuve courante differente de
    ///   celle la veut dire qu une autre tache a deja renouvele, et le
    ///   renouvellement se contente alors de rendre la preuve en place.
    /// - Returns: la nouvelle preuve, ou nul quand il n y a rien a retenter.
    func renouveler(apres refusee: EnteteDIdentite?) async -> EnteteDIdentite?
}

/// Preuve d identite qui ne change jamais.
///
/// C est le cas des sources dont les identifiants sont un mot de passe ou une
/// cle d API. Le renouvellement rend toujours nul : reposer la meme preuve
/// apres un refus ferait deux requetes la ou une seule suffit a conclure que
/// les identifiants sont a corriger.
struct IdentiteFixe: IdentiteHttp {
    let authentification: AuthentificationHttp

    func entete() -> EnteteDIdentite? {
        authentification.enteteDIdentite
    }

    func renouveler(apres _: EnteteDIdentite?) -> EnteteDIdentite? {
        nil
    }
}
