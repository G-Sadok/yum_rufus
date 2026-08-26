import Core
import Foundation

//
// SourceKomga
//
// La premiere source distante du projet, sur l API REST de Komga, section 4.2
// du cahier de developpement.
//
// C est un acteur pour une seule raison, mais elle suffit : les identifiants
// sont lus une fois dans le trousseau puis retenus avec le client construit
// autour d eux. Sans isolation, deux ecrans qui interrogent la source au meme
// instant lanceraient deux lectures de trousseau concurrentes, et l appareil
// verrouille en ouvrirait deux boites de dialogue.
//
// Les capacites declarees sont la recherche, les filtres, la pagination, le
// telechargement et la progression distante. Elles correspondent une a une a ce
// que le serveur sait faire : `search`, `genre` et `status` sur la liste des
// series, la pagination de Spring, des pages servies par URL donc
// telechargeables, et un point d entree de progression de lecture.
//
// Le choix de la langue n est pas declare, et ce n est pas un oubli. Komga
// range une langue par serie, pas la meme serie en plusieurs langues. Declarer
// la capacite ferait afficher un selecteur qui ne changerait jamais rien.
//

/// Source de contenu servie par un serveur Komga.
public actor SourceKomga: SourceProvider {
    /// Ce que cette source sait reellement faire.
    public static let capacitesOffertes: SourceCapacites = [
        .recherche,
        .filtres,
        .pagination,
        .telechargement,
        .progressionDistante,
    ]

    /// Nombre de series demandees par page de catalogue, par defaut.
    public static let tailleDePageParDefaut = 50

    /// Nombre de livres demandes par requete quand la liste est parcourue.
    ///
    /// Plus grand que la taille de page du catalogue : la liste des chapitres
    /// est rendue entiere, et chaque aller retour supplementaire se voit a
    /// l ouverture d une fiche.
    public static let tailleDePageDesLivres = 200

    /// Nombre maximal de requetes enchainees pour lister les livres d une serie.
    ///
    /// La borne existe pour qu un serveur qui repondrait toujours `last: false`
    /// ne fasse pas tourner la boucle sans fin. A deux cents livres par requete,
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

    private let magasin: any MagasinDIdentifiants
    private let transport: any TransportHttp
    private let accepteLeHttpEnClair: Bool
    private var clientEnCache: ClientHttp?

    /// Construit la source depuis sa configuration persistee.
    ///
    /// Rien n est lu ici, ni le trousseau ni le reseau. Un lancement ne paie
    /// donc pas la connexion aux serveurs que l utilisateur ne consultera pas.
    ///
    /// - Throws: `ErreurDeConfigurationDeSource.illisible` quand la
    ///   configuration ne porte aucune adresse. C est l erreur que la feuille de
    ///   configuration sait traiter, et une source sans adresse ne se repare que
    ///   la.
    public init(
        id: SourceID = SourceID(),
        nom: String,
        configuration: ConfigurationDeSource,
        magasin: any MagasinDIdentifiants,
        transport: any TransportHttp = TransportURLSession(),
        tailleDePage: Int = SourceKomga.tailleDePageParDefaut
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
    }

    // MARK: Protocole

    public func verifierConnexion() async -> EtatConnexion {
        do {
            let client = try await client()
            _ = try await client.executer(client.requete(chemin: Self.cheminDuCompte))

            return .connecte
        } catch {
            // Une source injoignable est un etat, pas une erreur de
            // programmation. La traduction fait le tri entre un refus
            // d identifiants, qui ouvre la feuille de configuration, et une
            // panne de reseau, qui propose de relancer le test.
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

        var parametres = parametresDePage(requete.page)
        parametres.append(contentsOf: Self.parametresDeTri(.tout))

        if let texte = requete.texte.sansBlancs {
            parametres.append(URLQueryItem(name: "search", value: texte))
        }

        parametres.append(contentsOf: Self.parametresDeFiltre(requete.filtres))

        return try await series(parametres: parametres, page: requete.page)
    }

    public func parcourir(_ section: SectionCatalogue, page: Int) async throws -> PageResultats<MangaDistant> {
        if page > 0 {
            try exiger(.pagination)
        }
        guard section != .populaires else {
            // Komga ne mesure aucune popularite. Rendre le catalogue complet
            // sous ce nom serait un classement invente.
            throw ErreurDeSource.sectionNonPriseEnCharge(section: section, source: nom)
        }

        var parametres = parametresDePage(page)
        parametres.append(contentsOf: Self.parametresDeTri(section))

        return try await series(parametres: parametres, page: page)
    }

    public func detailsManga(_ identifiant: String) async throws -> MangaDistant {
        do {
            let serie = try await client().lire(
                SerieDeKomga.self,
                chemin: Self.cheminDeSerie(identifiant)
            )

            return serie.mangaDistant(base: base)
        } catch {
            throw traduire(error, siIntrouvable: .mangaIntrouvable(identifiant: identifiant))
        }
    }

    public func chapitres(pour identifiant: String) async throws -> [ChapitreDistant] {
        do {
            let livres = try await tousLesLivres(deLaSerie: identifiant)

            return livres.enumerated().map { rang, livre in
                livre.chapitreDistant(ordre: rang, identifiantSerie: identifiant)
            }
        } catch {
            throw traduire(error, siIntrouvable: .mangaIntrouvable(identifiant: identifiant))
        }
    }

    public func pages(pour chapitre: String) async throws -> [PageDistante] {
        do {
            let pages = try await client().lire(
                [PageDeLivreDeKomga].self,
                chemin: Self.cheminDesPages(chapitre)
            )

            // Le tri est fait ici et non laisse au serveur : la section 4.1 rend
            // les pages dans l ordre de lecture, et une seule version de serveur
            // qui rendrait la liste dans l ordre du systeme de fichiers suffirait
            // a melanger un chapitre entier.
            return pages
                .sorted { $0.number < $1.number }
                .map { $0.pageDistante(base: base, livre: chapitre) }
        } catch {
            throw traduire(error, siIntrouvable: .chapitreIntrouvable(identifiant: chapitre))
        }
    }

    public func requeteImage(pour page: PageDistante) async throws -> URLRequest {
        if let entree = page.entree {
            // Aucune page de Komga ne vit dans un conteneur : le serveur les
            // extrait lui meme. Le refus est la pour qu une page fabriquee
            // ailleurs et passee ici ne parte pas en requete sur une adresse
            // qui ne la designe pas.
            throw ErreurDeSource.pageNonAdressableParRequete(entree: entree)
        }

        do {
            return try await client().requeteBrute(page.emplacement)
        } catch {
            throw ErreurDeSource.depuis(error, source: nom)
        }
    }

    // MARK: Entretien

    /// Oublie le client et les identifiants retenus.
    ///
    /// A appeler quand l utilisateur enregistre une nouvelle configuration :
    /// sans cela la source continuerait a presenter l ancien mot de passe
    /// jusqu au prochain lancement, et la verification de connexion
    /// echouerait alors que la saisie etait bonne.
    public func oublierLeClient() {
        clientEnCache = nil
    }

    // MARK: Catalogue

    /// Interroge la liste des series et traduit la tranche rendue.
    private func series(parametres: [URLQueryItem], page: Int) async throws -> PageResultats<MangaDistant> {
        do {
            let tranche = try await client().lire(
                PageDeKomga<SerieDeKomga>.self,
                chemin: Self.cheminDesSeries,
                parametres: parametres
            )

            return PageResultats(
                elements: tranche.content.map { $0.mangaDistant(base: base) },
                page: tranche.number ?? page,
                ilResteDesPages: tranche.ilResteDesPages
            )
        } catch {
            throw ErreurDeSource.depuis(error, source: nom)
        }
    }

    /// Rend tous les livres d une serie, dans l ordre de numero.
    ///
    /// La liste est demandee page par page jusqu a ce que le serveur annonce la
    /// derniere. Un chapitre manquant dans la liste est un chapitre que
    /// l utilisateur ne peut pas ouvrir, donc s arreter a la premiere page
    /// serait un bogue silencieux sur toute serie de plus de deux cents tomes.
    private func tousLesLivres(deLaSerie identifiant: String) async throws -> [LivreDeKomga] {
        let client = try await client()
        var recoltes: [LivreDeKomga] = []
        var page = 0

        while page < Self.maximumDeRequetesDeLivres {
            try Task.checkCancellation()

            let tranche = try await client.lire(
                PageDeKomga<LivreDeKomga>.self,
                chemin: Self.cheminDesLivres(identifiant),
                parametres: Self.parametresDeLivres(page: page)
            )

            recoltes.append(contentsOf: tranche.content)

            guard tranche.ilResteDesPages, tranche.content.isEmpty == false else {
                return recoltes
            }

            page += 1
        }

        return recoltes
    }

    // MARK: Client

    /// Le client REST, construit au premier appel et retenu ensuite.
    ///
    /// Interne et non prive : la progression distante vit dans un autre fichier
    /// et passe par le meme client, sans quoi elle lirait le trousseau une
    /// seconde fois pour la meme source.
    func client() async throws -> ClientHttp {
        if let clientEnCache {
            return clientEnCache
        }

        let identifiants = try await identifiants()
        let client = try ClientHttp(
            base: base,
            transport: transport,
            authentification: Self.authentification(identifiants, source: nom),
            accepteLeHttpEnClair: accepteLeHttpEnClair
        )
        clientEnCache = client

        return client
    }

    /// Les identifiants de la source, lus dans le trousseau.
    ///
    /// Un refus du trousseau devient un refus d identifiants. Les deux se
    /// reparent au meme endroit, la feuille de configuration, et c est
    /// exactement ce que `EtatConnexion.identifiantsInvalides` y ouvre. Faire
    /// remonter le code brut du trousseau donnerait un echec inattendu, qui ne
    /// dit a l utilisateur ni la cause ni la sortie.
    private func identifiants() async throws -> IdentifiantsDeSource {
        do {
            return try await magasin.identifiants(pour: id)
        } catch {
            throw ErreurDeSource.reseau(.authentificationRefusee, source: nom)
        }
    }

    /// Traduit les identifiants saisis en preuve d identite HTTP.
    ///
    /// Komga accepte l authentification basique et une cle d API. Il n emet
    /// aucun jeton rafraichissable : une source configuree avec un jeton a ete
    /// remplie pour un autre serveur, et la seule sortie est de ressaisir les
    /// identifiants.
    private static func authentification(
        _ identifiants: IdentifiantsDeSource,
        source: String
    ) throws -> AuthentificationHttp {
        switch identifiants {
        case .aucun:
            return .aucune
        case let .basique(compte, motDePasse):
            return .basique(compte: compte, motDePasse: motDePasse)
        case let .cleDApi(cle):
            return .entete(nom: "X-API-Key", valeur: cle)
        case .jeton:
            throw ErreurDeSource.reseau(.authentificationRefusee, source: source)
        }
    }

    // MARK: Traduction des erreurs

    /// Traduit une erreur, en nommant le cas introuvable quand c est lui.
    ///
    /// Un 404 sur une serie et un 404 sur un chapitre se reparent tous les deux
    /// par une analyse de la source, mais ils ne designent pas la meme chose a
    /// l ecran. Les laisser tous les deux en `reseau(.ressourceIntrouvable)`
    /// afficherait le meme message pour une fiche disparue et pour un chapitre
    /// supprime.
    func traduire(_ erreur: any Error, siIntrouvable remplacement: ErreurDeSource) -> ErreurDeSource {
        if let reseau = erreur as? ErreurReseau, reseau == .ressourceIntrouvable {
            return remplacement
        }

        return ErreurDeSource.depuis(erreur, source: nom)
    }
}
