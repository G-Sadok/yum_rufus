import Core
import Foundation

//
// SourceKavita
//
// La deuxieme source distante du projet, sur l API REST de Kavita, tableau de
// la section 4.2 du cahier de developpement.
//
// Ce qui la distingue de Komga tient en un mot, jeton. Komga accepte un mot de
// passe ou une cle d API, deux preuves qui valent jusqu a ce que l utilisateur
// les change. Kavita emet un jeton JWT de courte duree, qu il faut renouveler
// pendant que l application tourne. Toute cette mecanique vit dans
// `SessionKavita`, et la source n en voit rien : elle demande un client, le
// client demande une preuve d identite, la session la fournit fraiche.
//
// C est un acteur pour la meme raison que la source Komga, plus une : le
// repertoire des chapitres deja ouverts y est retenu, et deux ecrans qui
// publient une progression au meme instant s en partagent les entrees au lieu
// de redemander deux fois au serveur les identifiants du meme chapitre.
//
// Les capacites declarees sont la recherche, la pagination, le telechargement,
// la progression distante et la veille de nouveautes, la liste des chapitres
// d une serie se relisant a la demande.
// Les filtres n y sont pas, et c est une decision,
// pas un oubli. La grammaire de filtre de Kavita designe ses champs et ses
// comparaisons par des ordinaux, et une source qui les inventerait rendrait des
// resultats qui ne correspondent pas a ce qui est demande. La section 4.1 dit
// qu une capacite est un engagement : mieux vaut refuser un filtre que servir
// une liste fausse. Le choix de la langue n est pas declare non plus, Kavita
// rangeant une langue par serie et non la meme serie en plusieurs langues.
//

