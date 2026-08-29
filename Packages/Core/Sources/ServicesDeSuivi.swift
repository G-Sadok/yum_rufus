import Foundation

//
// ServicesDeSuivi
//
// Ce que chacun des quatre services de la section 9 attend pour se connecter,
// ecrit une seule fois.
//
// Le tableau du cahier de developpement distingue deja deux formes : trois
// services portent la mention connexion OAuth, le quatrieme porte simplement
// connexion. Cet ecart n est pas cosmetique, il decide de tout le reste. Un
// service OAuth ouvre une page dans le navigateur, revient par une adresse de
// redirection et echange un code contre un jeton. Le quatrieme presente un
// compte et un mot de passe a une adresse de connexion et recoit un jeton de
// session. Melanger les deux dans un seul chemin de code produirait un chemin
// qui ne convient a aucun des deux.
//
// Aucun identifiant de client et aucun secret ne figure ici. Ce fichier decrit
// des adresses publiques, celles que la documentation de chaque service publie.
// Ce qui identifie notre application, lui, arrive par `ConfigurationDesSuivis`,
// au lancement, depuis l exterieur du depot : la section 11 interdit le secret
// en clair, et le controle 8 le verifie.
//

/// Facon dont un service etablit qu il parle bien a l utilisateur.
public enum NatureDeConnexionDeSuivi: String, Sendable, CaseIterable, Hashable {
    /// Code d autorisation OAuth 2, echange contre un jeton avec le secret du
    /// client.
    case codeDAutorisationAvecSecret

    /// Code d autorisation OAuth 2 protege par une preuve de cle, sans secret.
    ///
    /// C est la forme que les clients publics doivent employer : une
    /// application installee sur un appareil ne peut pas garder un secret, la
    /// preuve de cle remplace donc le secret par une valeur tiree au sort a
    /// chaque connexion.
    case codeDAutorisationAvecPreuveDeCle

    /// Compte et mot de passe presentes une fois, echanges contre un jeton de
    /// session.
    case identifiantsDeCompte

    /// Vrai quand la connexion passe par le navigateur et une redirection.
    public var passeParLeNavigateur: Bool {
        switch self {
        case .codeDAutorisationAvecSecret, .codeDAutorisationAvecPreuveDeCle: true
        case .identifiantsDeCompte: false
        }
    }

    /// Vrai quand la demande d autorisation porte une preuve de cle.
    public var exigeUnePreuveDeCle: Bool {
        self == .codeDAutorisationAvecPreuveDeCle
    }
}

/// Facon dont la preuve de cle est calculee, telle que la norme la nomme.
///
/// Les deux valeurs brutes sont celles qui partent sur le fil, `plain` et
/// `S256`. Le service decide, jamais le client : demander `S256` a un serveur
/// qui ne l accepte pas fait echouer l echange du code avec un message que
/// l utilisateur ne peut pas corriger.
public enum MethodeDePreuveDeCle: String, Sendable, CaseIterable, Hashable {
    /// Le verifieur est envoye tel quel.
    case texteEnClair = "plain"

    /// Le defi est l empreinte SHA 256 du verifieur, en base 64 pour URL.
    case hachageSha256 = "S256"
}

/// Ce qu il faut savoir d un service de suivi pour s y connecter.
public struct DescriptionDeServiceDeSuivi: Sendable, Hashable {
    /// Service decrit.
    public let service: ServiceDeSuivi

    /// Nom du service tel que le tableau de la section 9 l ecrit.
    ///
    /// Il ne s affiche pas : les libelles visibles passent par le catalogue de
    /// chaines. Il existe pour que la suite de tests confronte cette table au
    /// document sans recopier la liste a cote.
    public let nomDuDocument: String

    /// Forme de connexion attendue.
    public let nature: NatureDeConnexionDeSuivi

    /// Methode de preuve de cle, nulle quand la nature n en demande aucune.
    public let preuveDeCle: MethodeDePreuveDeCle?

