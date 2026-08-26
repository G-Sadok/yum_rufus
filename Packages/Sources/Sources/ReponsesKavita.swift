import Core
import Foundation

//
// ReponsesKavita
//
// La forme exacte de ce que Kavita repond, et sa traduction vers les entites
// distantes de la section 4.1.
//
// Comme pour Komga, tous les champs sont optionnels sauf les identifiants. La
// raison est la meme et le risque aussi : Kavita a renomme plusieurs champs de
// numerotation entre deux versions majeures, `number` est devenu `minNumber`
// sur les volumes comme sur les chapitres, et un champ declare obligatoire
// ferait echouer le decodage de la reponse entiere, donc la source complete,
// sur un serveur d une version voisine.
//
// Trois pieges de ce serveur sont traites ici et nulle part ailleurs.
//
// Le premier est la date nulle. Kavita ecrit `0001-01-01T00:00:00` la ou il ne
// connait aucune date, au lieu de ne rien ecrire. La laisser passer afficherait
// une parution de l an un sur la moitie des chapitres.
//
// Le deuxieme est le titre recopie. Quand un chapitre n a pas de titre, Kavita
// remplit `title` avec son propre numero. L afficher donnerait une liste ou
// chaque ligne repete le numero deja affiche a cote.
//
// Le troisieme est le rangement des chapitres hors volume. Trois conventions
// coexistent selon les versions, et elles designent toutes la meme chose.
//

// MARK: - Authentification

/// Ce que Kavita repond a une connexion ou a un rafraichissement.
///
/// Le meme type sert aux deux, et a l authentification par cle : les trois
/// rendent la meme enveloppe, la reponse de rafraichissement etant simplement
/// plus courte. Trois types identiques a un champ pres auraient triple la
/// surface a maintenir sans rien distinguer.
struct JetonDeKavita: Decodable, Sendable {
    let token: String?
    let refreshToken: String?

    /// La cle d API du compte, rendue par la connexion mais pas par le
    /// rafraichissement.
    let apiKey: String?
}

// MARK: - Catalogue

/// Serie telle que Kavita la rend dans une liste ou en detail.
struct SerieDeKavita: Decodable, Sendable {
    let id: Int
    let name: String?
    let originalName: String?
    let localizedName: String?
}

/// Metadonnees editoriales d une serie, servies par un point d entree separe.
struct MetadonneesDeSerieDeKavita: Decodable, Sendable {
    let summary: String?
    let genres: [EtiquetteDeKavita]?
    let writers: [PersonneDeKavita]?
    let pencillers: [PersonneDeKavita]?
    let coverArtists: [PersonneDeKavita]?
    let publicationStatus: Int?
    let language: String?
}

/// Un genre ou une etiquette, tels que Kavita les nomme.
struct EtiquetteDeKavita: Decodable, Sendable {
    let title: String?
}

/// Une personne creditee sur une serie.
struct PersonneDeKavita: Decodable, Sendable {
    let name: String?
}

/// Resultat de recherche, dont la forme differe de celle du catalogue.
struct ResultatsDeRechercheDeKavita: Decodable, Sendable {
    let series: [ResultatDeSerieDeKavita]?
}

/// Une serie trouvee par la recherche.
///
/// Le champ d identifiant n a pas le meme nom que dans le catalogue, ou il
/// s appelle `id`. Ce n est pas une coquette : le point d entree de recherche
/// rend un type distinct cote serveur, qui melange series, collections et
/// personnes dans une meme enveloppe.
struct ResultatDeSerieDeKavita: Decodable, Sendable {
    let seriesId: Int
    let name: String?
    let localizedName: String?
}

/// La tranche annoncee par l entete de pagination.
///
/// Kavita ne met pas sa pagination dans le corps mais dans l entete
/// `X-Pagination`, qui porte un objet JSON. C est la seule reponse du projet
/// dont une partie utile arrive hors du corps.
struct TrancheDeKavita: Decodable, Sendable {
    let currentPage: Int?
    let totalPages: Int?

    /// La tranche lue depuis la valeur brute de l entete, ou nul.
    init?(entete: String?) {
        guard
            let entete = entete?.sansBlancs,
            let lue = try? JSONDecoder().decode(TrancheDeKavita.self, from: Data(entete.utf8))
        else {
            return nil
        }

        self = lue
    }

    /// Vrai quand une page suivante existe.
    var ilResteDesPages: Bool {
        guard let currentPage, let totalPages else {
            return false
        }

        return currentPage < totalPages
    }
}

// MARK: - Volumes et chapitres

/// Volume tel que Kavita le rend, avec ses chapitres.
struct VolumeDeKavita: Decodable, Sendable {
    let id: Int
    let name: String?
    let number: Int?
    let minNumber: Double?
    let chapters: [ChapitreDeKavita]?
}

