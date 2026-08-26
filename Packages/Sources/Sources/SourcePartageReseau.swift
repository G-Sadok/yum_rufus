import Archive
import Core
import Foundation
import ImagePipeline

//
// SourcePartageReseau
//
// La source de contenu commune aux trois partages du tableau 4.2. Une seule
// pour les trois, parce qu un partage SMB, un export NFS et un dossier WebDAV ne
// different que par la facon de lister un dossier et de lire une plage
// d octets : c est exactement ce que `PartageReseau` isole, et tout ce qui vient
// au dessus, l analyse a deux niveaux, la lecture en flux, la reprise apres
// coupure, est le meme code pour les trois. Trois sources auraient donne trois
// comportements et trois jeux de bogues.
//
// Ce qui distingue cette source des quatre precedentes tient au chemin que
// prennent les octets d une page.
//
// Komga et Kavita servent une page par requete : leurs `PageDistante` portent
// une adresse, et la chaine d images la demande elle meme. Jellyfin et OPDS ne
// savent pas ouvrir un conteneur, ils rapatrient donc le fichier entier et
// designent une entree dans un fichier local. Un partage reseau ne fait ni l un
// ni l autre : il sait lire une plage d octets a l interieur du fichier, donc il
// n a aucune raison de le copier, et c est le premier critere de la
// fonctionnalite. Les octets d une page se demandent a la source, par
// `donnees(page:)`, et jamais par une requete.
//
// La consequence est que `requeteImage(pour:)` refuse toujours. Ce refus est
// exact et non un manque : une page de CBZ sur un partage SMB n a pas d adresse,
// et en fabriquer une obligerait a inventer un schema d URL que chaque couche
// devrait ensuite savoir defaire.
//
// Les capacites declarees sont la recherche et la pagination, comme pour un
// dossier local, et pour les memes raisons : un partage sait filtrer ses titres
// et servir sa liste par tranches, il ne connait ni genre, ni langue, ni
// progression cote serveur. Le telechargement n est pas declare non plus, et
// c est le sujet de cette source : elle ne telecharge pas, elle lit.
//

