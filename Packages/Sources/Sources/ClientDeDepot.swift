import Core
import Foundation

//
// ClientDeDepot
//
// Le depot d extensions du tableau 4.2 : un catalogue JSON servi en HTTPS, et
// les paquets signes qu il publie.
//
// Le client ne passe pas par `TransportDExtension`. Ce n est pas un oubli : la
// barriere applique la liste blanche **d une extension**, et un depot n en a
// pas, il en distribue. Les deux regles qui s appliquent quand meme sont
// posees ici, et elles sont plus strictes que celles d une extension : le depot
// est en HTTPS, verifie par `DepotConfigure`, et un paquet ne se telecharge que
// depuis le meme hote que son catalogue.
//
// Cette derniere regle merite d etre dite. Sans elle, un depot pourrait publier
// une entree dont l adresse de paquet pointe ailleurs, et l utilisateur qui
// ajoute un depot de confiance se retrouverait a telecharger un paquet servi
// par un tiers. La signature protege ensuite du contenu, mais pas de la fuite
// de la requete elle meme.
//

/// Ce qui interroge un depot d extensions.
public struct ClientDeDepot: Sendable {
    /// Delai maximal accorde a une requete de depot.
    ///
    /// Le meme que celui des extensions et du registre de sources. Une valeur
    /// differente ferait qu un depot lent serait declare muet a un moment et
    /// pas a un autre selon le chemin emprunte.
    public static let delaiParDefaut: TimeInterval = 15

    private let transport: any TransportHttp

    public init(transport: any TransportHttp) {
        self.transport = transport
    }

    /// Lit le catalogue publie par ce depot.
    ///
    /// - Throws: `ErreurReseau` pour une panne de transport, et
    ///   `ErreurDExtension` pour un catalogue illisible ou trop recent.
    public func catalogue(de depot: DepotConfigure) async throws -> CatalogueDeDepot {
        try await CatalogueDeDepot.lire(octets(de: depot.adresse))
    }

    /// Telecharge le paquet d une entree et rend ce que l utilisateur doit lire.
    ///
    /// La verification de signature a lieu dans `InstallateurDExtensions`, avant
    /// que quoi que ce soit du manifeste ne soit interprete.
    ///
    /// - Throws: `ErreurReseau.domaineNonAutorise` quand l entree fait pointer
    ///   son paquet hors du depot, puis les refus de l installateur.
    public func paquet(
        de entree: EntreeDeDepot,
        depot: DepotConfigure,
        installateur: InstallateurDExtensions
    ) async throws -> PaquetPretAInstaller {
        try verifierQueLePaquetVientDuDepot(entree, depot: depot)

        return try await installateur.preparer(enveloppe: octets(de: entree.paquet))
    }

    /// Refuse un paquet servi par un autre hote que le depot.
    private func verifierQueLePaquetVientDuDepot(_ entree: EntreeDeDepot, depot: DepotConfigure) throws {
        let attendu = ListeBlancheDeDomaines.hote(de: depot.adresse)
        let observe = ListeBlancheDeDomaines.hote(de: entree.paquet)

        guard entree.paquet.scheme?.lowercased() == "https" else {
            throw ErreurReseau.transportNonChiffre
        }
        guard let attendu, let observe, attendu == observe else {
            throw ErreurReseau.domaineNonAutorise(domaine: observe ?? "")
        }
    }

    /// Rapporte les octets d une adresse, en validant ce qui revient.
    private func octets(de adresse: URL) async throws -> Data {
        var requete = URLRequest(url: adresse)
        requete.httpMethod = MethodeHttp.get.rawValue
        requete.setValue("application/json", forHTTPHeaderField: "Accept")

        let reponse = try await transport.executer(requete)

        if let erreur = ErreurReseau.depuis(codeHttp: reponse.code) {
            throw erreur
        }
        guard reponse.corps.isEmpty == false else {
            throw ErreurReseau.reponseVide
        }

        return reponse.corps
    }
}
