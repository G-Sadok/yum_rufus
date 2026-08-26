import Core
import Foundation

//
// SourceJellyfin
//
// La troisieme source distante du projet, sur l API REST de Jellyfin, tableau
// de la section 4.2 du cahier de developpement.
//
// Ce qui la distingue des deux precedentes tient en une phrase : Jellyfin n est
// pas un serveur de bandes dessinees. Komga et Kavita ne servent que cela, leur
// catalogue entier est lisible. Jellyfin sert d abord des films, des series et
// de la musique, et les livres n y sont qu une bibliotheque parmi d autres. Le
// tableau 4.2 le dit d un mot, filtrer sur le type de media livre, et ce filtre
// est la raison d etre de la moitie du code de cette source.
//
// Il est pose a deux endroits, et les deux comptent. A la racine, une
// bibliotheque dont le type de collection n est pas `books` n est jamais
// interrogee. Dans chaque liste, `includeItemTypes` dit au serveur ce qui est
// attendu, et le tri est refait a la reception : un serveur d une version
// voisine peut rendre autre chose que ce qui a ete demande, et un episode video
// glisse dans une liste de chapitres est un chapitre qui ne s ouvrira jamais.
//
// La lecture est l autre difference, et elle est structurelle. Komga et Kavita
// extraient les pages eux memes et les servent une par une. Jellyfin ne sait pas
// faire cela : il connait le fichier du livre, pas ce qu il y a dedans. Un
// chapitre est donc rapatrie en entier puis lu comme un conteneur local, ce qui
// est exactement la forme que `PageDistante` decrit avec son champ `entree`. La
// capacite `telechargement` n est pas un supplement pour cette source, c est sa
// condition d existence, et c est pourquoi elle est declaree.
//
// Les capacites offertes sont donc la recherche, la pagination et le
// telechargement. Les filtres n y sont pas : une serie est un dossier chez
// Jellyfin, un dossier ne porte ni genre ni statut editorial, et une requete
// filtree y rendrait toujours une liste vide. La progression distante n y est
// pas non plus : le serveur tient une progression par utilisateur, une cle d API
// n en designe aucun, et il n a de toute facon aucune notion de page dans un
// livre.
//

