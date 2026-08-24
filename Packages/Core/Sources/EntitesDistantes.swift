import Foundation

//
// EntitesDistantes
//
// Les valeurs qui circulent entre une source et le reste de l application,
// d apres la section 4.1 du cahier de developpement.
//
// Elles sont distinctes des entites de catalogue de la section 3.1. Une source
// ne connait pas les identifiants de la base : elle rend ce que son catalogue
// annonce, avec l identifiant du catalogue. C est la couche d import qui
// rapproche un `MangaDistant` d une ligne `Manga` existante, par le couple
// source et identifiant distant. Melanger les deux imposerait a chaque source
// de connaitre GRDB, ce que la frontiere entre paquets interdit.
//

/// Identite d une source configuree, telle qu elle est vue par le protocole.
///
/// Le type existe pour ne pas confondre l identifiant d une source avec celui
/// d une serie ou d un chapitre, qui sont eux aussi des UUID.
public struct SourceID: Sendable, Codable, Hashable {
    public let brut: UUID

    public init(_ brut: UUID = UUID()) {
        self.brut = brut
    }
}

/// Serie telle que la source l annonce, avant tout rapprochement avec la base.
public struct MangaDistant: Sendable, Hashable {
    /// Identifiant de la serie chez la source, stable entre deux analyses.
    public let identifiant: String

    public let titre: String
    public let auteurs: [String]
    public let resume: String?
    public let genres: [String]
    public let statut: StatutSerie
    public let langue: String?

    /// Emplacement de la couverture chez la source, quand elle en publie une.
    public let urlCouverture: String?

    /// Nombre de chapitres annonces, quand la source le connait sans avoir a
    /// ouvrir la serie.
    public let nombreChapitres: Int?

    public init(
        identifiant: String,
        titre: String,
        auteurs: [String] = [],
        resume: String? = nil,
        genres: [String] = [],
        statut: StatutSerie = .inconnu,
        langue: String? = nil,
        urlCouverture: String? = nil,
        nombreChapitres: Int? = nil
    ) {
        self.identifiant = identifiant
        self.titre = titre
        self.auteurs = auteurs
        self.resume = resume
        self.genres = genres
        self.statut = statut
        self.langue = langue
        self.urlCouverture = urlCouverture
        self.nombreChapitres = nombreChapitres
    }
}

/// Chapitre tel que la source l annonce.
public struct ChapitreDistant: Sendable, Hashable {
    public let identifiant: String
    public let identifiantManga: String

    /// Numero annonce, decimal parce que les chapitres bonus portent des
    /// numeros comme 10.5.
    public let numero: Double

    public let titre: String?
    public let langue: String?
    public let datePublication: Date?

    /// Nombre de pages, seulement quand la source le connait sans ouvrir le
    /// chapitre. Nul veut dire inconnu, jamais zero.
    public let nombrePages: Int?

    /// Rang du chapitre dans la serie, a partir de zero.
    ///
    /// Distinct de `numero`, qui peut etre absent, duplique ou incoherent selon
    /// la source. C est ce rang qui ordonne la liste, jamais le numero.
    public let ordre: Int

    public init(
        identifiant: String,
        identifiantManga: String,
        numero: Double,
        titre: String? = nil,
        langue: String? = nil,
        datePublication: Date? = nil,
        nombrePages: Int? = nil,
        ordre: Int
    ) {
        self.identifiant = identifiant
        self.identifiantManga = identifiantManga
        self.numero = numero
        self.titre = titre
        self.langue = langue
        self.datePublication = datePublication
        self.nombrePages = nombrePages
        self.ordre = ordre
    }
}

/// Page telle que la source l annonce.
///
/// L emplacement est en deux parties, parce qu une source locale sert aussi des
/// pages rangees dans une archive. Pour une image posee sur le disque ou servie
/// par un serveur, `emplacement` suffit et `entree` est nul. Pour une page a
/// l interieur d un conteneur, `emplacement` designe le conteneur et `entree`
/// nomme le fichier a en extraire. Une seule URL ne saurait pas dire cela, et
/// les schemas d URL inventes pour le faire tenir se paient ensuite dans chaque
/// couche qui les analyse.
public struct PageDistante: Sendable, Hashable {
    public let identifiantChapitre: String

    /// Position dans l ordre de lecture, a partir de zero.
    public let index: Int

    public let emplacement: URL

    /// Chemin de la page a l interieur du conteneur, quand il y en a un.
    public let entree: String?

    /// Poids de la page en octets, quand il est connu.
    public let octets: Int?

    public init(
        identifiantChapitre: String,
        index: Int,
        emplacement: URL,
        entree: String? = nil,
        octets: Int? = nil
    ) {
        self.identifiantChapitre = identifiantChapitre
        self.index = index
        self.emplacement = emplacement
        self.entree = entree
        self.octets = octets
    }

    /// Vrai quand la page vit a l interieur d un conteneur.
    public var estDansUnConteneur: Bool {
        entree != nil
    }
}

/// Criteres de recherche autres que le texte.
///
/// Une source qui ne declare pas `SourceCapacites.filtres` refuse une requete
/// dont les filtres ne sont pas vides, plutot que de les ignorer en silence et
/// de rendre des resultats qui ne correspondent pas a ce qui est demande.
public struct FiltresDeRecherche: Sendable, Hashable {
    public var genres: [String]
    public var statut: StatutSerie?

    public init(genres: [String] = [], statut: StatutSerie? = nil) {
        self.genres = genres
        self.statut = statut
    }

    public var estVide: Bool {
        genres.isEmpty && statut == nil
    }
}

/// Requete adressee a une source.
public struct RequeteRecherche: Sendable, Hashable {
    public var texte: String
    public var filtres: FiltresDeRecherche

    /// Langue demandee, au format BCP 47. Nul veut dire toutes les langues que
    /// la source connait.
    public var langue: String?

    /// Page demandee, a partir de zero.
    public var page: Int

    public init(
        texte: String,
        filtres: FiltresDeRecherche = FiltresDeRecherche(),
        langue: String? = nil,
        page: Int = 0
    ) {
        self.texte = texte
        self.filtres = filtres
        self.langue = langue
        self.page = page
    }
}

/// Une page de resultats rendue par une source.
public struct PageResultats<Element: Sendable>: Sendable {
    public let elements: [Element]

    /// Numero de la page rendue, a partir de zero.
    public let page: Int

    /// Vrai quand une page suivante existe.
    ///
    /// La valeur est portee par la source parce qu elle seule sait compter. La
    /// deduire d une liste pleine ferait demander une page vide a chaque fois
    /// que le total est un multiple de la taille de page.
    public let ilResteDesPages: Bool

    public init(elements: [Element], page: Int = 0, ilResteDesPages: Bool = false) {
        self.elements = elements
        self.page = page
        self.ilResteDesPages = ilResteDesPages
    }
}

/// Section du catalogue d une source.
///
/// Toutes les sources ne les servent pas toutes. Une source qui ne sait pas
/// classer par popularite leve `ErreurDeSource.sectionNonPriseEnCharge` plutot
/// que de rendre la liste complete sous un autre nom.
public enum SectionCatalogue: String, Sendable, Codable, CaseIterable, Hashable {
    /// Tout le catalogue, dans l ordre naturel des titres.
    case tout

    /// Les series vues comme recemment ajoutees ou mises a jour par la source.
    case recentes

    /// Les series les plus populaires chez la source.
    case populaires
}
