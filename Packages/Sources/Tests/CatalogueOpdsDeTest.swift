import Core
import Foundation
@testable import Sources

//
// CatalogueOpdsDeTest
//
// Le serveur des tests OPDS, et les regles de transport qui lui donnent ses
// reponses.
//
// Il est separe du jeu de flux figes pour la meme raison que chez les autres
// sources : les flux sont des documents que l on relit tels quels dans une
// revue, les regles sont du code. Les melanger rendrait le fichier de reponses
// illisible des la troisieme version du protocole.
//
// Un seul serveur publie les deux versions, sous deux chemins distincts. Ce
// n est pas un artifice de test : Komga publie `/opds/v1.2` et `/opds/v2` sur le
// meme hote, et deux serveurs separes cacheraient le fait que la version se
// deduit de la reponse et non de la configuration.
//

extension RegleDeTransport {
    /// Une reponse Atom acceptee, dont la longueur annoncee est la bonne.
    ///
    /// Le type de contenu est celui qu un serveur OPDS 1.2 pose reellement,
    /// profil compris. C est lui que l analyseur lit pour choisir sa version.
    static func atom(
        _ chemin: String,
        _ corps: String,
        code: Int = 200,
        quand parametres: [String: String] = [:]
    ) -> RegleDeTransport {
        contenu(
            chemin,
            corps,
            type: "application/atom+xml;profile=opds-catalog;kind=acquisition",
            code: code,
            quand: parametres
        )
    }

    /// Une reponse OPDS 2.0 acceptee.
    static func opdsJson(
        _ chemin: String,
        _ corps: String,
        code: Int = 200,
        quand parametres: [String: String] = [:]
    ) -> RegleDeTransport {
        contenu(chemin, corps, type: "application/opds+json", code: code, quand: parametres)
    }

    /// Une reponse de type quelconque, dont la longueur annoncee est la bonne.
    static func contenu(
        _ chemin: String,
        _ corps: String,
        type: String,
        code: Int = 200,
        quand parametres: [String: String] = [:]
    ) -> RegleDeTransport {
        let octets = Data(corps.utf8)

        return RegleDeTransport(
            methode: .get,
            chemin: chemin,
            reponse: ReponseHttp(
                code: code,
                entetes: ["Content-Type": type, "Content-Length": String(octets.count)],
                corps: octets
            ),
            parametresAttendus: parametres
        )
    }

    /// Une reponse binaire, celle d un conteneur rapatrie.
    static func binaire(_ chemin: String, _ octets: Data) -> RegleDeTransport {
        RegleDeTransport(
            methode: .get,
            chemin: chemin,
            reponse: ReponseHttp(
                code: 200,
                entetes: [
                    "Content-Type": "application/vnd.comicbook+zip",
                    "Content-Length": String(octets.count),
                ],
                corps: octets
            )
        )
    }
}

/// Un catalogue OPDS de test, avec ses deux versions et son trousseau volatil.
struct CatalogueOpdsDeTest {
    let transport: TransportFige
    let magasin = MagasinDIdentifiantsEnMemoire()
    let id = SourceID()
    let nom = "Catalogue de test"

    /// Compte et mot de passe de la source, tels qu ils seront ranges dans le
    /// trousseau volatil des tests.
    static let compte = "lecteur"
    static let motDePasse = "phrase-de-passe-de-test"

    /// L entete d authentification basique que ces identifiants produisent.
    static var enteteBasique: String {
        "Basic " + Data("\(compte):\(motDePasse)".utf8).base64EncodedString()
    }

    init(_ regles: [RegleDeTransport]) {
        transport = TransportFige(regles)
    }

    /// Les regles qui servent le catalogue entier, dans les deux versions.
    ///
    /// L ordre compte : la premiere regle qui correspond gagne, et une page
    /// suivante se distingue de la premiere par son seul parametre. Les regles
    /// les plus precises viennent donc d abord.
    static func reglesCompletes(conteneur: Data = Data()) -> [RegleDeTransport] {
        [
            .atom(
                ReponsesFigeesDOpds.cheminDeLaSerieAtom,
                ReponsesFigeesDOpds.seriePage2,
                quand: ["page": "1"]
            ),
            .atom(ReponsesFigeesDOpds.cheminDeLaSerieAtom, ReponsesFigeesDOpds.seriePage1),
            .atom(ReponsesFigeesDOpds.cheminDesNouveautesAtom, ReponsesFigeesDOpds.cataloguePage2),
            .atom(
                ReponsesFigeesDOpds.cheminDuCatalogueAtom,
                ReponsesFigeesDOpds.cataloguePage2,
                quand: ["page": "1"]
            ),
            .atom(ReponsesFigeesDOpds.cheminDuCatalogueAtom, ReponsesFigeesDOpds.cataloguePage1),
            .opdsJson(ReponsesFigeesDOpds.cheminDeLaSerieJson, ReponsesFigeesDOpds.serieJson),
            .opdsJson(
                ReponsesFigeesDOpds.cheminDuCatalogueJson,
                ReponsesFigeesDOpds.catalogueJsonPage2,
                quand: ["page": "1"]
            ),
            .opdsJson(
                ReponsesFigeesDOpds.cheminDuCatalogueJson,
                ReponsesFigeesDOpds.catalogueJsonPage1
            ),
            .binaire(ReponsesFigeesDOpds.cheminDuFichierDuSecondChapitre, conteneur),
            .binaire(ReponsesFigeesDOpds.cheminDuFichierDuPremierChapitre, conteneur),
        ]
    }

    /// La source, avec ses identifiants deja ranges dans le trousseau.
    func source(
        chemin: String = ReponsesFigeesDOpds.cheminDuCatalogueAtom,
        authentification: NatureDAuthentification = .basique,
        adresse: URL? = ReponsesFigeesDOpds.adresse,
        accepteLeHttpEnClair: Bool = false,
        dossierDeCache: URL? = nil
    ) async throws -> SourceOpds {
        await magasin.enregistrer(Self.identifiants(authentification), pour: id)

        return try SourceOpds(
            id: id,
            nom: nom,
            configuration: ConfigurationDeSource(
                adresse: adresse,
                chemin: chemin,
                authentification: authentification,
                accepteLeHttpEnClair: accepteLeHttpEnClair
            ),
            magasin: magasin,
            transport: transport,
            dossierDeCache: dossierDeCache
        )
    }

    private static func identifiants(_ nature: NatureDAuthentification) -> IdentifiantsDeSource {
        switch nature {
        case .aucune: .aucun
        case .basique: .basique(compte: compte, motDePasse: motDePasse)
        case .cleDApi: .cleDApi("cle-de-test")
        case .jeton: .jeton(acces: "jeton-de-test")
        }
    }
}