/// Chapitre tel que Kavita le rend. Un chapitre est un chapitre pour nous.
struct ChapitreDeKavita: Decodable, Sendable {
    let id: Int
    let range: String?
    let number: String?
    let minNumber: Double?
    let pages: Int?
    let title: String?
    let titleName: String?
    let releaseDate: String?
}

/// Ce que Kavita sait d un chapitre au moment de l ouvrir.
///
/// Le point d entree qui rend ce type est celui que la liseuse du serveur
/// appelle avant d afficher la premiere page. Il porte donc a la fois le nombre
/// de pages et les trois identifiants dont la publication de progression a
/// besoin, ce qui evite d enchainer trois requetes pour les reunir.
struct InfoDeChapitreDeKavita: Decodable, Sendable {
    let pages: Int?
    let volumeId: Int?
    let seriesId: Int?
    let libraryId: Int?
}

/// Progression de lecture telle que Kavita la tient.
struct ProgressionDeKavita: Decodable, Sendable {
    let pageNum: Int?
    let lastModifiedUtc: String?
}

// MARK: - Traduction vers les entites distantes

extension SerieDeKavita {
    /// La serie traduite pour le reste de l application.
    ///
    /// - Parameter metadonnees: le second appel, quand la fiche complete est
    ///   demandee. Le catalogue, lui, ne les charge pas : une liste de cinquante
    ///   series paierait cinquante requetes supplementaires pour un resume que
    ///   la grille n affiche pas.
    func mangaDistant(
        base: URL,
        cleDApi: String?,
        metadonnees: MetadonneesDeSerieDeKavita? = nil
    ) -> MangaDistant {
        MangaDistant(
            identifiant: String(id),
            titre: titreAffiche,
            auteurs: metadonnees?.auteursPrincipaux ?? [],
            resume: metadonnees?.summary?.sansBlancs,
            genres: metadonnees?.genres?.compactMap { $0.title?.sansBlancs } ?? [],
            statut: StatutSerie.depuisKavita(metadonnees?.publicationStatus),
            langue: metadonnees?.language?.sansBlancs,
            urlCouverture: AdressesKavita.couverture(base: base, serie: id, cleDApi: cleDApi)
        )
    }

    /// Le titre a afficher, du plus corrige au plus brut.
    ///
    /// Le nom localise prime : c est celui que l utilisateur a saisi dans Kavita
    /// pour remplacer le nom du dossier, et preferer ce dernier annulerait sa
    /// correction a chaque analyse.
    private var titreAffiche: String {
        localizedName?.sansBlancs ?? name?.sansBlancs ?? originalName?.sansBlancs ?? String(id)
    }
}

extension ResultatDeSerieDeKavita {
    /// Le resultat de recherche traduit, sans metadonnees.
    ///
    /// La recherche de Kavita ne rend ni genres ni resume. La fiche les charge
    /// a l ouverture, et inventer des champs vides ici les afficherait comme
    /// absents alors qu ils existent.
    func mangaDistant(base: URL, cleDApi: String?) -> MangaDistant {
        MangaDistant(
            identifiant: String(seriesId),
            titre: localizedName?.sansBlancs ?? name?.sansBlancs ?? String(seriesId),
            urlCouverture: AdressesKavita.couverture(base: base, serie: seriesId, cleDApi: cleDApi)
        )
    }
}

extension MetadonneesDeSerieDeKavita {
    /// Les auteurs a afficher, scenaristes et dessinateurs d abord.
    ///
    /// Kavita range ses credits par role dans des listes separees, la ou Komga
    /// les melange avec une etiquette. La regle affichee est la meme : ceux qui
    /// ecrivent et dessinent, et a defaut les illustrateurs de couverture,
    /// plutot qu une fiche sans aucun nom.
    var auteursPrincipaux: [String] {
        let principaux = ((writers ?? []) + (pencillers ?? [])).compactMap { $0.name?.sansBlancs }

        guard principaux.isEmpty else {
            return principaux.sansDoublons()
        }

        return (coverArtists ?? []).compactMap { $0.name?.sansBlancs }.sansDoublons()
    }
}

extension InfoDeChapitreDeKavita {
    /// Le repere du chapitre, tel que la source le retient.
    func repere(chapitre identifiant: Int) -> RepereDeChapitreKavita {
        RepereDeChapitreKavita(
            chapitre: identifiant,
            volume: volumeId,
            serie: seriesId,
            bibliotheque: libraryId,
            // Zero veut dire inconnu, jamais vide : un chapitre en attente
            // d analyse rend zero, et le laisser passer marquerait le chapitre
            // lu des son ouverture, la part lue etant calculee sur un total nul.
            nombreDePages: max(0, pages ?? 0)
        )
    }
}

