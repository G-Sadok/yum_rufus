import Core
import Foundation

//
// SourceDeTest
//
// Une implementation de `SourceProvider` pilotee par le test. Elle sert a
// couvrir ce qu aucune source reelle ne sait produire a la demande : une panne
// de transport precise, un serveur muet, une source qui promet une page
// suivante qu elle ne sert jamais.
//
// C est un acteur, comme les vraies sources : le compteur d appels est un etat
// mutable partage, et les tests du registre interrogent plusieurs sources en
// parallele.
//

/// Erreur sans type de domaine, pour couvrir la traduction de dernier recours.
struct ErreurQuelconque: Error {}

/// Source dont le test decide le comportement.
actor SourceDeTest: SourceProvider {
    /// Ce que la source fait au lieu de repondre.
    enum Panne: Sendable {
        /// Leve une erreur du domaine des sources.
        case source(ErreurDeSource)

        /// Leve une erreur de transport, comme URLSession la produirait.
        case transport(URLError.Code)

        /// Leve une erreur de lecture de conteneur.
        case document(ErreurDeDocument)

        /// Leve une erreur qu aucun type du domaine ne nomme.
        case quelconque

        /// Ne rend jamais la main, jusqu a l annulation.
        case muette
    }

    nonisolated let id: SourceID
    nonisolated let nom: String
    nonisolated let capacites: SourceCapacites

    private let series: [MangaDistant]
    private let tailleDePage: Int
    private let panne: Panne?
    private let etat: EtatConnexion

    /// Attente observee avant de repondre, pour jouer une source lente.
    ///
    /// Distincte de `Panne.muette`, qui ne repond jamais : une source lente
    /// finit par rendre ses resultats, et c est justement ce qui permet de
    /// verifier que les autres n ont pas attendu apres elle.
    private let delaiAvantReponse: Duration?

    /// Fait annoncer une page suivante meme quand il n en reste aucune.
    ///
    /// Sert a verifier que le parcours ne boucle pas sur une source qui ment.
    private let promettreUneSuiteSansFin: Bool

    private var appels = 0

    init(
        id: SourceID = SourceID(),
        nom: String,
        capacites: SourceCapacites = [.recherche, .pagination],
        series: [MangaDistant] = [],
        tailleDePage: Int = 2,
        panne: Panne? = nil,
        etat: EtatConnexion = .connecte,
        promettreUneSuiteSansFin: Bool = false,
        delaiAvantReponse: Duration? = nil
    ) {
        self.id = id
        self.nom = nom
        self.capacites = capacites
        self.series = series
        self.tailleDePage = max(1, tailleDePage)
        self.panne = panne
        self.etat = etat
        self.promettreUneSuiteSansFin = promettreUneSuiteSansFin
        self.delaiAvantReponse = delaiAvantReponse
    }

    /// Nombre de fois ou la source a ete interrogee.
    var nombreDAppels: Int {
        appels
    }

    // MARK: Protocole

    func verifierConnexion() async -> EtatConnexion {
        appels += 1

        if case .muette = panne {
            await Self.neJamaisRepondre()

            return .erreur
        }

        return etat
    }

    func rechercher(_ requete: RequeteRecherche) async throws -> PageResultats<MangaDistant> {
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

        try await repondreOuEchouer()

        let filtrees = series.filter { requete.texte.isEmpty || $0.titre.contains(requete.texte) }

        return decouper(filtrees, page: requete.page)
    }

    func parcourir(_ section: SectionCatalogue, page: Int) async throws -> PageResultats<MangaDistant> {
        if page > 0 {
            try exiger(.pagination)
        }
        if section == .populaires {
            throw ErreurDeSource.sectionNonPriseEnCharge(section: section, source: nom)
        }

        try await repondreOuEchouer()

        return decouper(series, page: page)
    }

    func detailsManga(_ identifiant: String) async throws -> MangaDistant {
        try await repondreOuEchouer()

        guard let serie = series.first(where: { $0.identifiant == identifiant }) else {
            throw ErreurDeSource.mangaIntrouvable(identifiant: identifiant)
        }

        return serie
    }

    func chapitres(pour identifiant: String) async throws -> [ChapitreDistant] {
        try await repondreOuEchouer()

        return []
    }

    func pages(pour chapitre: String) async throws -> [PageDistante] {
        try await repondreOuEchouer()

        return []
    }

    func requeteImage(pour page: PageDistante) async throws -> URLRequest {
        try await repondreOuEchouer()

        return URLRequest(url: page.emplacement)
    }

    // MARK: Pilotage

    /// Compte l appel, puis applique la panne demandee s il y en a une.
    private func repondreOuEchouer() async throws {
        appels += 1

        if let delaiAvantReponse {
            try await Task.sleep(for: delaiAvantReponse)
        }

        switch panne {
        case nil:
            return
        case let .source(erreur):
            throw erreur
        case let .transport(code):
            throw URLError(code)
        case let .document(erreur):
            throw erreur
        case .quelconque:
            throw ErreurQuelconque()
        case .muette:
            await Self.neJamaisRepondre()
        }
    }

    /// Attend jusqu a l annulation, sans jamais rendre de resultat.
    ///
    /// Une heure plutot qu une boucle infinie : si l annulation ne parvenait pas
    /// jusqu ici, le test echouerait par delai au lieu de figer la suite.
    private static func neJamaisRepondre() async {
        try? await Task.sleep(for: .seconds(3600))
    }

    /// Rend la tranche demandee, et dit s il en reste.
    private func decouper(_ elements: [MangaDistant], page: Int) -> PageResultats<MangaDistant> {
        let debut = max(0, page) * tailleDePage

        guard debut < elements.count else {
            return PageResultats(elements: [], page: page, ilResteDesPages: promettreUneSuiteSansFin)
        }

        let fin = min(debut + tailleDePage, elements.count)

        return PageResultats(
            elements: Array(elements[debut..<fin]),
            page: page,
            ilResteDesPages: promettreUneSuiteSansFin || fin < elements.count
        )
    }
}

extension MangaDistant {
    /// Serie minimale, dont seul le titre compte pour ces tests.
    static func deTest(_ titre: String) -> MangaDistant {
        MangaDistant(identifiant: titre, titre: titre)
    }
}

extension [MangaDistant] {
    /// Suite de series numerotees, pour remplir un catalogue.
    static func suiteDeTest(_ nombre: Int) -> [MangaDistant] {
        (0..<nombre).map { MangaDistant.deTest("Serie \($0)") }
    }
}
