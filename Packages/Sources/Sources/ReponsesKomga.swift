import Core
import Foundation

//
// ReponsesKomga
//
// La forme exacte de ce que le serveur repond, et sa traduction vers les
// entites distantes de la section 4.1.
//
// Tous les champs sont optionnels sauf les identifiants, et ce n est pas de la
// prudence decorative. Komga fait evoluer ses reponses de version en version :
// `sizeBytes` sur une page et `booksMetadata` sur une serie sont apparus en
// cours de route, `readProgress` est absent tant que rien n a ete lu. Declarer
// ces champs obligatoires ferait echouer le decodage de la reponse entiere sur
// un serveur d une autre version, donc echouer la source complete, alors que le
// seul champ manquant est celui d une information secondaire.
//
// Les identifiants, eux, sont obligatoires. Une serie sans identifiant ne
// designe rien : la rendre avec un identifiant invente ferait ouvrir une fiche
// vide, ce qui est pire qu un echec nomme.
//

/// Une tranche de resultats telle que Komga la rend.
///
/// C est la forme de page de Spring, employee par tous les points d entree de
/// liste du serveur.
struct PageDeKomga<Element: Decodable & Sendable>: Decodable, Sendable {
    let content: [Element]
    let number: Int?
    let last: Bool?
    let totalPages: Int?

    /// Vrai quand une page suivante existe.
    ///
    /// Le drapeau `last` du serveur fait autorite quand il est la. Sans lui, le
    /// total de pages tranche. Sans les deux, la reponse est traitee comme la
    /// derniere : promettre une page suivante qui n existe pas ferait tourner
    /// le defilement infini sur une liste vide.
    var ilResteDesPages: Bool {
        if let last {
            return last == false
        }
        if let totalPages, let number {
            return number + 1 < totalPages
        }

        return false
    }
}

/// Serie telle que Komga la rend.
struct SerieDeKomga: Decodable, Sendable {
    let id: String
    let name: String?
    let booksCount: Int?
    let metadata: MetadonneesDeSerieDeKomga?
    let booksMetadata: MetadonneesDesLivresDeKomga?
}

/// Metadonnees editoriales d une serie.
struct MetadonneesDeSerieDeKomga: Decodable, Sendable {
    let status: String?
    let title: String?
    let summary: String?
    let genres: [String]?
    let language: String?
}

/// Metadonnees agregees depuis les livres d une serie.
struct MetadonneesDesLivresDeKomga: Decodable, Sendable {
    let authors: [AuteurDeKomga]?
    let summary: String?
}

/// Un auteur, avec le role qu il a tenu sur l ouvrage.
struct AuteurDeKomga: Decodable, Sendable {
    let name: String
    let role: String?
}

/// Livre tel que Komga le rend. Un livre est un chapitre pour nous.
struct LivreDeKomga: Decodable, Sendable {
    let id: String
    let seriesId: String?
    let name: String?
    let media: MediaDeKomga?
    let metadata: MetadonneesDeLivreDeKomga?
    let readProgress: ProgressionDeKomga?
}

/// Ce que Komga sait du fichier d un livre.
struct MediaDeKomga: Decodable, Sendable {
    let pagesCount: Int?
}

/// Metadonnees editoriales d un livre.
struct MetadonneesDeLivreDeKomga: Decodable, Sendable {
    let title: String?
    let number: String?
    let numberSort: Double?
    let releaseDate: String?
}

/// Progression de lecture telle que Komga la tient.
///
/// La page est comptee a partir de un chez Komga. La conversion vers l index a
/// partir de zero du modele se fait dans `progressionDistante(pour:)`, et nulle
/// part ailleurs.
struct ProgressionDeKomga: Decodable, Sendable {
    let page: Int?
    let completed: Bool?
    let readDate: String?
}

/// Une page de livre telle que Komga la rend.
struct PageDeLivreDeKomga: Decodable, Sendable {
    let number: Int
    let fileName: String?
    let sizeBytes: Int?
}

// MARK: - Traduction vers les entites distantes

extension SerieDeKomga {
    /// La serie traduite pour le reste de l application.
    ///
    /// Le titre des metadonnees prime sur le nom du dossier : c est celui que
    /// l utilisateur a corrige dans Komga, et afficher le nom du dossier
    /// annulerait sa correction a chaque analyse.
    func mangaDistant(base: URL) -> MangaDistant {
        MangaDistant(
            identifiant: id,
            titre: titreAffiche,
            auteurs: booksMetadata?.auteursPrincipaux ?? [],
            resume: resumeAffiche,
            genres: metadata?.genres ?? [],
            statut: StatutSerie.depuisKomga(metadata?.status),
            langue: metadata?.language?.sansBlancs,
            urlCouverture: base.appending(path: "api/v1/series/\(id)/thumbnail").absoluteString,
            nombreChapitres: booksCount
        )
    }