extension ProgressionDeKavita {
    /// La progression traduite, ou nul quand le serveur n en tient aucune.
    ///
    /// Kavita ne distingue pas un chapitre jamais ouvert d un chapitre ouvert a
    /// sa premiere page : les deux rendent une page zero. La date de derniere
    /// modification tranche, et sans elle une page zero est traitee comme une
    /// absence de progression. Annoncer une reprise a la page zero poserait une
    /// pastille de lecture en cours sur toute la bibliotheque.
    func progressionDistante(chapitre: String, nombreDePages: Int) -> ProgressionDistante? {
        let page = max(0, pageNum ?? 0)
        let date = LecteurDeDateKavita.lire(lastModifiedUtc)

        guard page > 0 || date != nil else {
            return nil
        }

        return ProgressionDistante(
            identifiantChapitre: chapitre,
            pageAtteinte: nombreDePages > 0 ? min(page, nombreDePages - 1) : page,
            nombreDePages: nombreDePages,
            // Le serveur ne publie aucun drapeau de lecture par chapitre : il
            // compare le nombre de pages lues au total. La comparaison est donc
            // refaite ici a l identique, et non deduite de la page atteinte, qui
            // est bornee juste au dessus.
            estLu: nombreDePages > 0 && page >= nombreDePages,
            dateDeLecture: date
        )
    }
}

// MARK: - Correspondances de vocabulaire

extension StatutSerie {
    /// Le statut editorial de Kavita, traduit vers celui du domaine.
    ///
    /// Kavita designe ses statuts par les ordinaux de son enumeration
    /// `PublicationStatus`. Un ordinal inconnu devient `inconnu` plutot que de
    /// lever : une version de serveur qui en ajoute un ne doit pas rendre tout
    /// son catalogue illisible.
    ///
    /// Les deux facons de conclure une serie chez Kavita, toutes les parutions
    /// publiees et recit acheve, se rejoignent sur `termine` : le domaine n en
    /// distingue qu une, et la nuance ne change rien a ce que la fiche affiche.
    static func depuisKavita(_ statut: Int?) -> StatutSerie {
        switch statut {
        case 0: .enCours
        case 1: .enPause
        case 2: .termine
        case 3: .abandonne
        case 4: .termine
        default: .inconnu
        }
    }
}

/// Lecture des dates rendues par Kavita.
///
/// Le serveur emploie les memes formes que les autres, a une exception pres qui
/// justifie ce detour : il ecrit la date minimale de sa plateforme la ou il ne
/// connait rien, au lieu de ne rien ecrire. Elle se decode parfaitement et
/// afficherait une parution de l an un.
enum LecteurDeDateKavita {
    /// La date lue, ou nul quand la chaine est absente, vide ou nulle au sens
    /// du serveur.
    static func lire(_ texte: String?) -> Date? {
        guard let texte = texte?.sansBlancs, texte.hasPrefix(dateNulle) == false else {
            return nil
        }

        return LecteurDeDateDeServeur.lire(texte)
    }

    /// La date que le serveur ecrit quand il n en connait aucune.
    private static let dateNulle = "0001-01-01"
}

// MARK: - Adresses

/// Construction des adresses d images de Kavita.
enum AdressesKavita {
    /// L adresse de la couverture d une serie, ou nul quand elle ne s assemble
    /// pas.
    ///
    /// L echec ne leve pas : une couverture manquante se remplace par un visuel
    /// de repli, alors qu une erreur remontee ferait echouer toute la tranche de
    /// catalogue pour une image.
    static func couverture(base: URL, serie: Int, cleDApi: String?) -> String? {
        try? ClientHttp.adresse(
            base: base,
            chemin: CheminsKavita.couvertureDeSerie,
            parametres: ParametresKavita.image(ParametresKavita.serie(serie), cleDApi: cleDApi)
        ).absoluteString
    }

    /// L adresse de l image d une page.
    ///
    /// Celle ci leve, contrairement a la couverture : une page dont l adresse ne
    /// s assemble pas est une page que le lecteur ne peut pas afficher, et la
    /// remplacer par un trou ferait une lecture avec des pages manquantes sans
    /// que rien ne le dise.
    static func page(base: URL, chapitre: Int, index: Int, cleDApi: String?) throws -> URL {
        try ClientHttp.adresse(
            base: base,
            chemin: CheminsKavita.imageDePage,
            parametres: ParametresKavita.image(
                ParametresKavita.page(chapitre: chapitre, index: index),
                cleDApi: cleDApi
            )
        )
    }
}
