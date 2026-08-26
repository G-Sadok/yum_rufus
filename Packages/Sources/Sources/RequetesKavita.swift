import Core
import Foundation

//
// RequetesKavita
//
// Les chemins de l API de Kavita, ses parametres de requete, et les corps
// qu elle attend en publication.
//
// Ils vivent a part pour la meme raison que ceux de Komga : ils forment le
// vocabulaire du serveur et non sa logique, et c est la seule partie de la
// source qui change quand une version renomme un point d entree.
//
// Deux conventions de Kavita sont resorbees ici et nulle part ailleurs.
//
// La premiere est la numerotation des pages de resultats. Kavita compte ses
// tranches a partir de un, le protocole de la section 4.1 compte a partir de
// zero. La conversion se fait dans `tranche(page:taille:)`, une seule fois.
//
// La seconde est la cle d API dans l adresse des images. Kavita sert ses images
// a des balises `img`, qui ne posent aucun entete : le compte est donc identifie
// par un parametre de requete. C est cette cle, et non le jeton, qui fait
// qu une page continue de s afficher pendant qu une session se renouvelle.
//

/// Les chemins de l API de Kavita.
enum CheminsKavita {
    // MARK: Authentification

    static let connexion = "api/Account/login"
    static let rafraichissement = "api/Account/refresh-token"
    static let authentificationParCle = "api/Plugin/authenticate"

    // MARK: Catalogue

    static let toutesLesSeries = "api/Series/all-v2"
    static let recherche = "api/Search/search"
    static let metadonneesDeSerie = "api/Series/metadata"
    static let volumes = "api/Series/volumes"

    static func serie(_ identifiant: Int) -> String {
        "api/Series/\(identifiant)"
    }

    // MARK: Lecture

    static let infoDeChapitre = "api/Reader/chapter-info"
    static let imageDePage = "api/Reader/image"
    static let progressionLue = "api/Reader/get-progress"
    static let progressionPubliee = "api/Reader/progress"

    // MARK: Images

    static let couvertureDeSerie = "api/Image/series-cover"
}

/// Les parametres de requete de l API de Kavita.
enum ParametresKavita {
    /// La tranche demandee, dans la numerotation du serveur.
    ///
    /// Kavita compte ses pages a partir de un. Une source qui enverrait le
    /// numero du modele tel quel rendrait deux fois la premiere tranche et ne
    /// verrait jamais la derniere.
    static func tranche(page: Int, taille: Int) -> [URLQueryItem] {
        [
            URLQueryItem(name: "PageNumber", value: String(max(0, page) + 1)),
            URLQueryItem(name: "PageSize", value: String(max(1, taille))),
        ]
    }

    static func serie(_ identifiant: Int) -> [URLQueryItem] {
        [URLQueryItem(name: "seriesId", value: String(identifiant))]
    }

    static func chapitre(_ identifiant: Int) -> [URLQueryItem] {
        [URLQueryItem(name: "chapterId", value: String(identifiant))]
    }

    /// La recherche plein texte, telle que l ecran de recherche de Kavita
    /// l envoie.
    ///
    /// Les chapitres et les fichiers sont ecartes du resultat : la source rend
    /// des series, et une liste ou un chapitre isole voisine avec sa propre
    /// serie ferait ouvrir deux fiches differentes pour le meme titre.
    static func recherche(_ texte: String) -> [URLQueryItem] {
        [
            URLQueryItem(name: "queryString", value: texte),
            URLQueryItem(name: "includeChapterAndFiles", value: "false"),
        ]
    }

    /// L authentification par cle d API du point d entree des extensions.
    ///
    /// Le nom d extension est envoye parce que le serveur le journalise et le
    /// montre a l administrateur dans sa liste des sessions. Le laisser vide
    /// afficherait une ligne anonyme dans le journal du serveur de
    /// l utilisateur.
    static func authentificationParCle(_ cle: String) -> [URLQueryItem] {
        [
            URLQueryItem(name: "apiKey", value: cle),
            URLQueryItem(name: "pluginName", value: nomDuClient),
        ]
    }

    /// L adresse d une image, avec la cle d API quand la session en connait une.
    ///
    /// Sans cle, l adresse part quand meme : la requete portera alors l entete
    /// d identite, ce qui fonctionne tant que le jeton vaut. C est le mode
    /// degrade d une source configuree par jeton brut, ou aucune cle n a jamais
    /// ete rendue par le serveur.
    static func image(_ parametres: [URLQueryItem], cleDApi: String?) -> [URLQueryItem] {
        guard let cleDApi else {
            return parametres
        }

        return parametres + [URLQueryItem(name: "apiKey", value: cleDApi)]
    }

    /// La page demandee dans une adresse d image.
    ///
    /// Kavita indexe ses pages a partir de zero, comme le modele. Il n y a donc
    /// aucune conversion ici, et cette absence est intentionnelle : Komga, lui,
    /// compte a partir de un, et recopier sa conversion decalerait tout un
    /// chapitre d une page.
    static func page(chapitre: Int, index: Int) -> [URLQueryItem] {
        [
            URLQueryItem(name: "chapterId", value: String(chapitre)),
            URLQueryItem(name: "page", value: String(max(0, index))),
        ]
    }

    /// Nom sous lequel le client se presente aux journaux du serveur.
    private static let nomDuClient = "Tsuzuki"
}

// MARK: - Corps envoyes au serveur

/// Ce que la source envoie pour ouvrir une session.
struct DemandeDeConnexionKavita: Encodable, Sendable {
    let username: String
    let password: String
}