/// Source de contenu posee sur un partage reseau.
public actor SourcePartageReseau: SourceProvider {
    /// Ce que cette source sait reellement faire.
    public static let capacitesOffertes: SourceCapacites = [.recherche, .pagination]

    /// Nombre de series rendues par page de catalogue, par defaut.
    public static let tailleDePageParDefaut = 60

    /// Nom de famille du cache de conteneurs de cette source.
    static let familleDeCache = "PartageReseau"

    public nonisolated let id: SourceID
    public nonisolated let nom: String

    /// Nombre de series rendues par page de catalogue.
    public nonisolated let tailleDePage: Int

    public nonisolated var capacites: SourceCapacites {
        Self.capacitesOffertes
    }

    /// Le partage lui meme. Interne et non prive : la lecture des pages vit
    /// dans un autre fichier et passe par le meme partage.
    let partage: any PartageReseau

    /// Adresse qui identifie le partage, reprise par les pages.
    ///
    /// Elle ne sert jamais a demander quoi que ce soit : les octets passent par
    /// le partage. Elle sert a ce que deux pages de deux partages differents ne
    /// se confondent pas dans un cache indexe par emplacement.
    let adresse: URL

    let reglages: ReglagesDeFlux
    let cache: CacheDeConteneursDistants

    private let analyseur: AnalyseurDePartage
    private var analyseEnCache: AnalyseDeDossier?

    var conteneurs: [String: ConteneurDePartage] = [:]
    var pagesRetenues: [String: [PageDistante]] = [:]

    /// Construit la source sur un partage deja ouvert.
    ///
    /// Rien n est lu ici, ni le reseau ni le disque. Un lancement ne paie donc
    /// pas l analyse des partages que l utilisateur ne consultera pas.
    public init(
        id: SourceID = SourceID(),
        nom: String,
        partage: any PartageReseau,
        adresse: URL,
        tailleDePage: Int = SourcePartageReseau.tailleDePageParDefaut,
        reglages: ReglagesDeFlux = .parDefaut,
        analyseur: AnalyseurDePartage = AnalyseurDePartage(),
        dossierDeCache: URL? = nil
    ) {
        self.id = id
        self.nom = nom
        self.partage = partage
        self.adresse = adresse
        self.tailleDePage = max(1, tailleDePage)
        self.reglages = reglages
        self.analyseur = analyseur
        cache = dossierDeCache.map(CacheDeConteneursDistants.init(dossier:))
            ?? CacheDeConteneursDistants.parDefaut(famille: Self.familleDeCache, source: id)
    }

    // MARK: Protocole

    public func verifierConnexion() async -> EtatConnexion {
        do {
            _ = try await partage.lister("")

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

        let recherche = Self.normaliser(requete.texte)
        let series = try await analyse().series.filter { serie in
            recherche.isEmpty || Self.normaliser(serie.titre).contains(recherche)
        }

        return decouper(series.map(Self.mangaDistant), page: requete.page)
    }

    public func parcourir(_ section: SectionCatalogue, page: Int) async throws -> PageResultats<MangaDistant> {
        if page > 0 {
            try exiger(.pagination)
        }

        let series = try await analyse().series

        switch section {
        case .tout:
            // Deja triees selon l ordre naturel des titres par l analyse.
            return decouper(series.map(Self.mangaDistant), page: page)
        case .recentes:
            let recentes = series.sorted { gauche, droite in
                (gauche.dateModification ?? .distantPast) > (droite.dateModification ?? .distantPast)
            }

            return decouper(recentes.map(Self.mangaDistant), page: page)
        case .populaires:
            // Un partage reseau ne mesure aucune popularite. Rendre la liste
            // complete sous ce nom serait un classement invente.
            throw ErreurDeSource.sectionNonPriseEnCharge(section: section, source: nom)
        }
    }

    public func detailsManga(_ identifiant: String) async throws -> MangaDistant {
        guard let serie = try await analyse().serie(identifiant) else {
            throw ErreurDeSource.mangaIntrouvable(identifiant: identifiant)
        }

        return Self.mangaDistant(serie)
    }

    public func chapitres(pour identifiant: String) async throws -> [ChapitreDistant] {
        guard let serie = try await analyse().serie(identifiant) else {
            throw ErreurDeSource.mangaIntrouvable(identifiant: identifiant)
        }

        return serie.chapitres.map { Self.chapitreDistant($0, serie: serie) }
    }

    public func pages(pour chapitre: String) async throws -> [PageDistante] {
        if let connues = pagesRetenues[chapitre] {
            return connues
        }

        let trouve = try await chapitreLocal(chapitre)

        do {
            let pages = switch trouve.forme {
            case .dossierDImages:
                try await pagesPosees(dans: trouve)
            case let .archive(format):
                try await pagesDArchive(trouve, format: format)
            }
            pagesRetenues[chapitre] = pages

            return pages
        } catch {
            throw ErreurDeSource.depuis(error, source: nom)
        }
    }

    public func requeteImage(pour page: PageDistante) async throws -> URLRequest {
        // Aucune page d un partage reseau ne s obtient par une requete. Les
        // octets se lisent par plages, et c est `donnees(page:)` qui les rend.
        throw ErreurDeSource.pageNonAdressableParRequete(entree: page.entree ?? page.emplacement.lastPathComponent)
    }

    // MARK: Octets d une page

    /// Rend les octets bruts d une page, lus en flux sur le partage.
    ///
    /// Pour un chapitre range dans un CBZ, seuls l index central et les octets
    /// de l entree demandee traversent le reseau. Le fichier n est jamais copie,
    /// meme partiellement, sur le disque de l appareil.
    ///
    /// - Throws: `ErreurDeSource`, dans le cas nomme qui correspond a ce qui
    ///   s est passe. Une coupure de connexion y arrive sous `reseau`, dont le
    ///   message nomme la cause et indique la sortie ; relancer le meme appel
    ///   reprend ou la lecture s etait arretee.
    public func donnees(page: PageDistante) async throws -> Data {
        let trouve = try await chapitreLocal(page.identifiantChapitre)

        do {
            switch trouve.forme {
            case .dossierDImages:
                guard let entree = page.entree else {
                    throw ErreurDeSource.pageNonAdressableParRequete(entree: page.emplacement.lastPathComponent)
                }

                return try await octets(de: CheminDePartage.joindre(trouve.identifiant, entree))
            case let .archive(format) where ConteneurDePartage.litEnFlux(format):
                return try await octetsEnFlux(de: trouve, index: page.index)
            case let .archive(format):
                return try await octetsApresRapatriement(de: trouve, format: format, page: page)
            }
        } catch {
            throw ErreurDeSource.depuis(error, source: nom)
        }
    }

    /// Nombre d octets reellement transmis par le partage pour ce chapitre.
    ///
    /// C est la mesure du premier critere. Elle ne compte que ce qui a traverse
    /// le reseau, jamais ce que l appelant a lu : relire une page deja rapatriee
    /// ne l augmente pas.
    public func octetsRapatries(pour chapitre: String) async -> UInt64 {
        guard let conteneur = conteneurs[chapitre] else {
            return 0
        }

        return await conteneur.octetsRapatries
    }

    // MARK: Analyse

    /// Rend l analyse du partage, en la calculant au premier appel.
    public func analyse() async throws -> AnalyseDeDossier {
        if let analyseEnCache {
            return analyseEnCache
        }

        let resultat = try await analyseur.analyser(partage)
        analyseEnCache = resultat

        return resultat
    }

    /// Relance l analyse du partage et rend le resultat.
    @discardableResult
    public func reanalyser() async throws -> AnalyseDeDossier {
        analyseEnCache = nil
        conteneurs.removeAll()
        pagesRetenues.removeAll()

        return try await analyse()
    }

    /// Ferme ce que le partage tient ouvert et oublie ce qui a ete retenu.
    public func liberer() async {
        analyseEnCache = nil
        conteneurs.removeAll()
        pagesRetenues.removeAll()

        await partage.fermer()
    }

    /// Vide le cache des conteneurs rapatries faute de lecture en flux.
    public func viderLeCache() throws {
        try cache.vider()
    }

    // MARK: Conversions

    private static func mangaDistant(_ serie: SerieLocale) -> MangaDistant {
        MangaDistant(
            identifiant: serie.identifiant,
            titre: serie.titre,
            nombreChapitres: serie.chapitres.count
        )
    }

    private static func chapitreDistant(_ chapitre: ChapitreLocal, serie: SerieLocale) -> ChapitreDistant {
        ChapitreDistant(
            identifiant: chapitre.identifiant,
            identifiantManga: serie.identifiant,
            numero: chapitre.numero,
            titre: chapitre.titre,
            datePublication: chapitre.dateModification,
            nombrePages: chapitre.nombrePages,
            ordre: chapitre.ordre
        )
    }

    /// Forme de comparaison d un titre : sans casse et sans accent.
    private static func normaliser(_ texte: String) -> String {
        texte
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }

    /// Rend la tranche demandee, et dit s il en reste.
    private func decouper(_ elements: [MangaDistant], page: Int) -> PageResultats<MangaDistant> {
        let debut = max(0, page) * tailleDePage

        guard debut < elements.count else {
            return PageResultats(elements: [], page: page, ilResteDesPages: false)
        }

        let fin = min(debut + tailleDePage, elements.count)

        return PageResultats(
            elements: Array(elements[debut..<fin]),
            page: page,
            ilResteDesPages: fin < elements.count
        )
    }
}
