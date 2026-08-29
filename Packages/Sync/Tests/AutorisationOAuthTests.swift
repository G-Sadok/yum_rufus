import Core
import CryptoKit
import Foundation
import Testing
@testable import Sync

//
// Couvre la preparation d une autorisation et la relecture de la redirection.
//
// Les deux protections de la norme sont testees pour ce qu elles sont : des
// refus. Un etat qui ne correspond pas et un code absent doivent lever, pas
// produire une connexion approximative. Le reste du fichier verifie que
// l adresse envoyee porte ce que le service attend, ni plus ni moins, parce
// qu un parametre de trop chez un service qui n en veut pas fait echouer
// l echange avec un message que l utilisateur ne peut pas corriger.
//

@Suite("Autorisation OAuth des services de suivi")
struct AutorisationOAuthTests {
    static let configuration = AtelierDeSuivi.configurationComplete()

    /// Parametres de l adresse d autorisation d un service.
    static func parametres(de service: ServiceDeSuivi) throws -> [String: String] {
        let demande = try AutorisationOAuth.demande(
            pour: service,
            configuration: configuration,
            tirage: TirageFige()
        )
        let composants = URLComponents(url: demande.adresse, resolvingAgainstBaseURL: false)

        return (composants?.queryItems ?? []).reduce(into: [:]) { table, parametre in
            table[parametre.name] = parametre.value
        }
    }

    @Test("La demande porte le client, le retour, le type et l etat")
    func parametresCommuns() throws {
        for service in ServiceDeSuivi.allCases where service.descriptif.nature.passeParLeNavigateur {
            let parametres = try Self.parametres(de: service)

            #expect(parametres["client_id"] == "client-" + service.rawValue)
            #expect(parametres["redirect_uri"] == AtelierDeSuivi.redirection)
            #expect(parametres["response_type"] == "code")
            #expect(parametres["state"] == "etat-fige")
        }
    }

    @Test("Le service sans preuve de cle n en envoie pas")
    func sansPreuveDeCle() throws {
        let parametres = try Self.parametres(de: .aniList)

        #expect(parametres["code_challenge"] == nil)
        #expect(parametres["code_challenge_method"] == nil)
    }

    @Test("Le service qui exige la forme en clair recoit le verifieur tel quel")
    func preuveEnClair() throws {
        let parametres = try Self.parametres(de: .myAnimeList)

        #expect(parametres["code_challenge_method"] == "plain")
        #expect(parametres["code_challenge"] == "verifieur-fige")
    }

    @Test("Le service qui exige l empreinte recoit le hachage du verifieur")
    func preuveHachee() throws {
        let attendu = Data(SHA256.hash(data: Data("verifieur-fige".utf8))).base64PourURL
        let parametres = try Self.parametres(de: .kitsu)

        #expect(parametres["code_challenge_method"] == "S256")
        #expect(parametres["code_challenge"] == attendu)
        #expect(parametres["code_challenge"] != "verifieur-fige")
    }

    @Test("L encodage de la preuve ne laisse passer aucun caractere d adresse")
    func encodagePourAdresse() {
        let preuve = PreuveDeCle(verifieur: "verifieur-fige", methode: .hachageSha256)

        #expect(preuve.defi.contains("+") == false)
        #expect(preuve.defi.contains("/") == false)
        #expect(preuve.defi.contains("=") == false)
    }

