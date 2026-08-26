import Core
import Foundation
@testable import Sources

//
// ServeurKavitaDeTest
//
// Le montage d une source Kavita sans serveur : les regles que le transport
// fige doit servir, le trousseau volatil, et l horloge.
//
// Il est separe des reponses figees parce que les deux changent pour des
// raisons differentes. Les reponses changent quand le serveur change de forme,
// le montage change quand la source change de chemin. Les reunir ferait relire
// trois cents lignes de JSON a chaque fois qu une route bouge.
//
// L horloge est fixe, et c est ce qui rend les tests de jeton reproductibles.
// Un jeton fabrique autour de l heure reelle passerait au vert aujourd hui et
// au rouge le jour ou la marge d expiration changerait, sans que personne ne
// comprenne pourquoi.
//

/// Ce qu il faut pour interroger une source Kavita sans serveur.
struct ServeurKavitaDeTest {
    let transport: TransportFige
    let magasin = MagasinDIdentifiantsEnMemoire()
    let id = SourceID()
    let nom = "Kavita de test"

    static let compte = "lecteur"
    static let motDePasse = "phrase-de-passe-de-test"

    /// La cle d API du compte, celle que le serveur rend a la connexion.
    static let cleDApi = "cle-image-de-test"

    /// L horloge figee du serveur de test.
    static let maintenant = Date(timeIntervalSince1970: 1_800_000_000)

    /// Le jeton que le serveur rend, valable une heure.
    static var jetonValable: String {
        JetonDeTest.jwt(expirantA: maintenant.addingTimeInterval(3600))
    }

    /// Un jeton deja perime a l horloge du test.
    static var jetonPerime: String {
        JetonDeTest.jwt(expirantA: maintenant.addingTimeInterval(-60))
    }

    init(_ regles: [RegleDeTransport]) {
        transport = TransportFige(regles)
    }

    /// Les regles qui servent un catalogue complet, de la connexion aux pages.
    ///
    /// L ordre compte : la premiere regle qui correspond gagne, et les regles
    /// sont reconnues par la fin du chemin. Les plus precises viennent donc
    /// d abord, sans quoi la regle des metadonnees de n importe quelle serie
    /// masquerait celle de la serie de reference.
    static var reglesCompletes: [RegleDeTransport] {
        authentification + catalogue + lecture
    }

    /// Les trois points d entree qui rendent un jeton.
    static var authentification: [RegleDeTransport] {
        [
            .json(.post, CheminsKavita.connexion, ReponsesFigeesDeKavita.connexion(jeton: jetonValable)),
            .json(
                .post,
                CheminsKavita.rafraichissement,
                ReponsesFigeesDeKavita.rafraichissement(jeton: jetonValable)
            ),
            .json(
                .post,
                CheminsKavita.authentificationParCle,
                ReponsesFigeesDeKavita.connexion(jeton: jetonValable)
            ),
        ]
    }

    /// Le catalogue, ses deux tranches et sa recherche.
    static var catalogue: [RegleDeTransport] {
        let serie = ReponsesFigeesDeKavita.identifiantDeSerie

        return [
            .json(.get, CheminsKavita.recherche, ReponsesFigeesDeKavita.resultatsDeRecherche),
            .json(
                .get,
                CheminsKavita.metadonneesDeSerie,
                ReponsesFigeesDeKavita.metadonneesDeSerie,
                quand: ["seriesId": String(serie)]
            ),
            .json(.get, CheminsKavita.metadonneesDeSerie, ReponsesFigeesDeKavita.metadonneesInconnues),
            .json(.get, CheminsKavita.serie(serie), ReponsesFigeesDeKavita.detailDeSerie),
            .json(
                .post,
                CheminsKavita.toutesLesSeries,
                ReponsesFigeesDeKavita.premiereTrancheDeSeries,
                quand: ["PageNumber": "1"],
                entetes: ["X-Pagination": ReponsesFigeesDeKavita.paginationPremiereTranche]
            ),
            .json(
                .post,
                CheminsKavita.toutesLesSeries,
                ReponsesFigeesDeKavita.secondeTrancheDeSeries,
                quand: ["PageNumber": "2"],
                entetes: ["X-Pagination": ReponsesFigeesDeKavita.paginationDerniereTranche]
            ),
        ]
    }

    /// Les volumes, le chapitre et sa progression.
    static var lecture: [RegleDeTransport] {
        [
            .json(.get, CheminsKavita.infoDeChapitre, ReponsesFigeesDeKavita.infoDuPremierChapitre),
            .json(.get, CheminsKavita.progressionLue, ReponsesFigeesDeKavita.progressionEnCours),
            .json(.post, CheminsKavita.progressionPubliee, "{}"),
            .json(.get, CheminsKavita.volumes, ReponsesFigeesDeKavita.volumesDeLaSerie),
        ]
    }

    /// La source, avec ses identifiants deja ranges dans le trousseau.
    func source(
        identifiants: IdentifiantsDeSource = .basique(
            compte: ServeurKavitaDeTest.compte,
            motDePasse: ServeurKavitaDeTest.motDePasse
        ),
        adresse: URL? = ReponsesFigeesDeKavita.adresse,
        accepteLeHttpEnClair: Bool = false,
        tailleDePage: Int = 2
    ) async throws -> SourceKavita {
        await magasin.enregistrer(identifiants, pour: id)

        return try SourceKavita(
            id: id,
            nom: nom,
            configuration: ConfigurationDeSource(
                adresse: adresse,
                authentification: identifiants.nature,
                accepteLeHttpEnClair: accepteLeHttpEnClair
            ),
            magasin: magasin,
            transport: transport,
            tailleDePage: tailleDePage,
            maintenant: { Self.maintenant }
        )
    }

    /// Le nombre de requetes recues sur un chemin, quelle que soit la methode.
    func requetesVers(_ chemin: String) async -> Int {
        await transport.journal.count { $0.chemin.hasSuffix(chemin) }
    }

    /// Les regles completes, avec une regle prioritaire qui les surcharge.
    static func reglesSurchargees(par prioritaire: RegleDeTransport) -> [RegleDeTransport] {
        [prioritaire] + reglesCompletes
    }
}

// MARK: - Fabrique de jetons

/// Fabrique des jetons JWT dont l echeance est choisie par le test.
enum JetonDeTest {
    /// Un jeton bien forme, dont la revendication d echeance est celle demandee.
    static func jwt(expirantA echeance: Date) -> String {
        let entete = base64Url(#"{"alg":"HS256","typ":"JWT"}"#)
        let charge = base64Url("{\"exp\":\(Int(echeance.timeIntervalSince1970)),\"nameid\":\"lecteur\"}")

        // La signature n est pas calculee : le client ne la verifie pas, et il
        // ne le doit pas. Elle est la pour que le jeton ait bien trois segments.
        return "\(entete).\(charge).signature-non-verifiee"
    }

    /// Un jeton que le client ne sait pas dater, faute d etre un JWT.
    ///
    /// Il sert aux tests de refus : sans echeance lisible, le client le croit
    /// valable et ne decouvre le contraire que par la reponse du serveur, ce qui
    /// est exactement le chemin qu il faut couvrir.
    static let opaque = "jeton-sans-echeance-lisible"

    /// Un jeton a trois segments dont la charge utile ne porte aucune echeance.
    static let sansEcheance: String = {
        let charge = Data(#"{"nameid":"lecteur"}"#.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "=", with: "")

        return "entete.\(charge).signature"
    }()

    private static func base64Url(_ texte: String) -> String {
        Data(texte.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
