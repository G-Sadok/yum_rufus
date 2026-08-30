import Foundation

//
// ProtocoleDeSource
//
// Le protocole unique de la section 4.1 du cahier de developpement. Du dossier
// local au serveur distant, toutes les sources passent par la.
//
// Le protocole est dans Core et non dans Sources, pour la meme raison que
// `DocumentLocal` : la couche vue, la bibliotheque et le moteur de lecture
// parlent aux sources sans jamais dependre de leurs implementations. Sources ne
// porte que les implementations.
//

/// Ce qu une source sait faire.
///
/// L interface ne propose que les actions correspondant aux capacites
/// declarees. Une capacite est donc un engagement, pas une intention : une
/// source qui declare `recherche` sert une recherche, et une source qui ne la
/// declare pas leve `ErreurDeSource.capaciteIndisponible` si on l appelle
/// quand meme, plutot que de rendre un resultat approximatif.
public struct SourceCapacites: OptionSet, Sendable, Hashable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// La source sait filtrer son catalogue sur un texte.
    public static let recherche = SourceCapacites(rawValue: 1 << 0)

    /// La source sait restreindre une requete sur des genres ou un statut.
    public static let filtres = SourceCapacites(rawValue: 1 << 1)

    /// La source rend son catalogue par pages et sait dire s il en reste.
    public static let pagination = SourceCapacites(rawValue: 1 << 2)

    /// La source expose des pages telechargeables pour la lecture hors ligne.
    public static let telechargement = SourceCapacites(rawValue: 1 << 3)

    /// La source tient une progression de lecture cote serveur.
    public static let progressionDistante = SourceCapacites(rawValue: 1 << 4)

    /// La source publie le meme contenu en plusieurs langues.
    public static let plusieursLangues = SourceCapacites(rawValue: 1 << 5)

    /// La source accepte d etre relue periodiquement a la recherche de
    /// chapitres parus depuis la derniere visite.
    ///
    /// La capacite existe parce que toutes les sources ne peuvent pas etre
    /// relues sans consequence. Un dossier local repond en quelques
    /// millisecondes et sans reseau, un catalogue ouvert repond au prix d une
    /// requete qui compte dans le quota de l appareil et dans la charge du
    /// serveur d en face. La veille de F060 n interroge donc que les sources
    /// qui la declarent, exactement comme la recherche n interroge que celles
    /// qui declarent `recherche`.
    public static let veilleDeNouveautes = SourceCapacites(rawValue: 1 << 6)

    /// Les sept capacites, une par une.
    ///
    /// Sert aux interfaces qui affichent ce qu une source sait faire, et aux
    /// tests qui verifient qu une capacite declaree correspond bien a une
    /// fonction offerte.
    public static let connues: [SourceCapacites] = [
        .recherche,
        .filtres,
        .pagination,
        .telechargement,
        .progressionDistante,
        .plusieursLangues,
        .veilleDeNouveautes,
    ]
}

/// Une source de contenu, quelle que soit sa nature.
///
/// Toutes les methodes sont asynchrones parce que la plus lente decide de la
/// signature : une lecture de dossier repond en quelques millisecondes, un
/// serveur en quelques secondes. Elles sont aussi annulables, l annulation
/// etant propagee par les points de suspension.
public protocol SourceProvider: Sendable {
    /// Identite de la source configuree.
    var id: SourceID { get }

    /// Nom lisible, tel qu il est affiche dans la liste des sources.
    var nom: String { get }

    /// Ce que la source sait reellement faire.
    var capacites: SourceCapacites { get }

    /// Verifie que la source repond et rend l etat a afficher.
    ///
    /// Ne leve pas quand la source est injoignable : une source hors ligne est
    /// un etat normal, pas une erreur de programmation. Elle rend alors
    /// `EtatConnexion.injoignable`.
    func verifierConnexion() async -> EtatConnexion

    /// Cherche dans le catalogue de la source.
    ///
    /// - Throws: `ErreurDeSource.capaciteIndisponible` quand la source ne
    ///   declare pas `SourceCapacites.recherche`, ou quand la requete demande
    ///   une capacite non declaree, filtres ou langue.
    func rechercher(_ requete: RequeteRecherche) async throws -> PageResultats<MangaDistant>

    /// Parcourt une section du catalogue.
    ///
    /// - Throws: `ErreurDeSource.sectionNonPriseEnCharge` quand la source ne
    ///   sert pas cette section.
    func parcourir(_ section: SectionCatalogue, page: Int) async throws -> PageResultats<MangaDistant>

    /// Rend le detail d une serie.
    ///
    /// - Throws: `ErreurDeSource.mangaIntrouvable` quand l identifiant ne
    ///   designe rien chez cette source.
    func detailsManga(_ identifiant: String) async throws -> MangaDistant

    /// Rend les chapitres d une serie, dans l ordre de lecture.
    func chapitres(pour identifiant: String) async throws -> [ChapitreDistant]

    /// Rend les pages d un chapitre, dans l ordre de lecture.
    func pages(pour chapitre: String) async throws -> [PageDistante]

    /// Construit la requete reseau qui rapporte les octets d une page.
    ///
    /// - Throws: `ErreurDeSource.pageNonAdressableParRequete` quand la page ne
    ///   s obtient pas par une requete, par exemple une page rangee dans une
    ///   archive locale.
    func requeteImage(pour page: PageDistante) async throws -> URLRequest
}

extension SourceProvider {
    /// Vrai quand la source declare toutes les capacites demandees.
    public func declare(_ capacites: SourceCapacites) -> Bool {
        self.capacites.contains(capacites)
    }

    /// Leve si la capacite n est pas declaree.
    ///
    /// Point de passage unique des implementations, pour que le refus soit
    /// toujours la meme erreur typee et jamais un resultat vide.
    public func exiger(_ capacite: SourceCapacites) throws {
        guard capacites.contains(capacite) else {
            throw ErreurDeSource.capaciteIndisponible(capacite: capacite, source: nom)
        }
    }

    /// Les actions que l interface a le droit d offrir sur cette source.
    ///
    /// C est la lecture directe du tableau d `ActionDeSource`, faite ici pour
    /// que l ecran n ait ni a connaitre les capacites ni a refaire le calcul.
    public var actionsOffertes: Set<ActionDeSource> {
        capacites.actionsOffertes
    }

    /// Vrai quand cette action peut etre offerte par cette source.
    public func offre(_ action: ActionDeSource) -> Bool {
        capacites.offre(action)
    }

    /// Leve si l action n est pas offerte par cette source.
    ///
    /// Le pendant de `exiger(_:)` du cote de l interface : une action declenchee
    /// alors qu elle n aurait pas du etre affichee est refusee par la meme
    /// erreur typee que la capacite correspondante.
    public func exiger(_ action: ActionDeSource) throws {
        guard let capacite = action.capaciteRequise else {
            return
        }

        try exiger(capacite)
    }
}
