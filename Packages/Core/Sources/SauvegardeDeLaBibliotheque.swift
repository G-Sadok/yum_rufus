import Foundation

//
// SauvegardeDeLaBibliotheque
//
// La part bibliotheque du fichier JSON versionne de la section 10 du cahier de
// developpement, celle dont il dit que l export inclut `la bibliotheque, les
// categories, la progression, les signets, les prereglages et la configuration
// des sources`.
//
// Elle porte les series de la bibliotheque et leurs chapitres, et rien d autre.
// Trois absences sont voulues.
//
// Les pages n y sont pas. Une ligne de `page` est le releve d un contenu que la
// source enumere a l ouverture du chapitre, pas une decision de l utilisateur.
// L emporter multiplierait le poids du fichier par le nombre de pages d une
// bibliotheque, pour des lignes que la premiere ouverture reecrit.
//
// Le chemin de couverture locale n y est pas non plus. C est un chemin vers un
// fichier de cache de cet appareil la. Restaure ailleurs, il designerait un
// fichier absent, et la vignette serait cassee au lieu d etre simplement
// refabriquee.
//
// L avancement de lecture n y est pas : il forme la part progression, a part,
// pour que la section 10 se relise dans le fichier telle qu elle est ecrite.
//

/// Une serie de la bibliotheque telle qu elle figure dans une sauvegarde.
///
/// L identifiant est conserve : la part categories, la part progression et la
/// part signets s y rapportent toutes, et une restauration qui renumeroterait
/// les series perdrait ces trois liens d un coup.
public struct SerieExportee: Sendable, Codable, Hashable {
    public let id: UUID
    public let sourceId: UUID
    public let identifiantDistant: String
    public let titre: String
    public let titresAlternatifs: [String]
    public let auteurs: [String]
    public let dessinateurs: [String]
    public let resume: String?
    public let genres: [String]
    public let statut: StatutSerie
    public let langue: String?
    public let urlCouverture: String?
    public let sensLectureForce: SensDeLecture?
    public let decalageDeCouvertureForce: DecalageDeCouverture?
    public let dateAjout: Date
    public let dateDerniereMiseAJour: Date?

    /// Projette une serie vers sa forme exportable.
    public init(_ manga: Manga) {
        id = manga.id
        sourceId = manga.sourceId
        identifiantDistant = manga.identifiantDistant
        titre = manga.titre
        titresAlternatifs = manga.titresAlternatifs
        auteurs = manga.auteurs
        dessinateurs = manga.dessinateurs
        resume = manga.resume
        genres = manga.genres
        statut = manga.statut
        langue = manga.langue
        urlCouverture = manga.urlCouverture
        sensLectureForce = manga.sensLectureForce
        decalageDeCouvertureForce = manga.decalageDeCouvertureForce
        dateAjout = manga.dateAjout
        dateDerniereMiseAJour = manga.dateDerniereMiseAJour
    }

    /// Reconstruit la serie a partir de sa forme exportee.
    ///
    /// Elle revient dans la bibliotheque, puisque c est a ce titre qu elle a ete
    /// exportee, sans couverture en cache et sans date de derniere lecture. La
    /// date de derniere lecture appartient a la part progression, qui la repose
    /// apres coup.
    public func manga() -> Manga {
        Manga(
            id: id,
            sourceId: sourceId,
            identifiantDistant: identifiantDistant,
            titre: titre,
            titresAlternatifs: titresAlternatifs,
            auteurs: auteurs,
            dessinateurs: dessinateurs,
            resume: resume,
            genres: genres,
            statut: statut,
            langue: langue,
            urlCouverture: urlCouverture,
            sensLectureForce: sensLectureForce,
            decalageDeCouvertureForce: decalageDeCouvertureForce,
            estDansBibliotheque: true,
            dateAjout: dateAjout,
            dateDerniereMiseAJour: dateDerniereMiseAJour
        )
    }
}

/// Un chapitre tel qu il figure dans une sauvegarde.
///
/// L etat de lecture est absent par construction : `estLu`, la page atteinte,
/// le decalage de defilement et la date de lecture forment la part progression.
public struct ChapitreExporte: Sendable, Codable, Hashable {
    public let id: UUID
    public let mangaId: UUID
    public let identifiantDistant: String
    public let numero: Double
    public let titre: String?
    public let groupeTraduction: String?
    public let langue: String?
    public let datePublication: Date?
    public let nombrePages: Int
    public let ordreDansSerie: Int

    /// Projette un chapitre vers sa forme exportable.
    public init(_ chapitre: Chapitre) {
        id = chapitre.id
        mangaId = chapitre.mangaId
        identifiantDistant = chapitre.identifiantDistant
        numero = chapitre.numero
        titre = chapitre.titre
        groupeTraduction = chapitre.groupeTraduction
        langue = chapitre.langue
        datePublication = chapitre.datePublication
        nombrePages = chapitre.nombrePages
        ordreDansSerie = chapitre.ordreDansSerie
    }

    /// Reconstruit le chapitre a partir de sa forme exportee, non lu.
    ///
    /// C est la part progression qui repose l avancement, dans un second temps.
    /// Reconstruire un chapitre deja lu ici ferait travailler les declencheurs
    /// de non lus deux fois pour le meme chapitre.
    public func chapitre() -> Chapitre {
        Chapitre(
            id: id,
            mangaId: mangaId,
            identifiantDistant: identifiantDistant,
            numero: numero,
            titre: titre,
            groupeTraduction: groupeTraduction,
            langue: langue,
            datePublication: datePublication,
            nombrePages: nombrePages,
            ordreDansSerie: ordreDansSerie
        )
    }
}

/// La part bibliotheque d une sauvegarde, versionnee.
public struct SauvegardeDeLaBibliotheque: Sendable, Codable, Hashable {
    /// Version du format de la part bibliotheque.
    public static let versionCourante = 1

    public let version: Int
    public let series: [SerieExportee]
    public let chapitres: [ChapitreExporte]

    public init(
        version: Int = SauvegardeDeLaBibliotheque.versionCourante,
        series: [SerieExportee],
        chapitres: [ChapitreExporte]
    ) {
        self.version = version
        self.series = series
        self.chapitres = chapitres
    }

    /// Construit la part bibliotheque a partir des entites persistees.
    public init(series: [Manga], chapitres: [Chapitre]) {
        self.init(
            series: series.map(SerieExportee.init),
            chapitres: chapitres.map(ChapitreExporte.init)
        )
    }

    /// Series reconstruites, dans l ordre de la liste.
    public func seriesRestaurees() -> [Manga] {
        series.map { $0.manga() }
    }

    /// Chapitres reconstruits, dans l ordre de la liste.
    public func chapitresRestaures() -> [Chapitre] {
        chapitres.map { $0.chapitre() }
    }

    /// Part vide, celle que la migration d une sauvegarde anterieure installe.
    public static let vide = SauvegardeDeLaBibliotheque(series: [], chapitres: [])
}
