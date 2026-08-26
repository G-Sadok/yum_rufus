import Archive
import Core
import Foundation
import ImagePipeline

//
// SourceFichiersLocaux
//
// La premiere implementation de `SourceProvider`, sur un dossier du disque.
//
// C est un acteur pour deux raisons. L analyse est mise en cache, donc il y a
// un etat mutable partage. Et l acces au dossier ouvre une portee de securite
// qui ne supporte pas d etre ouverte et fermee par deux taches en parallele.
//
// Les capacites declarees sont la recherche et la pagination, et rien d autre.
// Un dossier local sait filtrer ses titres et servir sa liste par tranches. Il
// ne sait pas filtrer par genre, il ne connait aucune langue, il n a rien a
// telecharger puisque tout est deja la, et il ne tient aucune progression cote
// serveur. Declarer ces capacites ferait afficher a l interface des actions qui
// ne repondraient jamais.
//

/// Source de contenu posee sur un dossier local.
public actor SourceFichiersLocaux: SourceProvider {
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

    private let acces: AccesAuDossier
    private let analyseur = AnalyseurDeDossier()
    private var analyseEnCache: AnalyseDeDossier?

    /// Construit la source sur un acces deja prepare.
    public init(
        id: SourceID = SourceID(),
        nom: String,
        acces: AccesAuDossier,
        tailleDePage: Int = SourceFichiersLocaux.tailleDePageParDefaut
    ) {
        self.id = id
        self.nom = nom
        self.acces = acces
        self.tailleDePage = max(1, tailleDePage)
    }

    /// Construit la source sur un dossier que l utilisateur vient de choisir,
    /// en enregistrant le signet qui rendra ce dossier accessible au prochain
    /// lancement.
    public static func enregistrant(
        dossier: URL,
        id: SourceID = SourceID(),
        nom: String,
        magasin: any MagasinDeSignets,
        tailleDePage: Int = SourceFichiersLocaux.tailleDePageParDefaut
    ) throws -> SourceFichiersLocaux {
        let acces = try AccesAuDossier.enregistrant(
            dossier: dossier,
            magasin: magasin,
            cle: cleDeSignet(id),
            source: nom
        )

        return SourceFichiersLocaux(id: id, nom: nom, acces: acces, tailleDePage: tailleDePage)
    }

    /// Reconstruit la source d un lancement precedent, a partir du seul signet.
    ///
    /// Rien n est lu ici. Le signet n est resolu qu a la premiere interrogation,
    /// pour qu un lancement ne paie pas la resolution de sources que
    /// l utilisateur ne consultera pas.
    public static func depuisLeSignet(
        id: SourceID,
        nom: String,
        magasin: any MagasinDeSignets,
        tailleDePage: Int = SourceFichiersLocaux.tailleDePageParDefaut
    ) -> SourceFichiersLocaux {
        SourceFichiersLocaux(
            id: id,
            nom: nom,
            acces: AccesAuDossier(magasin: magasin, cle: cleDeSignet(id), source: nom),
            tailleDePage: tailleDePage
        )
    }

    /// Cle sous laquelle le signet d une source est range.
    public static func cleDeSignet(_ id: SourceID) -> String {
        "fichiersLocaux.\(id.brut.uuidString)"
    }

    // MARK: Protocole

    public func verifierConnexion() async -> EtatConnexion {
        do {
            _ = try await acces.dossier()

            return .connecte
        } catch ErreurDeSource.accesAuDossierPerdu {
            // Dossier deplace hors de portee, supprime, ou autorisation revoquee.
            // Les trois se reparent de la meme facon, en rechoisissant le dossier.
            return .injoignable
        } catch {
            return .erreur
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
            // Un dossier local ne mesure aucune popularite. Rendre la liste
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
        guard let trouve = try await analyse().chapitre(chapitre) else {
            throw ErreurDeSource.chapitreIntrouvable(identifiant: chapitre)
        }

        let emplacement = try await acces.dossier().appending(path: trouve.chapitre.identifiant)

        switch trouve.chapitre.forme {
        case .dossierDImages:
            return pagesPosees(dans: emplacement, chapitre: chapitre)
        case let .archive(format):
            return try pagesDArchive(emplacement, format: format, chapitre: trouve.chapitre)
        }
    }

    public func requeteImage(pour page: PageDistante) async throws -> URLRequest {
        if let entree = page.entree {
            throw ErreurDeSource.pageNonAdressableParRequete(entree: entree)
        }

        return URLRequest(url: page.emplacement)
    }

    // MARK: Analyse

    /// Rend l analyse du dossier, en la calculant au premier appel.
    public func analyse() async throws -> AnalyseDeDossier {
        if let analyseEnCache {
            return analyseEnCache
        }

        let racine = try await acces.dossier()
        let resultat = try analyseur.analyser(racine, source: nom)
        analyseEnCache = resultat

        return resultat
    }

    /// Rend le dossier racine de la source, en resolvant le signet au besoin.
    ///
    /// Le dossier sort d ici pour la reception Wi-Fi de la section 4.4, qui doit
    /// y poser les fichiers recus. Rien d autre n a besoin de l URL : le reste
    /// du projet passe par les identifiants de serie et de chapitre.
    ///
    /// - Throws: `ErreurDeSource.accesAuDossierPerdu` quand le signet ne designe
    ///   plus rien.
    public func racine() async throws -> URL {
        try await acces.dossier()
    }

    /// Relance l analyse du dossier et rend le resultat.
    ///
    /// A appeler quand l utilisateur demande une actualisation. Le systeme de
    /// fichiers ne previent pas des changements tant que personne ne l observe,
    /// et l observation arrivera avec la surveillance de dossier.
    @discardableResult
    public func reanalyser() async throws -> AnalyseDeDossier {
        analyseEnCache = nil

        return try await analyse()
    }

    /// Ferme l acces au dossier.
    public func liberer() async {
        analyseEnCache = nil
        await acces.liberer()
    }

    // MARK: Pages

    /// Pages d un chapitre range sous forme de dossier d images.
    private func pagesPosees(dans dossier: URL, chapitre: String) -> [PageDistante] {
        analyseur.imagesPosees(dans: dossier).enumerated().map { index, nom in
            let fichier = dossier.appending(path: nom)
            let octets = (try? fichier.resourceValues(forKeys: [.fileSizeKey]))?.fileSize

            return PageDistante(
                identifiantChapitre: chapitre,
                index: index,
                emplacement: fichier,
                octets: octets
            )
        }
    }

    /// Pages d un chapitre range dans un conteneur.
    ///
    /// L archive est ouverte ici et refermee aussitot : seul son index est lu,
    /// aucune page n est decompressee. Pour un TAR, qui ne porte pas d index,
    /// c est le cache sur disque qui evite d en reconstruire un a chaque fois.
    /// Les octets viendront a la demande, par le protocole `DocumentLocal`.
    private func pagesDArchive(
        _ emplacement: URL,
        format: String,
        chapitre: ChapitreLocal
    ) throws -> [PageDistante] {
        let document = try Self.ouvrir(emplacement, format: format, chapitre: chapitre)

        return try document.toutesLesPages().map { reference in
            PageDistante(
                identifiantChapitre: chapitre.identifiant,
                index: reference.index,
                emplacement: emplacement,
                entree: reference.nom,
                octets: reference.tailleOctets
            )
        }
    }

    /// Choisit le lecteur qui correspond a l extension du conteneur.
    ///
    /// Le format decide, jamais le contenu : un fichier renomme en .cbz reste
    /// annonce comme un ZIP par le systeme de fichiers, et un lecteur qui
    /// devinerait au vu des premiers octets ouvrirait sans le dire une archive
    /// que l utilisateur croit d un autre type.
    private static func ouvrir(
        _ emplacement: URL,
        format: String,
        chapitre: ChapitreLocal
    ) throws -> any DocumentLocal {
        if DocumentZip.extensions.contains(format) {
            return try DocumentZip(contenuDe: emplacement)
        }
        if DocumentTar.extensions.contains(format) {
            return try DocumentTar(contenuDe: emplacement)
        }
        // Le PDF protege remonte ici son `ErreurDeDocument.conteneurChiffre`
        // telle quelle. C est ce que l ecran attend pour demander le mot de
        // passe, et la traduire en erreur de source la rendrait indiscernable
        // d une archive cassee.
        if DocumentPdf.extensions.contains(format) {
            return try DocumentPdf(contenuDe: emplacement)
        }

        throw ErreurDeSource.formatNonPrisEnCharge(nom: chapitre.titre, format: format)
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
    ///
    /// Une recherche sur `Berserk` doit trouver `berserk`, et une recherche sur
    /// `pokemon` doit trouver `Pokemon` comme `Pokémon`.
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
