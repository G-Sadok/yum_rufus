import Foundation
import Testing
@testable import Core

//
// Couvre la table des quatre services de la section 9 du cahier de
// developpement, et le refus d une version sans cles.
//
// Le test compare la table au document plutot que de recopier les quatre noms
// une seconde fois. Un service renomme dans le code sans l etre dans le
// document fait donc virer la suite au rouge, ce qu une liste recopiee aurait
// laisse passer.
//

@Suite("Description des services de suivi")
struct ServicesDeSuiviTests {
    /// Les quatre lignes du tableau Suivis de la section 9.
    static let nomsDuDocument = ["AniList", "MyAnimeList", "Kitsu", "MangaUpdates"]

    @Test("Les quatre services du document existent, et rien d autre")
    func lesQuatreServicesDuDocument() {
        let nomsDuCode = ServiceDeSuivi.allCases.map(\.descriptif.nomDuDocument)

        #expect(Set(nomsDuCode) == Set(Self.nomsDuDocument))
        #expect(nomsDuCode.count == 4)

        for nom in Self.nomsDuDocument {
            #expect(ServiceDeSuivi.portant(leNomDuDocument: nom) != nil)
        }
    }

    @Test("Toutes les adresses des services sont en HTTPS")
    func toutesLesAdressesSontEnHttps() {
        for service in ServiceDeSuivi.allCases {
            let descriptif = service.descriptif

            #expect(descriptif.api.scheme == "https")
            #expect(descriptif.jeton.scheme == "https")

            if let autorisation = descriptif.autorisation {
                #expect(autorisation.scheme == "https")
            }
        }
    }

    @Test("Trois services passent par le navigateur, le quatrieme non")
    func troisServicesOAuth() {
        let parLeNavigateur = ServiceDeSuivi.allCases
            .filter(\.descriptif.nature.passeParLeNavigateur)

        #expect(Set(parLeNavigateur) == [.aniList, .myAnimeList, .kitsu])
        #expect(ServiceDeSuivi.mangaUpdates.descriptif.nature == .identifiantsDeCompte)
        #expect(ServiceDeSuivi.mangaUpdates.descriptif.autorisation == nil)
    }

    @Test("Un service a preuve de cle nomme la methode qu il accepte")
    func preuveDeCleNommee() {
        for service in ServiceDeSuivi.allCases {
            let descriptif = service.descriptif

            if descriptif.nature.exigeUnePreuveDeCle {
                #expect(descriptif.preuveDeCle != nil)
            } else {
                #expect(descriptif.preuveDeCle == nil)
            }
        }
    }

    @Test("Un service sans cles ne peut pas se connecter")
    func serviceSansCles() {
        #expect(ConfigurationDesSuivis.aucune.peutSeConnecter(.aniList) == false)
        #expect(ConfigurationDesSuivis.aucune.servicesConfigures.isEmpty)
    }

    @Test("Un identifiant de client vide compte comme absent")
    func identifiantVide() throws {
        let configuration = try ConfigurationDesSuivis([
            .kitsu: ConfigurationDeServiceDeSuivi(
                identifiantDeClient: "",
                redirection: #require(URL(string: Self.redirection))
            ),
        ])

        #expect(configuration.peutSeConnecter(.kitsu) == false)
    }

    @Test("Le service qui exige un secret n est pas connectable sans lui")
    func secretManquant() throws {
        let retour = try #require(URL(string: Self.redirection))
        let sansSecret = ConfigurationDesSuivis([
            .aniList: ConfigurationDeServiceDeSuivi(
                identifiantDeClient: "client-de-test",
                redirection: retour
            ),
        ])
        let avecSecret = ConfigurationDesSuivis([
            .aniList: ConfigurationDeServiceDeSuivi(
                identifiantDeClient: "client-de-test",
                secretDeClient: "secret-de-test",
                redirection: retour
            ),
        ])

        #expect(sansSecret.peutSeConnecter(.aniList) == false)
        #expect(avecSecret.peutSeConnecter(.aniList))
        #expect(avecSecret.servicesConfigures == [.aniList])
    }

    @Test("La configuration ne rend jamais le secret a l affichage")
    func configurationCaviardee() throws {
        let entree = try ConfigurationDeServiceDeSuivi(
            identifiantDeClient: "client-de-test",
            secretDeClient: "secret-a-ne-pas-afficher",
            redirection: #require(URL(string: Self.redirection))
        )

        #expect(entree.description.contains("secret-a-ne-pas-afficher") == false)
        #expect("\(entree)".contains("secret-a-ne-pas-afficher") == false)
    }

    /// Adresse de retour employee par les tests.
    static let redirection = "https://retour.exemple.test/suivis"
}