    private var titreAffiche: String {
        metadata?.title?.sansBlancs ?? name?.sansBlancs ?? id
    }

    /// Le resume de la serie, ou celui agrege depuis ses livres.
    ///
    /// Komga laisse le premier vide tant que personne ne l a saisi, et remplit
    /// le second depuis le `ComicInfo.xml` du premier tome. Preferer un champ
    /// vide au resume reellement disponible afficherait une fiche nue alors que
    /// le texte est la.
    private var resumeAffiche: String? {
        metadata?.summary?.sansBlancs ?? booksMetadata?.summary?.sansBlancs
    }
}

extension MetadonneesDesLivresDeKomga {
    /// Les auteurs a afficher, dans l ordre rendu par le serveur.
    ///
    /// Komga liste tout le monde, du scenariste au lettreur. La fiche n affiche
    /// que ceux qui ecrivent et dessinent : une liste de douze noms dont dix
    /// sont des roles techniques ne renseigne personne. Quand aucun role connu
    /// ne ressort, toute la liste est rendue plutot que rien.
    var auteursPrincipaux: [String] {
        let tous = authors ?? []
        let principaux = tous.filter { auteur in
            guard let role = auteur.role?.lowercased() else {
                return false
            }

            return Self.rolesPrincipaux.contains(role)
        }
        let retenus = principaux.isEmpty ? tous : principaux

        return retenus.map(\.name).sansDoublons()
    }

    /// Les roles qui designent un auteur au sens de la fiche de serie.
    private static let rolesPrincipaux: Set<String> = ["writer", "penciller", "artist", "author"]
}

extension LivreDeKomga {
    /// Le livre traduit en chapitre, a son rang dans la serie.
    ///
    /// Le rang est passe par l appelant et non deduit du numero : la section
    /// 4.1 dit que c est le rang qui ordonne la liste, jamais le numero, et un
    /// serveur ou deux tomes portent le meme numero existe.
    func chapitreDistant(ordre: Int, identifiantSerie: String) -> ChapitreDistant {
        ChapitreDistant(
            identifiant: id,
            identifiantManga: seriesId ?? identifiantSerie,
            numero: numeroDeLecture(ordre: ordre),
            titre: metadata?.title?.sansBlancs ?? name?.sansBlancs,
            datePublication: LecteurDeDateKomga.lire(metadata?.releaseDate),
            nombrePages: nombreDePagesConnu,
            ordre: ordre
        )
    }

    /// Le numero annonce, avec ses deux replis.
    ///
    /// `numberSort` est le champ numerique de Komga et c est celui qui compte.
    /// Quand il manque, le numero textuel est tente, parce qu il vaut souvent
    /// `12` ou `12.5`. Quand les deux manquent, le rang sert de numero : il est
    /// faux, mais il est croissant, ce qui vaut mieux qu une colonne de zeros.
    private func numeroDeLecture(ordre: Int) -> Double {
        if let numberSort = metadata?.numberSort {
            return numberSort
        }
        if let texte = metadata?.number, let valeur = Double(texte) {
            return valeur
        }

        return Double(ordre + 1)
    }

    /// Nombre de pages, nul quand le serveur n a pas encore analyse le fichier.
    ///
    /// Zero veut dire inconnu chez Komga, pas vide : un livre en attente
    /// d analyse rend zero. Le laisser passer marquerait le chapitre lu des son
    /// ouverture, la part lue etant alors calculee sur un total nul.
    private var nombreDePagesConnu: Int? {
        guard let pages = media?.pagesCount, pages > 0 else {
            return nil
        }

        return pages
    }

    /// La progression du serveur, ramenee a l index de page du modele.
    func progressionDistante(nombreDePages: Int) -> ProgressionDistante? {
        guard let readProgress else {
            return nil
        }

        return ProgressionDistante(
            identifiantChapitre: id,
            // Komga compte les pages a partir de un, le modele a partir de
            // zero. C est ici, et uniquement ici, que l ecart se resorbe.
            pageAtteinte: max(0, (readProgress.page ?? 1) - 1),
            nombreDePages: nombreDePages,
            estLu: readProgress.completed ?? false,
            dateDeLecture: LecteurDeDateKomga.lire(readProgress.readDate)
        )
    }
}

