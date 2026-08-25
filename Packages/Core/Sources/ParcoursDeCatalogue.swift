//
// ParcoursDeCatalogue
//
// La pagination de la section 4.1, cote appelant. `PageResultats` dit ce qu une
// page contient et s il en reste ; ce parcours enchaine les appels et sait
// quand s arreter.
//
// Il vit dans Core parce que la regle d arret depend des capacites declarees et
// non de l implementation : une source qui ne declare pas `pagination` refuse
// la page suivante par `ErreurDeSource.capaciteIndisponible`, et la lui
// demander quand meme transformerait un catalogue court en erreur affichee.
//

/// Enchaine les pages d un catalogue jusqu a la derniere.
///
/// Le parcours rend des pages entieres et non des series une par une : la grille
/// de l ecran Parcourir insere par lot, et decouper la page ici l obligerait a
/// la recomposer.
public struct ParcoursDeCatalogue: AsyncSequence, Sendable {
    public typealias Element = PageResultats<MangaDistant>

    /// Ce que le parcours interroge.
    public enum Origine: Sendable, Hashable {
        /// Une section du catalogue, parcourue telle quelle.
        case section(SectionCatalogue)

        /// Une recherche, dont le numero de page est remplace a chaque tour.
        case recherche(RequeteRecherche)
    }

    private let source: any SourceProvider
    private let origine: Origine
    private let premierePage: Int

    /// Parcourt une section du catalogue.
    public init(source: any SourceProvider, section: SectionCatalogue, depuis premierePage: Int = 0) {
        self.source = source
        origine = .section(section)
        // Swift.max explicite : AsyncSequence apporte une methode max() sans
        // argument, que le compilateur prefere ici a la fonction globale.
        self.premierePage = Swift.max(0, premierePage)
    }

    /// Parcourt les resultats d une recherche.
    ///
    /// La page portee par la requete sert de point de depart, pour qu une
    /// reprise apres erreur ne recommence pas au debut.
    public init(source: any SourceProvider, recherche: RequeteRecherche) {
        self.source = source
        origine = .recherche(recherche)
        premierePage = Swift.max(0, recherche.page)
    }

    public func makeAsyncIterator() -> Iterateur {
        Iterateur(source: source, origine: origine, page: premierePage)
    }

    /// Avance d une page a chaque appel, et s arrete de lui meme.
    public struct Iterateur: AsyncIteratorProtocol {
        private let source: any SourceProvider
        private let origine: Origine
        private var page: Int
        private var termine = false

        init(source: any SourceProvider, origine: Origine, page: Int) {
            self.source = source
            self.origine = origine
            self.page = page
        }

        /// Rend la page suivante, ou nul quand le parcours est fini.
        ///
        /// Trois raisons d arreter, dans cet ordre. La source dit qu il ne reste
        /// rien. La page rendue est vide, ce qui protege d une source qui
        /// promettrait une suite sans jamais la servir, et ferait tourner la
        /// grille indefiniment. La source ne declare pas la pagination, auquel
        /// cas la premiere page est tout son catalogue et demander la suivante
        /// leverait `capaciteIndisponible`.
        public mutating func next() async throws -> Element? {
            guard termine == false else {
                return nil
            }

            try Task.checkCancellation()

            let resultats = try await charger(page)

            termine = resultats.ilResteDesPages == false
                || resultats.elements.isEmpty
                || source.declare(.pagination) == false
            page += 1

            return resultats
        }

        private func charger(_ numero: Int) async throws -> Element {
            switch origine {
            case let .section(section):
                try await source.parcourir(section, page: numero)
            case let .recherche(requete):
                try await source.rechercher(Self.requete(requete, page: numero))
            }
        }

        /// Rend la requete d origine, pointee sur la page demandee.
        private static func requete(_ modele: RequeteRecherche, page: Int) -> RequeteRecherche {
            var requete = modele
            requete.page = page

            return requete
        }
    }
}

extension ParcoursDeCatalogue {
    /// Ramene le catalogue entier, en s arretant a `maximum` series.
    ///
    /// Le plafond est obligatoire et non optionnel : un catalogue distant peut
    /// compter des centaines de milliers de series, et une methode qui promet
    /// de tout ramener sans borne finit toujours par etre appelee sur celui la.
    public func collecter(maximum: Int) async throws -> [MangaDistant] {
        var series: [MangaDistant] = []

        for try await page in self {
            series.append(contentsOf: page.elements)

            if series.count >= maximum {
                return Array(series.prefix(maximum))
            }
        }

        return series
    }
}
