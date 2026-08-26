import Core
import Foundation

//
// SourceOpds
//
// La quatrieme source distante du projet, sur les catalogues ouverts OPDS,
// tableau de la section 4.2 du cahier de developpement.
//
// Elle ne ressemble a aucune des trois precedentes, et il faut le dire tout de
// suite. Komga, Kavita et Jellyfin sont des API : leurs chemins sont connus,
// leurs pages sont numerotees, et une source sait ou aller chercher la
// deuxieme page d une liste. OPDS n est pas une API, c est un format de
// document. Un catalogue publie un flux, ce flux porte des liens, et le seul
// moyen d atteindre la suite est de suivre le lien `next` que le flux publie.
// Rien n autorise a fabriquer une adresse de page.
//
// Cette contrainte decide de toute la structure. La pagination du protocole de
// la section 4.1 est numerotee, celle d OPDS est chainee, et le rapprochement
// des deux est le parcours de `ParcoursOpds` : les adresses deja atteintes sont
// retenues, et une page jamais visitee s atteint en suivant les liens depuis la
// derniere connue. C est le deuxieme critere de la fonctionnalite.
//
// Les capacites declarees sont la pagination et le telechargement, et rien de
// plus. Chacune des quatre absences a une raison.
//
// La recherche n est pas declaree, et c est le point le plus discutable de
// cette source. OPDS la definit, mais par un document OpenSearch publie a part,
// que tous les catalogues ne servent pas. Une capacite est un engagement : une
// source qui declare la recherche doit la servir, toujours. La declarer ferait
// afficher un champ de recherche qui echouerait sur un catalogue sur deux, ce
// qui est pire que de ne pas l offrir. Le jour ou la capacite pourra etre
// declaree par catalogue et non par type de source, elle le sera.
//
// Les filtres ne sont pas declares parce qu OPDS n a pas de notion de filtre.
// Les langues ne le sont pas parce qu un catalogue ne publie pas la meme serie
// en plusieurs langues, il publie des flux distincts. La progression distante
// ne l est pas parce que le protocole ne prevoit aucun moyen d ecrire quoi que
// ce soit sur le serveur.
//