    @Test("Un service sans cles refuse de preparer une demande")
    func serviceNonConfigure() {
        #expect(throws: ErreurDeSuivi.serviceNonConfigure(service: .aniList)) {
            try AutorisationOAuth.demande(pour: .aniList, configuration: .aucune, tirage: TirageFige())
        }
    }

    @Test("Le service qui ne passe pas par le navigateur refuse la demande")
    func serviceSansNavigateur() {
        #expect(throws: ErreurDeSuivi.serviceNonConfigure(service: .mangaUpdates)) {
            try AutorisationOAuth.demande(
                pour: .mangaUpdates,
                configuration: Self.configuration,
                tirage: TirageFige()
            )
        }
    }

    @Test("Le code est lu quand l etat correspond")
    func codeLu() throws {
        let demande = try AutorisationOAuth.demande(
            pour: .kitsu,
            configuration: Self.configuration,
            tirage: TirageFige()
        )
        let retour = try AtelierDeSuivi.retour(pour: demande, code: "code-de-test")

        #expect(try AutorisationOAuth.code(depuis: retour, pour: demande) == "code-de-test")
    }

    @Test("Un etat qui ne correspond pas fait echouer la connexion")
    func etatInattendu() throws {
        let demande = try AutorisationOAuth.demande(
            pour: .kitsu,
            configuration: Self.configuration,
            tirage: TirageFige()
        )
        let retour = try AtelierDeSuivi.retour(pour: demande, code: "code-de-test", etat: "etat-fabrique")

        #expect(throws: ErreurDeSuivi.etatDeRedirectionInattendu(service: .kitsu)) {
            try AutorisationOAuth.code(depuis: retour, pour: demande)
        }
    }

    @Test("Un refus du service est rendu avec son motif")
    func refusDuService() throws {
        let demande = try AutorisationOAuth.demande(
            pour: .kitsu,
            configuration: Self.configuration,
            tirage: TirageFige()
        )
        let retour = try AtelierDeSuivi.refus(pour: demande, motif: "access_denied")

        #expect(throws: ErreurDeSuivi.autorisationRefusee(service: .kitsu, motif: "access_denied")) {
            try AutorisationOAuth.code(depuis: retour, pour: demande)
        }
    }

    @Test("Une redirection sans code ni motif compte comme un abandon")
    func abandon() throws {
        let demande = try AutorisationOAuth.demande(
            pour: .kitsu,
            configuration: Self.configuration,
            tirage: TirageFige()
        )
        let retour = try AtelierDeSuivi.retour(pour: demande, code: nil)

        #expect(throws: ErreurDeSuivi.autorisationAbandonnee(service: .kitsu)) {
            try AutorisationOAuth.code(depuis: retour, pour: demande)
        }
    }

    @Test("Le motif du refus passe avant la verification de l etat")
    func refusAvantEtat() throws {
        // Un service qui refuse ne renvoie pas toujours l etat. Verifier l etat
        // en premier transformerait un refus explicite en soupcon d attaque, et
        // l utilisateur lirait un message qui ne dit pas ce qui s est passe.
        let demande = try AutorisationOAuth.demande(
            pour: .kitsu,
            configuration: Self.configuration,
            tirage: TirageFige()
        )

        var composants = try #require(URLComponents(string: AtelierDeSuivi.redirection))
        composants.queryItems = [URLQueryItem(name: "error", value: "server_error")]
        let retour = try #require(composants.url)

        #expect(throws: ErreurDeSuivi.autorisationRefusee(service: .kitsu, motif: "server_error")) {
            try AutorisationOAuth.code(depuis: retour, pour: demande)
        }
    }

    @Test("L echange du code porte le secret quand le service en attend un")
    func echangeAvecSecret() throws {
        let demande = try AutorisationOAuth.demande(
            pour: .aniList,
            configuration: Self.configuration,
            tirage: TirageFige()
        )
        let champs = try AutorisationOAuth.champsDEchange(
            pour: demande,
            code: "code-de-test",
            configuration: Self.configuration
        )
        let table = champs.reduce(into: [String: String]()) { $0[$1.name] = $1.value }

        #expect(table["grant_type"] == "authorization_code")
        #expect(table["code"] == "code-de-test")
        #expect(table["client_secret"] == "secret-de-test")
        #expect(table["code_verifier"] == nil)
    }

    @Test("L echange du code porte le verifieur quand le service en attend un")
    func echangeAvecVerifieur() throws {
        let demande = try AutorisationOAuth.demande(
            pour: .myAnimeList,
            configuration: Self.configuration,
            tirage: TirageFige()
        )
        let champs = try AutorisationOAuth.champsDEchange(
            pour: demande,
            code: "code-de-test",
            configuration: Self.configuration
        )
        let table = champs.reduce(into: [String: String]()) { $0[$1.name] = $1.value }

        #expect(table["code_verifier"] == "verifieur-fige")
        #expect(table["client_secret"] == nil)
    }

    @Test("Le corps de formulaire echappe le plus au lieu de le laisser passer")
    func plusEchappe() {
        let corps = FormulaireEncode.corps([URLQueryItem(name: "refresh_token", value: "a+b")])

        #expect(corps == "refresh_token=a%2Bb")
    }
}
