import Foundation

//
// EntitesDeCatalogue
//
// Source, Manga, Chapitre et Page, d apres la section 3.1 du cahier de
// developpement. Ces types ne connaissent ni SQL ni GRDB. Le paquet Storage
// leur ajoute les conformances de persistance par extension.
//
// Les identifiants sont des UUID et non des numeros de ligne. La
// synchronisation iCloud de l etape 10 replique des enregistrements entre
// plusieurs appareils : deux appareils hors ligne qui inserent chacun une
// serie doivent produire des identifiants distincts. Un compteur local
// produirait deux fois le meme et la fusion perdrait une serie. Rattraper ce
// choix plus tard imposerait une migration destructive sur 200000 chapitres.
//

/// Source de contenu configuree par l utilisateur.
///
/// L application n heberge rien. Une source designe toujours quelque chose que
/// l utilisateur possede deja : un dossier, un serveur, un partage reseau.
public struct Source: Sendable, Codable, Identifiable, Hashable {
    public var id: UUID
    public var type: TypeDeSource
    public var nom: String

    /// Configuration chiffree de la source, sans aucun identifiant de
    /// connexion. Les mots de passe et jetons vivent dans le trousseau, jamais
    /// dans la base et jamais en clair.
    public var configurationChiffree: Data?

    /// Version de l extension declarative, quand la source en utilise une.
    public var versionExtension: String?

    /// Code de langue du catalogue, au format BCP 47.
    public var langue: String?

    public var ordreAffichage: Int
    public var estActive: Bool
    public var dateDerniereVerification: Date?
    public var etatConnexion: EtatConnexion

    public init(
        id: UUID = UUID(),
        type: TypeDeSource,
        nom: String,
        configurationChiffree: Data? = nil,
        versionExtension: String? = nil,
        langue: String? = nil,
        ordreAffichage: Int = 0,
        estActive: Bool = true,
        dateDerniereVerification: Date? = nil,
        etatConnexion: EtatConnexion = .nonVerifie
    ) {
        self.id = id
        self.type = type
        self.nom = nom
        self.configurationChiffree = configurationChiffree
        self.versionExtension = versionExtension
        self.langue = langue
        self.ordreAffichage = ordreAffichage
        self.estActive = estActive
        self.dateDerniereVerification = dateDerniereVerification
        self.etatConnexion = etatConnexion
    }
}

/// Serie, quel que soit son genre : manga, manhwa, manhua, comics.
///
/// Le compteur de chapitres non lus ne figure pas ici. Il est denormalise dans
/// la table `manga` et maintenu par declencheur, donc jamais ecrit par le code
/// applicatif. Voir `MangaDeGrille` dans Storage pour le lire.
public struct Manga: Sendable, Codable, Identifiable, Hashable {
    public var id: UUID
    public var sourceId: UUID

    /// Identifiant de la serie chez la source, unique au sein de cette source.
    public var identifiantDistant: String

    public var titre: String
    public var titresAlternatifs: [String]
    public var auteurs: [String]
    public var dessinateurs: [String]
    public var resume: String?
    public var genres: [String]
    public var statut: StatutSerie
    public var langue: String?
    public var urlCouverture: String?
    public var cheminCouvertureLocale: String?

    /// Sens de lecture impose a cette serie. Nul quand la serie suit le
    /// reglage global.
    public var sensLectureForce: SensDeLecture?

    public var estDansBibliotheque: Bool
    public var dateAjout: Date
    public var dateDerniereMiseAJour: Date?
    public var dateDerniereLecture: Date?