/// Ce que la source envoie pour prolonger une session.
///
/// Les deux jetons partent ensemble parce que le serveur verifie que le jeton
/// de rafraichissement appartient bien au jeton d acces presente. Envoyer le
/// seul jeton de rafraichissement laisserait un jeton vole prolonger n importe
/// quelle session.
struct DemandeDeRafraichissementKavita: Encodable, Sendable {
    let token: String
    let refreshToken: String
}

/// Le tri demande au catalogue.
///
/// Les valeurs sont les ordinaux de l enumeration `SortField` du serveur. Elles
/// sont nommees ici plutot que recopiees a l appel : ce sont les seuls nombres
/// du fichier dont le sens ne se lit pas, et une version de Kavita qui les
/// renumeroterait se corrige a un seul endroit.
struct TriDeKavita: Encodable, Sendable {
    let sortField: Int
    let isAscending: Bool

    /// Tri sur le titre de classement, celui du catalogue complet.
    static let parTitre = TriDeKavita(sortField: 1, isAscending: true)

    /// Tri sur l arrivee du dernier chapitre.
    ///
    /// La section recentes est definie par la section 4.1 comme les series
    /// recemment ajoutees ou mises a jour. Un nouveau chapitre dans une vieille
    /// serie compte donc autant qu une serie neuve, ce que la date de creation
    /// de la serie ne dirait pas.
    static let parDernierChapitre = TriDeKavita(sortField: 4, isAscending: false)

    /// Le tri qui correspond a la section demandee, ou nul quand la source ne
    /// sait pas la servir.
    init?(_ section: SectionCatalogue) {
        switch section {
        case .tout:
            self = .parTitre
        case .recentes:
            self = .parDernierChapitre
        case .populaires:
            // Kavita ne mesure aucune popularite. Rendre le catalogue complet
            // sous ce nom serait un classement invente.
            return nil
        }
    }

    private init(sortField: Int, isAscending: Bool) {
        self.sortField = sortField
        self.isAscending = isAscending
    }
}

/// Une clause de filtre de Kavita.
///
/// Le type est declare sans champ et n est jamais instancie : la source
/// n envoie aucune clause, et ne declare donc pas la capacite `filtres`. Il
/// existe pour que le tableau `statements` parte avec un type qui dit ce qu il
/// contiendra, et pour que l arrivee des filtres se voie ici et nulle part
/// ailleurs.
struct ClauseDeKavita: Encodable, Sendable {}

/// Le filtre envoye au catalogue.
///
/// Il ne porte qu un tri. La grammaire de filtre de Kavita designe ses champs
/// et ses comparaisons par des ordinaux, et une source qui les inventerait
/// rendrait des resultats qui ne correspondent pas a ce qui est demande, ce que
/// la section 4.1 interdit explicitement. Tant que ces ordinaux ne sont pas
/// verifies contre un serveur reel, la source refuse les filtres au lieu de les
/// approximer.
struct FiltreDeKavita: Encodable, Sendable {
    let statements: [ClauseDeKavita]
    let combination: Int
    let limitTo: Int
    let sortOptions: TriDeKavita

    init(tri: TriDeKavita) {
        statements = []
        // Combinaison par et, sans effet sur une liste de clauses vide.
        combination = 0
        // Zero veut dire aucune limite chez Kavita, la pagination s en charge.
        limitTo = 0
        sortOptions = tri
    }
}

/// Ce que la source envoie pour deplacer la progression d un chapitre.
///
/// Les quatre identifiants sont exiges par le serveur, qui s en sert pour
/// mettre a jour ses compteurs de serie et de bibliotheque en meme temps que la
/// ligne du chapitre. Les envoyer a zero laisserait la progression enregistree
/// mais les compteurs de la grille inchanges.
struct ChargeDeProgressionKavita: Encodable, Sendable {
    let chapterId: Int
    let volumeId: Int
    let seriesId: Int
    let libraryId: Int
    let pageNum: Int

    init(_ progression: ProgressionDistante, repere: RepereDeChapitreKavita) {
        chapterId = repere.chapitre
        volumeId = repere.volume ?? 0
        seriesId = repere.serie ?? 0
        libraryId = repere.bibliotheque ?? 0
        pageNum = Self.pageDeKavita(progression, nombreDePages: repere.nombreDePages)
    }

    /// Une progression remise a zero, ce que le marquage comme non lu produit.
    ///
    /// Kavita n a pas de point d entree qui efface la progression d un seul
    /// chapitre : il a un marquage par serie et un par volume. Remettre la page
    /// a zero produit exactement l etat vise, un chapitre sans page lue, par le
    /// point d entree que la source emploie deja.
    init(remiseAZero repere: RepereDeChapitreKavita) {
        chapterId = repere.chapitre
        volumeId = repere.volume ?? 0
        seriesId = repere.serie ?? 0
        libraryId = repere.bibliotheque ?? 0
        pageNum = 0
    }

    /// La page a envoyer, dans la convention du serveur.
    ///
    /// Kavita indexe ses pages a partir de zero comme le modele, il n y a donc
    /// aucun decalage d une unite a resorber. Le seul ecart porte sur le
    /// marquage : le serveur considere un chapitre lu quand le nombre de pages
    /// lues atteint son total, donc un chapitre lu s envoie a son nombre de
    /// pages et non a l index de sa derniere page.
    private static func pageDeKavita(_ progression: ProgressionDistante, nombreDePages: Int) -> Int {
        let total = nombreDePages > 0 ? nombreDePages : progression.nombreDePages

        guard progression.estLu == false else {
            return max(total, progression.pageAtteinte + 1)
        }
        guard total > 0 else {
            return progression.pageAtteinte
        }

        return min(progression.pageAtteinte, total - 1)
    }
}
