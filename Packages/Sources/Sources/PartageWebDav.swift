import Core
import Foundation

//
// PartageWebDav
//
// Le partage WebDAV du tableau 4.2, pose sur `ClientWebDav`.
//
// Il ne fait qu une chose que le client ne fait pas : traduire entre deux
// facons de nommer une entree. Le serveur parle en chemins absolus encodes en
// pourcentage, `/dav/Mangas/Berserk/Tome%2001.cbz` ; le reste du projet parle en
// chemins relatifs a la racine de la source, `Berserk/Tome 01.cbz`. La bascule
// se fait ici, une fois, parce qu elle depend du dossier racine que
// l utilisateur a choisi et de rien d autre.
//
// Le listage laisse tomber une entree, et c est voulu. Un `PROPFIND` de
// profondeur un rend le dossier interroge en plus de son contenu, la norme
// l impose. La garder ferait apparaitre chaque serie comme son propre
// sous dossier, et l analyse a deux niveaux y verrait une profondeur de plus.
//
// Les attributs d un fichier se demandent par `PROPFIND` de profondeur zero, et
// par `HEAD` en secours. Le secours n est pas de la prudence gratuite : une
// partie des serveurs WebDAV refusent un `PROPFIND` sur autre chose qu une
// collection, et sans lui la taille du conteneur resterait inconnue, donc la
// lecture en flux impossible sur ces serveurs la.
//

/// Partage reseau servi par un serveur WebDAV.
public actor PartageWebDav: PartageReseau {
    public nonisolated let libelle: String

    /// Chemin absolu du dossier racine sur le serveur, deja decode.
    private let racine: String

    private let client: ClientWebDav

    /// Construit le partage sur l adresse d un dossier WebDAV.
    ///
    /// - Throws: `ErreurReseau.transportNonChiffre` quand l adresse est en clair
    ///   et que l utilisateur n a pas confirme l exception de la section 11.
    public init(
        libelle: String,
        base: URL,
        transport: any TransportHttp = TransportURLSession(),
        identifiants: IdentifiantsWebDav = .aucuns,
        accepteLeHttpEnClair: Bool = false
    ) throws {
        self.libelle = libelle
        client = try ClientWebDav(
            base: base,
            transport: transport,
            identifiants: identifiants,
            accepteLeHttpEnClair: accepteLeHttpEnClair
        )
        racine = Self.normaliser(base.path)
    }

    /// Construit le partage sur un client deja pret.
    ///
    /// Sert aux tests, qui fournissent leur propre generateur de `cnonce` pour
    /// que la reponse Digest calculee soit comparable a un vecteur connu.
    init(libelle: String, client: ClientWebDav) async {
        self.libelle = libelle
        self.client = client
        racine = Self.normaliser(client.base.path)
    }

    // MARK: Protocole

    public func lister(_ chemin: String) async throws -> [EntreeDePartage] {
        let demande = Self.normaliser(CheminDePartage.joindre(racine, chemin))

        return try await client.lister(chemin).compactMap { reponse in
            // Le dossier interroge revient dans sa propre reponse. Le garder
            // ferait de chaque serie un sous dossier d elle meme.
            guard Self.normaliser(reponse.chemin) != demande else {
                return nil
            }

            return entree(reponse)
        }
    }

    public func attributs(de chemin: String) async throws -> EntreeDePartage {
        if let decrite = try await attributsParPropfind(chemin) {
            return decrite
        }

        return try await attributsParHead(chemin)
    }

    public func lire(_ chemin: String, a offset: UInt64, longueur: Int) async throws -> Data {
        try await client.lire(chemin, a: offset, longueur: longueur)
    }

    // MARK: Attributs

    /// Les attributs lus par un `PROPFIND` de profondeur zero.
    ///
    /// Rend nul quand le serveur refuse la methode sur cette ressource, ce qui
    /// laisse le secours par `HEAD` prendre la suite. Une ressource reellement
    /// absente, elle, leve : la confondre avec un refus de methode ferait
    /// demander deux fois au serveur ce qu il a deja dit ne pas connaitre.
    private func attributsParPropfind(_ chemin: String) async throws -> EntreeDePartage? {
        do {
            let reponses = try await client.lister(chemin, profondeur: "0")

            guard let decrite = reponses.first else {
                return nil
            }

            return entree(decrite)
        } catch ErreurReseau.reponseInattendue, ErreurReseau.accesRefuse, ErreurReseau.reponseIllisible {
            return nil
        }
    }

    /// Les attributs deduits des seuls entetes de la ressource.
    private func attributsParHead(_ chemin: String) async throws -> EntreeDePartage {
        let reponse = try await client.entetes(de: chemin)
        let taille = reponse.entete("Content-Length").flatMap(UInt64.init) ?? 0

        return EntreeDePartage(
            chemin: chemin,
            estDossier: false,
            taille: taille,
            dateModification: AnalyseWebDav.date(reponse.entete("Last-Modified"))
        )
    }

    // MARK: Chemins

    /// Traduit une reponse du serveur en entree de partage.
    ///
    /// Un chemin qui ne commence pas par la racine est rendu tel quel, prive de
    /// son dossier de tete. Cela n arrive que chez un serveur qui redirige vers
    /// un autre prefixe, et perdre l entree serait pire que la nommer sur son
    /// seul dernier composant.
    private func entree(_ reponse: ReponseWebDav) -> EntreeDePartage {
        EntreeDePartage(
            chemin: relatif(reponse.chemin),
            estDossier: reponse.estDossier,
            taille: reponse.taille,
            dateModification: reponse.dateModification
        )
    }

    /// Rend un chemin absolu du serveur sous sa forme relative a la racine.
    private func relatif(_ absolu: String) -> String {
        let propre = Self.normaliser(absolu)

        guard racine.isEmpty == false else {
            return propre.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        guard propre.hasPrefix(racine + "/") else {
            return propre == racine ? "" : CheminDePartage.nom(de: propre)
        }

        return String(propre.dropFirst(racine.count + 1))
    }

    /// Retire les barres obliques de tete et de queue d un chemin.
    private static func normaliser(_ chemin: String) -> String {
        chemin.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}
