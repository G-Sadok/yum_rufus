import Core
import Foundation
import Testing
@testable import Sources

//
// AnalyseDesReponsesKavitaTests
//
// Les quatre reponses que la strategie de test exige pour chaque source :
// figee, malformee, vide, tronquee. Plus ce qui est propre a Kavita et se
// verifie sans passer par le reseau, l ordre des chapitres et la lecture de son
// entete de pagination.
//
// Les quatre cas de reponse sont traites par `ClientHttp`, deja couvert du cote
// de Komga. Ils sont repris ici parce que le critere porte sur la source, et
// qu une source qui decoderait ses reponses ailleurs que par le client passerait
// les tests de Komga sans etre couverte.
//

struct AnalyseDesReponsesKavitaTests {
    // MARK: Reponses hors norme

    @Test("Une reponse qui n est pas du JSON est nommee illisible")
    func reponseMalformee() async throws {
        let serveur = ServeurKavitaDeTest(Self.regles(
            .json(.post, CheminsKavita.toutesLesSeries, ReponsesFigeesDeKavita.malformee)
        ))
        let source = try await serveur.source()

        await #expect(
            throws: ErreurDeSource.reseau(.reponseIllisible, source: serveur.nom)
        ) {
            _ = try await source.parcourir(.tout, page: 0)
        }
    }

    @Test("Une reponse vide est distinguee d une reponse illisible")
    func reponseVide() async throws {
        let serveur = ServeurKavitaDeTest(Self.regles(
            RegleDeTransport(
                methode: .post,
                chemin: CheminsKavita.toutesLesSeries,
                reponse: ReponseHttp(code: 200)
            )
        ))
        let source = try await serveur.source()

        // Les deux se reparent differemment, l une en reessayant, l autre en
        // corrigeant l adresse de la source.
        await #expect(throws: ErreurDeSource.reseau(.reponseVide, source: serveur.nom)) {
            _ = try await source.parcourir(.tout, page: 0)
        }
    }

    @Test("Une reponse coupee en route est nommee tronquee")
    func reponseTronquee() async throws {
        let serveur = ServeurKavitaDeTest(Self.regles(
            RegleDeTransport(
                methode: .post,
                chemin: CheminsKavita.toutesLesSeries,
                reponse: ReponseHttp(
                    code: 200,
                    entetes: ["Content-Length": "512"],
                    corps: Data(ReponsesFigeesDeKavita.troncature.utf8)
                )
            )
        ))
        let source = try await serveur.source()

        await #expect(throws: ErreurDeSource.reseau(.reponseTronquee, source: serveur.nom)) {
            _ = try await source.parcourir(.tout, page: 0)
        }
    }

    @Test("Une source en echec ne fait pas tomber les autres")
    func echecIsole() async throws {
        let cassee = ServeurKavitaDeTest(Self.regles(
            .json(.post, CheminsKavita.toutesLesSeries, ReponsesFigeesDeKavita.malformee)
        ))
        let saine = ServeurKavitaDeTest(ServeurKavitaDeTest.reglesCompletes)
        let premiere = try await cassee.source()
        let seconde = try await saine.source()

        _ = try? await premiere.parcourir(.tout, page: 0)

        // La seconde source ne sait rien de l echec de la premiere et repond
        // normalement.
        #expect(try await seconde.parcourir(.tout, page: 0).elements.isEmpty == false)
    }

    // MARK: Entete de pagination

    @Test("L entete de pagination est lu, y compris sur la derniere tranche")
    func entetesDePagination() {
        let premiere = TrancheDeKavita(entete: ReponsesFigeesDeKavita.paginationPremiereTranche)
        let derniere = TrancheDeKavita(entete: ReponsesFigeesDeKavita.paginationDerniereTranche)

        #expect(premiere?.ilResteDesPages == true)
        #expect(derniere?.ilResteDesPages == false)
    }

    @Test("Un entete de pagination absent ou casse ne se lit pas")
    func entetesDePaginationInvalides() {
        #expect(TrancheDeKavita(entete: nil) == nil)
        #expect(TrancheDeKavita(entete: "   ") == nil)
        #expect(TrancheDeKavita(entete: "pas du json") == nil)
        // Un objet JSON valable mais sans les deux champs attendus : la tranche
        // se construit et se declare derniere, plutot que de promettre une
        // suite qui n existe pas.
        #expect(TrancheDeKavita(entete: "{}")?.ilResteDesPages == false)
    }

    // MARK: Ordre de lecture

    @Test("Les trois conventions de chapitre hors volume se lisent apres les tomes")
    func chapitresHorsVolumeEnDernier() throws {
        // Le numero zero des versions anciennes, et les deux sentinelles des
        // versions recentes, l une pour les chapitres libres, l autre pour les
        // hors series.
        let conventions: [Double] = [0, 2_147_483_646, 2_147_483_647]

        for horsVolume in conventions {
            let volumes = try [
                Self.volume(identifiant: 1, numero: horsVolume, chapitres: [Self.chapitre(9, numero: 1)]),
                Self.volume(identifiant: 2, numero: 3, chapitres: [Self.chapitre(4, numero: 40)]),
            ]
            let ordonnes = OrdreDesChapitresKavita.ordonner(volumes)

            // Trie sur le seul numero de chapitre, le chapitre un du paquet
            // hors volume passerait avant le chapitre quarante du tome trois.
            #expect(ordonnes.map(\.chapitre.id) == [4, 9])
        }
    }

    @Test("Deux chapitres du meme volume se suivent par leur numero")
    func ordreDansUnVolume() throws {
        let volumes = try [
            Self.volume(identifiant: 1, numero: 1, chapitres: [
                Self.chapitre(30, numero: 10),
                Self.chapitre(10, numero: 2),
                Self.chapitre(20, numero: 2.5),
            ]),
        ]

        // Le tri naturel s applique aussi aux numeros : dix se lit apres deux,
        // pas avant.
        #expect(OrdreDesChapitresKavita.ordonner(volumes).map(\.chapitre.id) == [10, 20, 30])
    }

    @Test("Deux chapitres du meme numero gardent un ordre stable")
    func ordreStableSurUnDoublon() throws {
        let volumes = try [
            Self.volume(identifiant: 1, numero: 1, chapitres: [
                Self.chapitre(77, numero: 5),
                Self.chapitre(12, numero: 5),
            ]),
        ]

        // Un serveur ou deux chapitres portent le meme numero existe. L ordre
        // doit rester le meme d une analyse a l autre, sans quoi la liste se
        // reorganiserait a chaque ouverture de fiche.
        #expect(OrdreDesChapitresKavita.ordonner(volumes).map(\.chapitre.id) == [12, 77])
    }

    @Test("Un volume sans chapitre ne fait pas echouer la serie")
    func volumeVide() throws {
        let volumes = try [
            Self.volume(identifiant: 1, numero: 1, chapitres: []),
            Self.volume(identifiant: 2, numero: 2, chapitres: [Self.chapitre(5, numero: 3)]),
        ]

        #expect(OrdreDesChapitresKavita.ordonner(volumes).map(\.chapitre.id) == [5])
    }

    // MARK: Vocabulaire

    @Test("Les statuts de publication de Kavita sont traduits")
    func statutsTraduits() {
        #expect(StatutSerie.depuisKavita(0) == .enCours)
        #expect(StatutSerie.depuisKavita(1) == .enPause)
        // Les deux facons de conclure une serie chez Kavita se rejoignent sur
        // termine : le domaine n en distingue qu une.
        #expect(StatutSerie.depuisKavita(2) == .termine)
        #expect(StatutSerie.depuisKavita(4) == .termine)
        #expect(StatutSerie.depuisKavita(3) == .abandonne)
        #expect(StatutSerie.depuisKavita(42) == .inconnu)
        #expect(StatutSerie.depuisKavita(nil) == .inconnu)
    }

    @Test("La date nulle du serveur n est jamais rendue comme une date")
    func dateNulle() {
        #expect(LecteurDeDateKavita.lire("0001-01-01T00:00:00") == nil)
        #expect(LecteurDeDateKavita.lire("0001-01-01") == nil)
        #expect(LecteurDeDateKavita.lire(nil) == nil)
        #expect(LecteurDeDateKavita.lire("   ") == nil)
        #expect(LecteurDeDateKavita.lire("1990-11-26T00:00:00") == DatesDeTest.jour(1990, 11, 26))
    }

    // MARK: Montage

    /// Les regles completes, avec une regle prioritaire qui les surcharge.
    private static func regles(_ prioritaire: RegleDeTransport) -> [RegleDeTransport] {
        ServeurKavitaDeTest.reglesSurchargees(par: prioritaire)
    }

    /// Un volume decode depuis sa forme reelle.
    ///
    /// Il est construit par decodage et non par un initialiseur de test : les
    /// types de reponse n en ont pas, et leur en ajouter un ferait que les
    /// tests d ordre s executeraient sur une forme que le serveur ne rend
    /// jamais.
    private static func volume(identifiant: Int, numero: Double, chapitres: [String]) throws -> VolumeDeKavita {
        let corps = """
        {"id": \(identifiant), "minNumber": \(numero), "chapters": [\(chapitres.joined(separator: ","))]}
        """

        return try JSONDecoder().decode(VolumeDeKavita.self, from: Data(corps.utf8))
    }

    /// Un chapitre, sous la forme que le serveur ecrit dans un volume.
    private static func chapitre(_ identifiant: Int, numero: Double) -> String {
        """
        {"id": \(identifiant), "minNumber": \(numero), "number": "\(numero)", "pages": 1}
        """
    }
}