    public init(
        id: UUID = UUID(),
        sourceId: UUID,
        identifiantDistant: String,
        titre: String,
        titresAlternatifs: [String] = [],
        auteurs: [String] = [],
        dessinateurs: [String] = [],
        resume: String? = nil,
        genres: [String] = [],
        statut: StatutSerie = .inconnu,
        langue: String? = nil,
        urlCouverture: String? = nil,
        cheminCouvertureLocale: String? = nil,
        sensLectureForce: SensDeLecture? = nil,
        estDansBibliotheque: Bool = false,
        dateAjout: Date = Date(),
        dateDerniereMiseAJour: Date? = nil,
        dateDerniereLecture: Date? = nil
    ) {
        self.id = id
        self.sourceId = sourceId
        self.identifiantDistant = identifiantDistant
        self.titre = titre
        self.titresAlternatifs = titresAlternatifs
        self.auteurs = auteurs
        self.dessinateurs = dessinateurs
        self.resume = resume
        self.genres = genres
        self.statut = statut
        self.langue = langue
        self.urlCouverture = urlCouverture
        self.cheminCouvertureLocale = cheminCouvertureLocale
        self.sensLectureForce = sensLectureForce
        self.estDansBibliotheque = estDansBibliotheque
        self.dateAjout = dateAjout
        self.dateDerniereMiseAJour = dateDerniereMiseAJour
        self.dateDerniereLecture = dateDerniereLecture
    }
}

/// Chapitre d une serie.
public struct Chapitre: Sendable, Codable, Identifiable, Hashable {
    public var id: UUID
    public var mangaId: UUID
    public var identifiantDistant: String

    /// Numero du chapitre, decimal parce que les chapitres bonus portent des
    /// numeros comme 10.5. Stocke en virgule flottante, la base ne connait pas
    /// le type decimal et un entier perdrait ces chapitres.
    public var numero: Double

    public var titre: String?
    public var groupeTraduction: String?
    public var langue: String?
    public var datePublication: Date?
    public var nombrePages: Int
    public var estLu: Bool

    /// Derniere page atteinte, indexee a partir de zero.
    public var pageAtteinte: Int

    /// Part de la page atteinte deja depassee par le defilement, entre zero et
    /// un. Voir `PositionDeLecture`, qui porte la meme valeur cote lecteur.
    ///
    /// Zero dans les modes pagines. C est la seconde moitie de la position de
    /// reprise de la section 7.5 : sans elle, un chapitre webtoon rouvre en
    /// haut d une page de vingt mille pixels que l utilisateur avait presque
    /// finie.
    public var decalageDeDefilement: Double

    public var dateLecture: Date?

    /// Rang du chapitre dans la serie. Distinct de `numero`, qui peut etre
    /// absent, duplique ou incoherent selon la source.
    public var ordreDansSerie: Int

    public init(
        id: UUID = UUID(),
        mangaId: UUID,
        identifiantDistant: String,
        numero: Double,
        titre: String? = nil,
        groupeTraduction: String? = nil,
        langue: String? = nil,
        datePublication: Date? = nil,
        nombrePages: Int = 0,
        estLu: Bool = false,
        pageAtteinte: Int = 0,
        decalageDeDefilement: Double = 0,
        dateLecture: Date? = nil,
        ordreDansSerie: Int
    ) {
        self.id = id
        self.mangaId = mangaId
        self.identifiantDistant = identifiantDistant
        self.numero = numero
        self.titre = titre
        self.groupeTraduction = groupeTraduction
        self.langue = langue
        self.datePublication = datePublication
        self.nombrePages = nombrePages
        self.estLu = estLu
        self.pageAtteinte = pageAtteinte
        self.decalageDeDefilement = decalageDeDefilement
        self.dateLecture = dateLecture
        self.ordreDansSerie = ordreDansSerie
    }
}

/// Page d un chapitre.
public struct Page: Sendable, Codable, Identifiable, Hashable {
    public var id: UUID
    public var chapitreId: UUID

    /// Position de la page dans le chapitre, indexee a partir de zero.
    public var index: Int

    public var urlDistante: String?
    public var cheminLocal: String?
    public var largeur: Int?
    public var hauteur: Int?

    /// Poids du fichier en octets, quand il est connu.
    public var octets: Int?

    public init(
        id: UUID = UUID(),
        chapitreId: UUID,
        index: Int,
        urlDistante: String? = nil,
        cheminLocal: String? = nil,
        largeur: Int? = nil,
        hauteur: Int? = nil,
        octets: Int? = nil
    ) {
        self.id = id
        self.chapitreId = chapitreId
        self.index = index
        self.urlDistante = urlDistante
        self.cheminLocal = cheminLocal
        self.largeur = largeur
        self.hauteur = hauteur
        self.octets = octets
    }
}
