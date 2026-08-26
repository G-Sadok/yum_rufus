import Archive
import Core
import Foundation
import ImagePipeline

//
// SourceICloudDrive
//
// La source du tableau 4.2 posee sur un dossier d iCloud Drive.
//
// Elle ressemble a la source de fichiers locaux, et c est voulu : la convention
// de rangement est la meme, l analyse est la meme, les identifiants de chapitre
// sont les memes chemins relatifs. Trois choses seulement la distinguent, et ce
// sont les trois que la fonctionnalite demande.
//
// La premiere est qu un fichier peut ne pas etre la. Un chapitre absent reste
// affiche, avec son vrai nom, et c est son ouverture qui declenche le
// rapatriement. L analyse, elle, ne telecharge rien : une grille de vingt
// chapitres qui rapatrierait tout ce qu elle affiche viderait le forfait de
// l utilisateur pour lui montrer des vignettes.
//
// La deuxieme est que le fichier appartient a un autre processus. Toute lecture
// passe donc par le coordinateur du systeme, sans quoi une synchronisation
// lancee au meme moment ferait lire une archive a demi ecrite.
//
// La troisieme est que les octets d une page ne s obtiennent pas par une
// requete. `requeteImage(pour:)` refuse toujours, comme pour un partage reseau,
// et pour une raison voisine : rendre une URL de fichier laisserait la chaine
// d images ouvrir un substitut de quelques centaines d octets en croyant lire
// une page, et le chapitre s afficherait casse sans que rien ne dise pourquoi.
// Les octets se demandent a la source, par `donnees(page:)`.
//
// Les capacites declarees sont la recherche et la pagination. Pas le
// telechargement : cette capacite designe la mise en cache hors ligne offerte
// par une source distante, pas le rapatriement d un fichier que l utilisateur
// possede deja et que le systeme gere pour lui.
//

/// Source de contenu posee sur un dossier iCloud Drive.
public actor SourceICloudDrive: SourceProvider {
    /// Ce que cette source sait reellement faire.
    public static let capacitesOffertes: SourceCapacites = [.recherche, .pagination]

    /// Nombre de series rendues par page de catalogue, par defaut.
    public static let tailleDePageParDefaut = 60

    public nonisolated let id: SourceID
    public nonisolated let nom: String

    /// Nombre de series rendues par page de catalogue.
    public nonisolated let tailleDePage: Int

    public nonisolated var capacites: SourceCapacites {
        Self.capacitesOffertes
    }

    let acces: AccesAuDossier
    let coordination: any CoordinationDeFichiers
    let telechargeur: TelechargeurICloud

    /// L analyse reconnait les substituts, seule difference avec celle d un
    /// dossier local. Interne et non prive : la lecture des pages vit dans un
    /// autre fichier et enumere les images posees par le meme analyseur.
    let analyseur = AnalyseurDeDossier(substitutsUbiquitaires: true)
    private var analyseEnCache: AnalyseDeDossier?

    var pagesRetenues: [String: [PageDistante]] = [:]

    /// Construit la source sur un acces deja prepare.
    public init(
        id: SourceID = SourceID(),
        nom: String,
        acces: AccesAuDossier,
        depot: any DepotICloud = DepotICloudDuSysteme(),
        coordination: any CoordinationDeFichiers = CoordinationParLeSysteme(),
        tailleDePage: Int = SourceICloudDrive.tailleDePageParDefaut,
        cadenceDeSondage: Duration = TelechargeurICloud.cadenceParDefaut
    ) {
        self.id = id
        self.nom = nom
        self.acces = acces
        self.coordination = coordination
        self.tailleDePage = max(1, tailleDePage)
        telechargeur = TelechargeurICloud(nom: nom, depot: depot, cadence: cadenceDeSondage)
    }

    /// Construit la source sur un dossier que l utilisateur vient de choisir,
    /// en enregistrant le signet qui rendra ce dossier accessible au prochain
    /// lancement.
    public static func enregistrant(
        dossier: URL,
        id: SourceID = SourceID(),
        nom: String,
        magasin: any MagasinDeSignets,
        depot: any DepotICloud = DepotICloudDuSysteme(),
        coordination: any CoordinationDeFichiers = CoordinationParLeSysteme(),
        tailleDePage: Int = SourceICloudDrive.tailleDePageParDefaut,
        cadenceDeSondage: Duration = TelechargeurICloud.cadenceParDefaut
    ) throws -> SourceICloudDrive {
        let acces = try AccesAuDossier.enregistrant(
            dossier: dossier,
            magasin: magasin,
            cle: cleDeSignet(id),
            source: nom
        )

        return SourceICloudDrive(
            id: id,
            nom: nom,
            acces: acces,
            depot: depot,
            coordination: coordination,
            tailleDePage: tailleDePage,
            cadenceDeSondage: cadenceDeSondage
        )
    }

    /// Reconstruit la source d un lancement precedent, a partir du seul signet.
    public static func depuisLeSignet(
        id: SourceID,
        nom: String,
        magasin: any MagasinDeSignets,
        depot: any DepotICloud = DepotICloudDuSysteme(),
        coordination: any CoordinationDeFichiers = CoordinationParLeSysteme(),
        tailleDePage: Int = SourceICloudDrive.tailleDePageParDefaut
    ) -> SourceICloudDrive {
        SourceICloudDrive(
            id: id,
            nom: nom,
            acces: AccesAuDossier(magasin: magasin, cle: cleDeSignet(id), source: nom),
            depot: depot,
            coordination: coordination,
            tailleDePage: tailleDePage
        )
    }

    /// Cle sous laquelle le signet d une source est range.
    public static func cleDeSignet(_ id: SourceID) -> String {
        "iCloudDrive.\(id.brut.uuidString)"
    }

    // MARK: Protocole

    public func verifierConnexion() async -> EtatConnexion {
        do {
            _ = try await acces.dossier()

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
            // Un dossier iCloud ne mesure aucune popularite. Rendre la liste
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

    public func requeteImage(pour page: PageDistante) async throws -> URLRequest {
        throw ErreurDeSource.pageNonAdressableParRequete(
            entree: page.entree ?? page.emplacement.lastPathComponent
        )
    }

    // MARK: Telechargement

    /// Ouvre un flux des progressions de telechargement de cette source.
    public func progressions() async -> AsyncStream<ProgressionDeTelechargement> {
        await telechargeur.progressions()
    }

    /// Derniere progression connue pour ce chapitre.
    public func progression(de chapitre: String) async -> ProgressionDeTelechargement? {
        await telechargeur.progression(de: chapitre)
    }

    // MARK: Analyse

    /// Rend l analyse du dossier, en la calculant au premier appel.
    ///
    /// Aucun fichier n est rapatrie ici. L analyse ne lit que des noms et des
    /// dates, que le systeme connait sans telecharger quoi que ce soit.
    public func analyse() async throws -> AnalyseDeDossier {
        if let analyseEnCache {
            return analyseEnCache
        }

        let racine = try await acces.dossier()
        let resultat = try analyseur.analyser(racine, source: nom)
        analyseEnCache = resultat

        return resultat
    }

    /// Relance l analyse du dossier et rend le resultat.
    @discardableResult
    public func reanalyser() async throws -> AnalyseDeDossier {
        analyseEnCache = nil
        pagesRetenues.removeAll()

        return try await analyse()
    }

    /// Ferme l acces au dossier et arrete les telechargements en cours.
    public func liberer() async {
        analyseEnCache = nil
        pagesRetenues.removeAll()

        await telechargeur.liberer()
        await acces.liberer()
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