/// Source de contenu servie par un serveur Kavita.
public actor SourceKavita: SourceProvider {
    /// Ce que cette source sait reellement faire.
    public static let capacitesOffertes: SourceCapacites = [
        .recherche,
        .pagination,
        .telechargement,
        .progressionDistante,
        .veilleDeNouveautes,
    ]

    /// Nombre de series demandees par page de catalogue, par defaut.
    public static let tailleDePageParDefaut = 50

    public nonisolated let id: SourceID
    public nonisolated let nom: String

    /// Adresse du serveur, sans le chemin de l API.
    public nonisolated let base: URL

    /// Nombre de series demandees par page de catalogue.
    public nonisolated let tailleDePage: Int

    public nonisolated var capacites: SourceCapacites {
        Self.capacitesOffertes
    }

    /// La session qui tient le jeton et le renouvelle.
    ///
    /// Interne et non privee, pour la meme raison que `client()` : le catalogue
    /// et la progression vivent dans d autres fichiers et ont besoin de la cle
    /// d API que la session retient, sans quoi les couvertures et les pages
    /// partiraient sans elle.
    let session: SessionKavita

    private let transport: any TransportHttp
    private let accepteLeHttpEnClair: Bool
    private var clientEnCache: ClientHttp?

    /// Ce que la source sait des chapitres deja ouverts.
    ///
    /// Les identifiants de volume, de serie et de bibliotheque d un chapitre ne
    /// changent jamais, et la publication de progression en a besoin a chaque
    /// tourne de page. Les redemander a chaque publication doublerait le nombre
    /// de requetes d une lecture.
    private var reperes: [String: RepereDeChapitreKavita] = [:]

    /// Construit la source depuis sa configuration persistee.
    ///
    /// Rien n est lu ici, ni le trousseau ni le reseau. La connexion elle meme
    /// est repoussee a la premiere requete : un lancement ne paie donc pas
    /// l ouverture de session des serveurs que l utilisateur ne consultera pas.
    ///
    /// - Throws: `ErreurDeConfigurationDeSource.illisible` quand la
    ///   configuration ne porte aucune adresse.
    public init(
        id: SourceID = SourceID(),
        nom: String,
        configuration: ConfigurationDeSource,
        magasin: any MagasinDIdentifiants,
        transport: any TransportHttp = TransportURLSession(),
        tailleDePage: Int = SourceKavita.tailleDePageParDefaut,
        maintenant: @escaping @Sendable () -> Date = Date.init
    ) throws {
        guard let adresse = configuration.adresse else {
            throw ErreurDeConfigurationDeSource.illisible
        }

        self.id = id
        self.nom = nom
        base = configuration.chemin?.sansBlancs.map { adresse.appending(path: $0) } ?? adresse
        self.transport = transport
        accepteLeHttpEnClair = configuration.accepteLeHttpEnClair
        self.tailleDePage = max(1, tailleDePage)
        session = SessionKavita(
            id: id,
            base: base,
            magasin: magasin,
            transport: transport,
            accepteLeHttpEnClair: configuration.accepteLeHttpEnClair,
            maintenant: maintenant
        )
    }

    // MARK: Protocole

    public func verifierConnexion() async -> EtatConnexion {
        do {
            // La verification passe par le catalogue et non par un point
            // d entree dedie : elle prouve alors les deux choses qui comptent,
            // que la session s ouvre et que l adresse designe bien un serveur
            // Kavita. Un point d entree qui ne rendrait qu un etat de sante
            // repondrait aussi bien a un serveur sans aucune bibliotheque
            // lisible par ce compte.
            _ = try await series(tri: .parTitre, page: 0, taille: 1)

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

        guard let texte = requete.texte.sansBlancs else {
            // Une recherche sans texte est le catalogue complet. Le servir par
            // le point d entree pagine plutot que par celui de recherche evite
            // de rendre une liste tronquee la ou l utilisateur a simplement
            // efface sa saisie.
            return try await series(tri: .parTitre, page: requete.page, taille: tailleDePage)
        }

        return try await rechercher(texte: texte, page: requete.page)
    }

    public func parcourir(_ section: SectionCatalogue, page: Int) async throws -> PageResultats<MangaDistant> {
        if page > 0 {
            try exiger(.pagination)
        }
        guard let tri = TriDeKavita(section) else {
            throw ErreurDeSource.sectionNonPriseEnCharge(section: section, source: nom)
        }

        return try await series(tri: tri, page: page, taille: tailleDePage)
    }

    public func detailsManga(_ identifiant: String) async throws -> MangaDistant {
        let serie = try Self.numerique(identifiant, siInvalide: .mangaIntrouvable(identifiant: identifiant))

        do {
            let client = try client()
            let fiche = try await client.lire(SerieDeKavita.self, chemin: CheminsKavita.serie(serie))
            // Les metadonnees vivent derriere un second point d entree. Leur
            // absence ne fait pas echouer la fiche : un serveur qui les refuse
            // au compte courant laisse quand meme lire la serie, et une fiche
            // sans resume vaut mieux qu une serie qui ne s ouvre pas.
            let metadonnees = try? await client.lire(
                MetadonneesDeSerieDeKavita.self,
                chemin: CheminsKavita.metadonneesDeSerie,
                parametres: ParametresKavita.serie(serie)
            )

            return await fiche.mangaDistant(
                base: base,
                cleDApi: session.cleDApi(),
                metadonnees: metadonnees
            )
        } catch {
            throw traduire(error, siIntrouvable: .mangaIntrouvable(identifiant: identifiant))
        }
    }

    public func chapitres(pour identifiant: String) async throws -> [ChapitreDistant] {
        let serie = try Self.numerique(identifiant, siInvalide: .mangaIntrouvable(identifiant: identifiant))

        do {
            let volumes = try await client().lire(
                [VolumeDeKavita].self,
                chemin: CheminsKavita.volumes,
                parametres: ParametresKavita.serie(serie)
            )

            return OrdreDesChapitresKavita.ordonner(volumes).enumerated().map { rang, place in
                place.chapitreDistant(ordre: rang, serie: identifiant)
            }
        } catch {
            throw traduire(error, siIntrouvable: .mangaIntrouvable(identifiant: identifiant))
        }
    }

    public func pages(pour chapitre: String) async throws -> [PageDistante] {
        let repere = try await repere(deChapitre: chapitre)

        guard repere.nombreDePages > 0 else {
            // Zero page veut dire que le serveur n a pas encore analyse le
            // fichier. Une liste vide le dit sans inventer de pages qui
            // rendraient toutes une erreur a l affichage.
            return []
        }

        let cleDApi = await session.cleDApi()

        do {
            return try (0..<repere.nombreDePages).map { index in
                try PageDistante(
                    identifiantChapitre: chapitre,
                    // Kavita indexe ses pages a partir de zero, comme le
                    // modele. Aucune conversion, contrairement a Komga.
                    index: index,
                    emplacement: AdressesKavita.page(
                        base: base,
                        chapitre: repere.chapitre,
                        index: index,
                        cleDApi: cleDApi
                    )
                )
            }
        } catch {
            throw ErreurDeSource.depuis(error, source: nom)
        }
    }

    public func requeteImage(pour page: PageDistante) async throws -> URLRequest {
        if let entree = page.entree {
            // Aucune page de Kavita ne vit dans un conteneur : le serveur les
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

    /// Oublie la session, les identifiants et les chapitres retenus.
    ///
    /// A appeler quand l utilisateur enregistre une nouvelle configuration :
    /// sans cela la source continuerait a presenter le jeton de l ancien compte
    /// jusqu au prochain lancement, et la verification de connexion echouerait
    /// alors que la saisie etait bonne.
    public func oublierLaSession() async {
        clientEnCache = nil
        reperes.removeAll()
        await session.oublier()
    }

    // MARK: Chapitres

    /// Ce que la source sait d un chapitre, demande une fois puis retenu.
    func repere(deChapitre identifiant: String) async throws -> RepereDeChapitreKavita {
        if let connu = reperes[identifiant] {
            return connu
        }

        let chapitre = try Self.numerique(
            identifiant,
            siInvalide: .chapitreIntrouvable(identifiant: identifiant)
        )

        do {
            let info = try await client().lire(
                InfoDeChapitreDeKavita.self,
                chemin: CheminsKavita.infoDeChapitre,
                parametres: ParametresKavita.chapitre(chapitre)
            )
            let repere = info.repere(chapitre: chapitre)
            reperes[identifiant] = repere

            return repere
        } catch {
            throw traduire(error, siIntrouvable: .chapitreIntrouvable(identifiant: identifiant))
        }
    }

    /// Traduit un identifiant du modele vers celui du serveur.
    ///
    /// Kavita numerote ses series et ses chapitres. Un identifiant qui n est
    /// pas un nombre ne designe rien chez lui, et le refuser ici evite une
    /// requete dont la reponse serait de toute facon un 404.
    private static func numerique(_ texte: String, siInvalide erreur: ErreurDeSource) throws -> Int {
        guard let valeur = Int(texte) else {
            throw erreur
        }

        return valeur
    }

    // MARK: Client

    /// Le client REST, construit au premier appel et retenu ensuite.
    ///
    /// Interne et non prive : la progression distante vit dans un autre fichier
    /// et passe par le meme client, donc par la meme session.
    func client() throws -> ClientHttp {
        if let clientEnCache {
            return clientEnCache
        }

        let client = try ClientHttp(
            base: base,
            transport: transport,
            identite: session,
            accepteLeHttpEnClair: accepteLeHttpEnClair
        )
        clientEnCache = client

        return client
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

/// Ce que la source retient d un chapitre deja ouvert.
///
/// Les quatre identifiants ne changent jamais pour un chapitre donne, et la
/// publication de progression a besoin des quatre. Le nombre de pages, lui, sert
/// a borner la page envoyee et a decider si le chapitre est lu.
struct RepereDeChapitreKavita: Sendable, Hashable {
    let chapitre: Int
    let volume: Int?
    let serie: Int?
    let bibliotheque: Int?
    let nombreDePages: Int
}