/// Source de contenu servie par un catalogue OPDS, en version 1.2 ou 2.0.
public actor SourceOpds: SourceProvider {
    /// Ce que cette source sait reellement faire.
    public static let capacitesOffertes: SourceCapacites = [
        .pagination,
        .telechargement,
    ]

    /// Nombre maximal de flux enchaines pour lister les chapitres d une serie.
    ///
    /// La borne existe pour qu un catalogue dont le lien `next` boucle sur lui
    /// meme ne fasse pas tourner le parcours sans fin. Un flux OPDS porte
    /// couramment quelques dizaines d entrees, cinq cents flux autorisent donc
    /// largement la plus longue serie qu une bibliotheque reelle contienne.
    public static let maximumDeFluxEnchaines = 500

    /// Nom de famille du cache de conteneurs de cette source.
    static let familleDeCache = "Opds"

    public nonisolated let id: SourceID
    public nonisolated let nom: String

    /// Adresse du flux racine du catalogue.
    public nonisolated let racine: URL

    public nonisolated var capacites: SourceCapacites {
        Self.capacitesOffertes
    }

    /// Ou sont ranges les conteneurs rapatries.
    ///
    /// Interne et non prive : la lecture vit dans un autre fichier.
    let cache: CacheDeConteneursDistants

    /// Vrai quand l utilisateur a confirme une adresse en clair.
    ///
    /// Interne et non prive : le parcours verifie chaque lien du catalogue avec
    /// la meme regle que la configuration.
    let accepteLeHttpEnClair: Bool

    private let magasin: any MagasinDIdentifiants
    private let transport: any TransportHttp
    private var clientEnCache: ClientHttp?

    /// Les adresses de flux deja atteintes, par parcours.
    ///
    /// Interne et non privee : le parcours vit dans un autre fichier. C est la
    /// memoire qui rend la pagination numerotee possible sur un protocole qui
    /// ne numerote rien.
    var adressesDeParcours: [String: [URL]] = [:]

    /// Les series deja vues en parcourant le catalogue.
    ///
    /// Un flux de serie ne porte que son titre : les auteurs, le resume et les
    /// genres vivent dans l entree du flux parent, pas dans le flux enfant.
    /// Sans cette memoire, ouvrir une fiche depuis le catalogue perdrait tout
    /// ce que le catalogue venait d afficher.
    var seriesRetenues: [String: MangaDistant] = [:]

    /// Ce qu il faut savoir pour lire un chapitre, par identifiant.
    var chapitresRetenus: [String: DescripteurDeChapitreOpds] = [:]

    /// Les pages deja enumerees, par chapitre.
    var pagesRetenues: [String: [PageDistante]] = [:]

    /// L adresse de depart de chaque section, une fois trouvee dans la racine.
    ///
    /// Sans elle, chaque page de la section des nouveautes couterait une lecture
    /// du flux racine en plus de la sienne, pour retrouver un lien qui ne change
    /// pas pendant une session.
    var sectionsRetenues: [SectionCatalogue: URL] = [:]

    /// Construit la source depuis sa configuration persistee.
    ///
    /// Rien n est lu ici, ni le trousseau ni le reseau. Un lancement ne paie
    /// donc pas la connexion aux catalogues que l utilisateur ne consultera pas.
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
        dossierDeCache: URL? = nil
    ) throws {
        guard let adresse = configuration.adresse else {
            throw ErreurDeConfigurationDeSource.illisible
        }

        self.id = id
        self.nom = nom
        racine = configuration.chemin?.sansBlancs.map { adresse.appending(path: $0) } ?? adresse
        self.magasin = magasin
        self.transport = transport
        accepteLeHttpEnClair = configuration.accepteLeHttpEnClair
        cache = dossierDeCache.map(CacheDeConteneursDistants.init(dossier:))
            ?? CacheDeConteneursDistants.parDefaut(famille: Self.familleDeCache, source: id)
    }

    // MARK: Protocole

    public func verifierConnexion() async -> EtatConnexion {
        do {
            // La verification lit le flux racine, et non une adresse publique du
            // serveur. Elle prouve ainsi les trois choses qui comptent : que
            // l adresse designe bien un catalogue OPDS, que les identifiants
            // sont acceptes, et que le document rendu s analyse.
            _ = try await flux(racine)

            return .connecte
        } catch {
            return ErreurDeSource.depuis(error, source: nom).etatDeConnexion
        }
    }

    public func rechercher(_ requete: RequeteRecherche) async throws -> PageResultats<MangaDistant> {
        // Le refus est explicite et non un resultat vide. Un catalogue OPDS ne
        // publie pas toujours de document OpenSearch, la capacite n est donc pas
        // declaree, et l interface n a pas a offrir ce champ.
        try exiger(.recherche)

        return PageResultats(elements: [], page: requete.page)
    }

    public func parcourir(_ section: SectionCatalogue, page: Int) async throws -> PageResultats<MangaDistant> {
        if page > 0 {
            try exiger(.pagination)
        }

        let depart = try await depart(de: section)

        do {
            guard let atteint = try await parcourir(depuis: depart, page: page) else {
                return PageResultats(elements: [], page: max(0, page))
            }

            let series = atteint.flux.series.compactMap { entree in
                mangaDistant(entree, relativement: atteint.adresse)
            }
            series.forEach { seriesRetenues[$0.identifiant] = $0 }

            return PageResultats(
                elements: series,
                page: max(0, page),
                ilResteDesPages: atteint.flux.suivante != nil
            )
        } catch {
            throw ErreurDeSource.depuis(error, source: nom)
        }
    }

    public func detailsManga(_ identifiant: String) async throws -> MangaDistant {
        if let connue = seriesRetenues[identifiant] {
            return connue
        }

        let introuvable = ErreurDeSource.mangaIntrouvable(identifiant: identifiant)

        do {
            let adresse = try adresseDeSource(identifiant)
            let flux = try await flux(adresse)

            // Le flux d une serie ne porte que son titre. Les auteurs et le
            // resume vivent dans l entree du catalogue parent, que cet appel n a
            // pas sous la main : il rend donc ce qui est certain, et rien de
            // plus. Une fiche ouverte depuis le catalogue passe, elle, par la
            // memoire des series deja vues et garde tout.
            let manga = MangaDistant(
                identifiant: identifiant,
                titre: flux.titre ?? identifiant,
                nombreChapitres: flux.suivante == nil ? flux.chapitres.count : nil
            )
            seriesRetenues[identifiant] = manga

            return manga
        } catch {
            throw traduire(error, siIntrouvable: introuvable)
        }
    }

    public func chapitres(pour identifiant: String) async throws -> [ChapitreDistant] {
        do {
            let entrees = try await toutesLesEntrees(deLaSerie: identifiant)

            return entrees.enumerated().compactMap { rang, atteinte in
                chapitreDistant(atteinte, serie: identifiant, ordre: rang)
            }
        } catch {
            throw traduire(error, siIntrouvable: .mangaIntrouvable(identifiant: identifiant))
        }
    }

    public func requeteImage(pour page: PageDistante) async throws -> URLRequest {
        if let entree = page.entree {
            // La page vit dans un conteneur rapatrie, ce qui est le cas de tout
            // catalogue qui ne publie pas la diffusion page par page. Elle se lit
            // par le protocole `DocumentLocal`, jamais par une requete.
            throw ErreurDeSource.pageNonAdressableParRequete(entree: entree)
        }

        do {
            try verifier(page.emplacement)

            return try await client().requeteBrute(page.emplacement)
        } catch {
            throw ErreurDeSource.depuis(error, source: nom)
        }
    }

    // MARK: Entretien

    /// Oublie le client, les adresses parcourues et tout ce qui a ete retenu.
    ///
    /// A appeler quand l utilisateur enregistre une nouvelle configuration :
    /// sans cela la source continuerait a presenter l ancien mot de passe
    /// jusqu au prochain lancement, et la verification de connexion echouerait
    /// alors que la saisie etait bonne.
    public func oublierLeClient() {
        clientEnCache = nil
        adressesDeParcours.removeAll()
        seriesRetenues.removeAll()
        chapitresRetenus.removeAll()
        pagesRetenues.removeAll()
    }

    // MARK: Client

    /// Le client, construit au premier appel et retenu ensuite.
    ///
    /// Interne et non prive : le parcours et la lecture vivent dans d autres
    /// fichiers et passent par le meme client, sans quoi ils liraient le
    /// trousseau une seconde fois pour la meme source.
    func client() async throws -> ClientHttp {
        if let clientEnCache {
            return clientEnCache
        }

        let identifiants = try await identifiants()
        let client = try ClientHttp(
            base: racine,
            transport: transport,
            authentification: Self.authentification(identifiants),
            accepteLeHttpEnClair: accepteLeHttpEnClair
        )
        clientEnCache = client

        return client
    }

    /// Les identifiants de la source, lus dans le trousseau.
    private func identifiants() async throws -> IdentifiantsDeSource {
        do {
            return try await magasin.identifiants(pour: id)
        } catch {
            throw ErreurDeSource.reseau(.authentificationRefusee, source: nom)
        }
    }

    /// Traduit les identifiants saisis en preuve d identite HTTP.
    ///
    /// Le tableau 4.2 ne nomme aucune authentification pour OPDS, et la norme
    /// non plus : un catalogue est ouvert par definition. Les catalogues
    /// personnels sont pourtant proteges, et tous le font de la meme facon, par
    /// l authentification basique de HTTP. C est le troisieme critere de la
    /// fonctionnalite, et c est la seule forme acceptee ici avec l absence
    /// d identifiants. Une cle d API se pose dans un entete dont seul le serveur
    /// qui l a emise connait le nom, ce qu un catalogue ouvert ne definit pas.
    private static func authentification(_ identifiants: IdentifiantsDeSource) -> AuthentificationHttp {
        switch identifiants {
        case let .basique(compte, motDePasse):
            .basique(compte: compte, motDePasse: motDePasse)
        default:
            .aucune
        }
    }

    // MARK: Traduction des erreurs

    /// Traduit une erreur, en nommant le cas introuvable quand c est lui.
    func traduire(_ erreur: any Error, siIntrouvable remplacement: ErreurDeSource) -> ErreurDeSource {
        if let reseau = erreur as? ErreurReseau, reseau == .ressourceIntrouvable {
            return remplacement
        }

        return ErreurDeSource.depuis(erreur, source: nom)
    }
}