    /// Page ouverte dans le navigateur pour demander l autorisation, nulle
    /// quand la connexion ne passe pas par lui.
    public let autorisation: URL?

    /// Adresse qui echange un code, un mot de passe ou un jeton de
    /// rafraichissement contre un jeton d acces.
    public let jeton: URL

    /// Racine de l API interrogee une fois la connexion etablie.
    public let api: URL

    /// Vrai quand le service emet un jeton de rafraichissement.
    ///
    /// Quand il repond faux, un jeton refuse renvoie l utilisateur vers une
    /// nouvelle connexion, il ne se renouvelle pas en silence.
    public let rafraichitSonJeton: Bool

    /// Note maximale de l echelle du service.
    ///
    /// Les services ne comptent pas pareil, et une note publiee dans la
    /// mauvaise echelle transforme un huit sur dix en huit sur cent. La
    /// conversion se fait a la frontiere, avec cette valeur, jamais dans le
    /// modele.
    public let echelleDeNote: Double
}

extension ServiceDeSuivi {
    /// Description du service, telle que la section 9 la fixe.
    ///
    /// Le nom evite `description` : ce membre la est celui de
    /// `CustomStringConvertible`, il rend une chaine, et le prendre pour un
    /// autre type interdirait au type de s y conformer un jour.
    public var descriptif: DescriptionDeServiceDeSuivi {
        switch self {
        case .aniList:
            DescriptionDeServiceDeSuivi(
                service: self,
                nomDuDocument: "AniList",
                nature: .codeDAutorisationAvecSecret,
                preuveDeCle: nil,
                autorisation: Self.adresseFixe("https://anilist.co/api/v2/oauth/authorize"),
                jeton: Self.adresseFixe("https://anilist.co/api/v2/oauth/token"),
                api: Self.adresseFixe("https://graphql.anilist.co"),
                rafraichitSonJeton: false,
                echelleDeNote: 100
            )

        case .myAnimeList:
            DescriptionDeServiceDeSuivi(
                service: self,
                nomDuDocument: "MyAnimeList",
                nature: .codeDAutorisationAvecPreuveDeCle,

                // Le service n accepte que la forme en clair. Lui envoyer une
                // empreinte fait echouer l echange du code, et le message
                // renvoye ne dit pas pourquoi.
                preuveDeCle: .texteEnClair,
                autorisation: Self.adresseFixe("https://myanimelist.net/v1/oauth2/authorize"),
                jeton: Self.adresseFixe("https://myanimelist.net/v1/oauth2/token"),
                api: Self.adresseFixe("https://api.myanimelist.net/v2"),
                rafraichitSonJeton: true,
                echelleDeNote: 10
            )

        case .kitsu:
            DescriptionDeServiceDeSuivi(
                service: self,
                nomDuDocument: "Kitsu",
                nature: .codeDAutorisationAvecPreuveDeCle,
                preuveDeCle: .hachageSha256,
                autorisation: Self.adresseFixe("https://kitsu.io/api/oauth/authorize"),
                jeton: Self.adresseFixe("https://kitsu.io/api/oauth/token"),
                api: Self.adresseFixe("https://kitsu.io/api/edge"),
                rafraichitSonJeton: true,
                echelleDeNote: 20
            )

        case .mangaUpdates:
            DescriptionDeServiceDeSuivi(
                service: self,
                nomDuDocument: "MangaUpdates",
                nature: .identifiantsDeCompte,
                preuveDeCle: nil,
                autorisation: nil,
                jeton: Self.adresseFixe("https://api.mangaupdates.com/v1/account/login"),
                api: Self.adresseFixe("https://api.mangaupdates.com/v1"),
                rafraichitSonJeton: false,
                echelleDeNote: 10
            )
        }
    }