extension PageDeLivreDeKomga {
    /// La page traduite, avec l adresse a laquelle son image se telecharge.
    func pageDistante(base: URL, livre: String) -> PageDistante {
        PageDistante(
            identifiantChapitre: livre,
            // Komga numerote ses pages a partir de un.
            index: max(0, number - 1),
            emplacement: base.appending(path: "api/v1/books/\(livre)/pages/\(number)"),
            octets: sizeBytes
        )
    }
}

// MARK: - Correspondances de vocabulaire

extension StatutSerie {
    /// Le statut editorial de Komga, traduit vers celui du domaine.
    ///
    /// Un statut inconnu devient `inconnu` plutot que de lever : une version de
    /// serveur qui ajoute un statut ne doit pas rendre tout son catalogue
    /// illisible pour un mot que nous ne connaissons pas encore.
    static func depuisKomga(_ statut: String?) -> StatutSerie {
        switch statut?.uppercased() {
        case "ONGOING": .enCours
        case "ENDED": .termine
        case "HIATUS": .enPause
        case "ABANDONED": .abandonne
        default: .inconnu
        }
    }

    /// Le mot que Komga attend pour ce statut, nul quand il n en a pas.
    var motDeKomga: String? {
        switch self {
        case .enCours: "ONGOING"
        case .termine: "ENDED"
        case .enPause: "HIATUS"
        case .abandonne: "ABANDONED"
        case .inconnu: nil
        }
    }
}

/// Lecture des dates rendues par Komga.
///
/// Le serveur en emploie trois formes selon le champ : une date seule pour la
/// date de parution, un instant avec fuseau pour la date de lecture, et un
/// instant sans fuseau pour ses propres horodatages. Un seul lecteur pour les
/// trois, essayes dans l ordre, parce qu un lecteur par champ multiplierait les
/// endroits ou une forme nouvelle passerait au travers.
enum LecteurDeDateKomga {
    /// La date lue, ou nul quand la chaine est absente ou d une autre forme.
    static func lire(_ texte: String?) -> Date? {
        guard let texte = texte?.trimmingCharacters(in: .whitespacesAndNewlines), texte.isEmpty == false else {
            return nil
        }
        if let avecFraction = lecteurAvecFraction.date(from: texte) {
            return avecFraction
        }
        if let sansFraction = lecteurSansFraction.date(from: texte) {
            return sansFraction
        }
        if let sansFuseau = lecteurSansFuseau.date(from: texte) {
            return sansFuseau
        }

        return lecteurDeJour.date(from: texte)
    }

    /// Lecteurs des instants avec fuseau, avec puis sans fraction de seconde.
    ///
    /// Ils sont ecrits en `DateFormatter` et non en `ISO8601DateFormatter`, qui
    /// serait plus court : ce dernier n est pas `Sendable`, et une instance
    /// partagee entre plusieurs taches ne compile pas en concurrence stricte.
    /// Le motif `XXXXX` accepte les deux ecritures du fuseau, `Z` et `+01:00`.
    private static let lecteurAvecFraction = formateur("yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX")

    private static let lecteurSansFraction = formateur("yyyy-MM-dd'T'HH:mm:ssXXXXX")

    /// Lecteur des instants sans fuseau, que Komga rend pour ses horodatages.
    ///
    /// Le fuseau est fixe a GMT parce que le serveur publie ces instants en
    /// temps universel sans le dire. Laisser le fuseau de l appareil decider
    /// decalerait la date affichee de plusieurs heures selon le voyage.
    private static let lecteurSansFuseau = formateur("yyyy-MM-dd'T'HH:mm:ss")

    private static let lecteurDeJour = formateur("yyyy-MM-dd")

    private static func formateur(_ format: String) -> DateFormatter {
        let lecteur = DateFormatter()
        lecteur.locale = Locale(identifier: "en_US_POSIX")
        lecteur.timeZone = TimeZone(secondsFromGMT: 0)
        lecteur.dateFormat = format

        return lecteur
    }
}

// MARK: - Outils de chaine

extension String {
    /// La chaine debarrassee de ses blancs, ou nul quand il ne reste rien.
    ///
    /// Komga rend une chaine vide la ou il n a rien, jamais nul. Sans ce
    /// filtre, une fiche afficherait une ligne de resume vide et une langue
    /// vide, que le modele est cense declarer absentes.
    var sansBlancs: String? {
        let nettoyee = trimmingCharacters(in: .whitespacesAndNewlines)

        return nettoyee.isEmpty ? nil : nettoyee
    }
}

extension Array where Element: Hashable {
    /// Les elements sans doublon, dans l ordre de premiere apparition.
    func sansDoublons() -> [Element] {
        var vus: Set<Element> = []

        return filter { vus.insert($0).inserted }
    }
}