/// Source de contenu servie par un serveur Jellyfin.
public actor SourceJellyfin: SourceProvider {
    /// Ce que cette source sait reellement faire.
    public static let capacitesOffertes: SourceCapacites = [
        .recherche,
        .pagination,
        .telechargement,
    ]

    /// Nombre de series demandees par page de catalogue, par defaut.
    public static let tailleDePageParDefaut = 50

    /// Nombre de livres demandes par requete quand une serie est ouverte.
    ///
    /// Plus grand que la taille de page du catalogue : la liste des chapitres
    /// est rendue entiere, et chaque aller retour supplementaire se voit a
    /// l ouverture d une fiche.
    public static let tailleDePageDesLivres = 200

    /// Nombre maximal de requetes enchainees pour lister les livres d une serie.
    ///
    /// La borne existe pour qu un serveur qui compterait mal ses elements ne
    /// fasse pas tourner la boucle sans fin. A deux cents livres par requete,
    /// elle autorise cent mille chapitres dans une seule serie, ce qu aucune
    /// bibliotheque reelle n atteint.
    public static let maximumDeRequetesDeLivres = 500

    public nonisolated let id: SourceID
    public nonisolated let nom: String

    /// Adresse du serveur, sans le chemin de l API.
    public nonisolated let base: URL

    /// Nombre de series demandees par page de catalogue.
    public nonisolated let tailleDePage: Int

    public nonisolated var capacites: SourceCapacites {
        Self.capacitesOffertes
    }

    /// Ou sont ranges les conteneurs rapatries.
    ///
    /// Interne et non prive : la lecture vit dans un autre fichier.
    let cache: CacheDeConteneursJellyfin

    private let magasin: any MagasinDIdentifiants
    private let transport: any TransportHttp
    private let accepteLeHttpEnClair: Bool
    private var clientEnCache: ClientHttp?

    /// Les bibliotheques de livres du serveur, demandees une fois puis retenues.
    ///
    /// Interne et non privee : le catalogue vit dans un autre fichier. Un
    /// utilisateur n ajoute pas une bibliotheque pendant qu il parcourt son
    /// catalogue, et la redemander a chaque tranche doublerait le nombre de
    /// requetes du defilement.
    var bibliothequesEnCache: [String]?

    /// Les pages deja enumerees, par chapitre.
    ///
    /// Enumerer un chapitre veut dire rapatrier son fichier. Le refaire a chaque
    /// appel rapatrierait le meme conteneur a chaque retour au sommaire.
    var pagesRetenues: [String: [PageDistante]] = [:]

    /// Construit la source depuis sa configuration persistee.
    ///
    /// Rien n est lu ici, ni le trousseau ni le reseau. Un lancement ne paie donc
    /// pas la connexion aux serveurs que l utilisateur ne consultera pas.
    ///
    /// - Parameter dossierDeCache: ou ranger les conteneurs rapatries. Nul rend
    ///   le dossier de caches du systeme, propre a cette source.
    /// - Throws: `ErreurDeConfigurationDeSource.illisible` quand la
    ///   configuration ne porte aucune adresse.
    public init(
        id: SourceID = SourceID(),
        nom: String,
        configuration: ConfigurationDeSource,
        magasin: any MagasinDIdentifiants,
        transport: any TransportHttp = TransportURLSession(),
        tailleDePage: Int = SourceJellyfin.tailleDePageParDefaut,
        dossierDeCache: URL? = nil
    ) throws {
        guard let adresse = configuration.adresse else {
            throw ErreurDeConfigurationDeSource.illisible
        }

        self.id = id
        self.nom = nom
        base = configuration.chemin?.sansBlancs.map { adresse.appending(path: $0) } ?? adresse
        self.magasin = magasin
        self.transport = transport
        accepteLeHttpEnClair = configuration.accepteLeHttpEnClair
        self.tailleDePage = max(1, tailleDePage)
        cache = dossierDeCache.map(CacheDeConteneursJellyfin.init(dossier:))
            ?? CacheDeConteneursJellyfin.parDefaut(source: id)
    }

    // MARK: Protocole

    public func verifierConnexion() async -> EtatConnexion {
        do {
            // La verification passe par le catalogue et non par le point
            // d entree public du serveur : ce dernier repond a tout le monde,
            // et une cle d API fausse y passerait pour bonne. Le catalogue,
            // lui, prouve les trois choses qui comptent, que l adresse designe
            // un serveur Jellyfin, que la cle est acceptee, et que le compte
            // voit au moins ses bibliotheques.
            _ = try await series(tri: .parTitre, recherche: nil, page: 0, taille: 1)

            return .connecte
        } catch {
            return ErreurDeSource.depuis(error, source: nom).etatDeConnexion
        }
    }

    public func rechercher(_ requete: RequeteRecherche) async throws -> PageResultats<MangaDistant> {
        try exiger(.recherche)

        if requete.filtres.estVide == false {
            try exiger(.filtres)
        }
        if requete.langue != nil {
            try exiger(.plusieursLangues)
        }
        if requete.page > 0 {
            try exiger(.pagination)
        }

        return try await series(
            tri: .parTitre,
            recherche: requete.texte.sansBlancs,
            page: requete.page,
            taille: tailleDePage
        )
    }

    public func parcourir(_ section: SectionCatalogue, page: Int) async throws -> PageResultats<MangaDistant> {
        if page > 0 {
            try exiger(.pagination)
        }
        guard let tri = TriDeJellyfin(section) else {
            throw ErreurDeSource.sectionNonPriseEnCharge(section: section, source: nom)
        }

        return try await series(tri: tri, recherche: nil, page: page, taille: tailleDePage)
    }

    public func detailsManga(_ identifiant: String) async throws -> MangaDistant {
        let introuvable = ErreurDeSource.mangaIntrouvable(identifiant: identifiant)
        let element = try await element(identifiant, siIntrouvable: introuvable)

        guard element.estUnDossier else {
            // Un identifiant qui designe un livre, ou un film, ne designe pas
            // une serie. Le traduire quand meme ouvrirait une fiche dont la
            // liste de chapitres serait vide sans que rien ne dise pourquoi.
            throw introuvable
        }

        return element.mangaDistant(base: base)
    }

    public func chapitres(pour identifiant: String) async throws -> [ChapitreDistant] {
        do {
            let livres = try await tousLesLivres(deLaSerie: identifiant)

            return livres.enumerated().map { rang, livre in
                livre.chapitreDistant(ordre: rang, serie: identifiant)
            }
        } catch {
            throw traduire(error, siIntrouvable: .mangaIntrouvable(identifiant: identifiant))
        }
    }

    public func requeteImage(pour page: PageDistante) async throws -> URLRequest {
        if let entree = page.entree {
            // C est le cas normal chez Jellyfin, et non l exception : le serveur
            // ne sert pas les pages d un livre, il en sert le fichier. Toutes
            // les pages de cette source vivent donc dans un conteneur, et se
            // lisent par le protocole `DocumentLocal`.
            throw ErreurDeSource.pageNonAdressableParRequete(entree: entree)
        }

        do {
            return try await client().requeteBrute(page.emplacement)
        } catch {
            throw ErreurDeSource.depuis(error, source: nom)
        }
    }

    // MARK: Entretien

    /// Oublie le client, les bibliotheques et les chapitres enumeres.
    ///
    /// A appeler quand l utilisateur enregistre une nouvelle configuration :
    /// sans cela la source continuerait a presenter l ancienne cle d API jusqu au
    /// prochain lancement, et la verification de connexion echouerait alors que
    /// la saisie etait bonne.
    public func oublierLeClient() {
        clientEnCache = nil
        bibliothequesEnCache = nil
        pagesRetenues.removeAll()
    }

    // MARK: Elements

    /// Rend un element designe par son identifiant.
    ///
    /// Interne et non prive : la lecture s en sert pour retrouver le format du
    /// conteneur d un chapitre.
    ///
    /// - Throws: l erreur passee en parametre quand aucun element ne porte cet
    ///   identifiant, une erreur de source traduite sinon.
    func element(_ identifiant: String, siIntrouvable erreur: ErreurDeSource) async throws -> ElementDeJellyfin {
        do {
            let tranche = try await client().lire(
                TrancheDeJellyfin.self,
                chemin: CheminsJellyfin.elements,
                parametres: ParametresJellyfin.element(identifiant)
            )

            guard let trouve = tranche.elements.first else {
                throw erreur
            }

            return trouve
        } catch {
            throw traduire(error, siIntrouvable: erreur)
        }
    }

    /// Rend tous les livres d une serie, dans l ordre de titre de classement.
    ///
    /// La liste est demandee par tranches jusqu a ce que le decalage rejoigne le
    /// total annonce. Un chapitre manquant dans la liste est un chapitre que
    /// l utilisateur ne peut pas ouvrir, donc s arreter a la premiere tranche
    /// serait un bogue silencieux sur toute serie de plus de deux cents tomes.
    private func tousLesLivres(deLaSerie identifiant: String) async throws -> [ElementDeJellyfin] {
        let client = try await client()
        var recoltes: [ElementDeJellyfin] = []
        var depart = 0
        var requetes = 0

        while requetes < Self.maximumDeRequetesDeLivres {
            try Task.checkCancellation()

            let tranche = try await client.lire(
                TrancheDeJellyfin.self,
                chemin: CheminsJellyfin.elements,
                parametres: ParametresJellyfin.tranche(
                    portee: .livres(de: identifiant),
                    tri: .parTitre,
                    pagination: PaginationJellyfin(
                        depart: depart,
                        taille: Self.tailleDePageDesLivres
                    )
                )
            )

            // Le filtre envoye au serveur est double d un filtre local. Les deux
            // sont necessaires : le premier evite de rapatrier une liste
            // entiere pour la jeter, le second garantit le critere quand le
            // serveur ne respecte pas le premier.
            recoltes.append(contentsOf: tranche.elements.filter(\.estUnLivre))
            depart += tranche.elements.count
            requetes += 1

            guard tranche.elements.isEmpty == false, depart < (tranche.total ?? depart) else {
                return recoltes
            }
        }

        return recoltes
    }

    // MARK: Client

    /// Le client REST, construit au premier appel et retenu ensuite.
    ///
    /// Interne et non prive : le catalogue et la lecture vivent dans d autres
    /// fichiers et passent par le meme client, sans quoi ils liraient le
    /// trousseau une seconde fois pour la meme source.
    func client() async throws -> ClientHttp {
        if let clientEnCache {
            return clientEnCache
        }

        let identifiants = try await identifiants()
        let client = try ClientHttp(
            base: base,
            transport: transport,
            authentification: Self.authentification(identifiants, source: nom, appareil: id),
            accepteLeHttpEnClair: accepteLeHttpEnClair
        )
        clientEnCache = client

        return client
    }

    /// Les identifiants de la source, lus dans le trousseau.
    ///
    /// Un refus du trousseau devient un refus d identifiants. Les deux se
    /// reparent au meme endroit, la feuille de configuration, et c est
    /// exactement ce que `EtatConnexion.identifiantsInvalides` y ouvre.
    private func identifiants() async throws -> IdentifiantsDeSource {
        do {
            return try await magasin.identifiants(pour: id)
        } catch {
            throw ErreurDeSource.reseau(.authentificationRefusee, source: nom)
        }
    }

    /// Traduit les identifiants saisis en preuve d identite HTTP.
    ///
    /// Jellyfin est la seule source du projet a n accepter qu une seule forme.
    /// Le tableau 4.2 dit cle d API, et c est la seule qui soit acceptee ici.
    /// Un mot de passe ouvrirait une session utilisateur, qui expire, se
    /// renouvelle et compte comme une connexion dans les journaux du serveur :
    /// c est une autre source que celle qui a ete specifiee, pas une variante.
    /// Une source anonyme n existe pas non plus, Jellyfin ne servant rien sans
    /// preuve d identite.
    private static func authentification(
        _ identifiants: IdentifiantsDeSource,
        source: String,
        appareil: SourceID
    ) throws -> AuthentificationHttp {
        guard case let .cleDApi(cle) = identifiants else {
            throw ErreurDeSource.reseau(.authentificationRefusee, source: source)
        }

        return IdentiteJellyfin.authentification(cleDApi: cle, appareil: appareil)
    }

    // MARK: Traduction des erreurs

    /// Traduit une erreur, en nommant le cas introuvable quand c est lui.
    ///
    /// Un 404 sur une serie et un 404 sur un chapitre se reparent tous les deux
    /// par une analyse de la source, mais ils ne designent pas la meme chose a
    /// l ecran.
    func traduire(_ erreur: any Error, siIntrouvable remplacement: ErreurDeSource) -> ErreurDeSource {
        if let reseau = erreur as? ErreurReseau, reseau == .ressourceIntrouvable {
            return remplacement
        }

        return ErreurDeSource.depuis(erreur, source: nom)
    }
}