    /// Service portant ce nom au document, nul si le document ne le liste pas.
    public static func portant(leNomDuDocument nom: String) -> ServiceDeSuivi? {
        allCases.first { $0.descriptif.nomDuDocument == nom }
    }

    /// Adresse constante de ce fichier.
    ///
    /// `URL(string:)` rend une valeur facultative, et le projet interdit de la
    /// forcer. Le repli est volontairement inutilisable : son schema n est pas
    /// `https`, donc la couche reseau refuse de s y connecter, et le test qui
    /// exige le transport chiffre sur les quatre services vire au rouge avant
    /// qu une faute de frappe n atteigne un appareil.
    private static func adresseFixe(_ texte: String) -> URL {
        URL(string: texte) ?? URL(fileURLWithPath: "/adresse-de-service-invalide")
    }
}

/// Ce qui identifie notre application aupres d un service.
///
/// Le type ne conforme pas a `Codable`, pour la meme raison que
/// `IdentifiantsDeSource` : un secret de client qui sait s encoder finit un
/// jour dans une sauvegarde ou dans `UserDefaults`. Il est fourni au
/// lancement et ne se persiste nulle part.
public struct ConfigurationDeServiceDeSuivi: Sendable, Hashable {
    /// Identifiant public de notre application chez le service.
    public let identifiantDeClient: String

    /// Secret de notre application, nul pour les services qui n en demandent
    /// pas.
    public let secretDeClient: String?

    /// Adresse par laquelle le navigateur revient vers l application.
    public let redirection: URL

    public init(identifiantDeClient: String, secretDeClient: String? = nil, redirection: URL) {
        self.identifiantDeClient = identifiantDeClient
        self.secretDeClient = secretDeClient
        self.redirection = redirection
    }
}

extension ConfigurationDeServiceDeSuivi: CustomStringConvertible, CustomDebugStringConvertible {
    /// Description caviardee, qui ne rend jamais le secret.
    public var description: String {
        "ConfigurationDeServiceDeSuivi(client: \(identifiantDeClient.isEmpty ? "absent" : "present"))"
    }

    public var debugDescription: String {
        description
    }
}

/// Ce que l application connait des quatre services au lancement.
///
/// Une entree absente veut dire que la version installee n a pas ete construite
/// avec les cles de ce service. La connexion est alors refusee par
/// `ErreurDeSuivi.serviceNonConfigure`, ce qui dit la cause, plutot que par un
/// echange de code qui echouerait plus loin avec un message du serveur.
public struct ConfigurationDesSuivis: Sendable, Hashable {
    private let entrees: [ServiceDeSuivi: ConfigurationDeServiceDeSuivi]

    public init(_ entrees: [ServiceDeSuivi: ConfigurationDeServiceDeSuivi] = [:]) {
        self.entrees = entrees
    }

    /// Aucune cle connue, l etat d une construction de developpement.
    public static let aucune = ConfigurationDesSuivis()

    /// Configuration du service, nulle quand la version installee ne la porte
    /// pas.
    public subscript(service: ServiceDeSuivi) -> ConfigurationDeServiceDeSuivi? {
        entrees[service]
    }

    /// Vrai quand ce service peut etre propose a la connexion.
    ///
    /// Un service configure avec un identifiant vide compte comme absent : une
    /// chaine vide passe la construction et se fait refuser par le serveur, ce
    /// qui reporte l erreur au pire endroit, apres l ouverture du navigateur.
    public func peutSeConnecter(_ service: ServiceDeSuivi) -> Bool {
        guard let entree = entrees[service], entree.identifiantDeClient.isEmpty == false else {
            return false
        }

        guard service.descriptif.nature == .codeDAutorisationAvecSecret else {
            return true
        }

        return (entree.secretDeClient?.isEmpty == false)
    }

    /// Services que cette version peut proposer, dans l ordre du document.
    public var servicesConfigures: [ServiceDeSuivi] {
        ServiceDeSuivi.allCases.filter(peutSeConnecter)
    }
}
