import Core
import Foundation
import Sources
@testable import Sync

//
// AtelierDeSuivi
//
// Le montage commun des tests de suivi : un transport fige, un magasin de
// jetons en memoire, un client et un registre, pour un service donne.
//
// Il existe pour que chaque test dise ce qu il verifie et rien d autre. Sans
// lui, les six lignes d assemblage seraient recopiees dans chaque fichier, et
// la premiere modification du client en laisserait la moitie derriere.
//

/// Montage complet d un service de suivi pour un test.
struct AtelierDeSuivi {
    /// Service monte.
    let service: ServiceDeSuivi

    /// Serveur fige.
    let transport: TransportFigeDeSuivi

    /// Jetons, en memoire.
    let magasin: MagasinDeJetonsDeSuiviEnMemoire

    /// Registre a interroger.
    let registre: RegistreDesSuivis

    /// Mode incognito, inactif par defaut.
    let incognito: RegistreDIncognito

    /// Configuration des cles, presente pour les quatre services.
    let configuration: ConfigurationDesSuivis

    /// Instant fixe, pour que les echeances calculees soient comparables.
    static let maintenant = Date(timeIntervalSince1970: 1_700_000_000)

    /// Adresse de retour employee par les tests.
    static let redirection = "https://retour.exemple.test/suivis"

    init(
        service: ServiceDeSuivi,
        reglesSupplementaires: [RegleDeSuivi] = [],
        incognito: RegistreDIncognito = RegistreDIncognito()
    ) throws {
        self.service = service
        self.incognito = incognito

        transport = TransportFigeDeSuivi(reglesSupplementaires + RegleDeService.regles(pour: service))
        magasin = MagasinDeJetonsDeSuiviEnMemoire()
        configuration = Self.configurationComplete()

        let client = try ClientDeSuivi(
            dialecte: Self.dialecte(de: service),
            configuration: configuration,
            magasin: magasin,
            transport: transport,
            maintenant: { Self.maintenant }
        )

        registre = RegistreDesSuivis(
            clients: [client],
            incognito: incognito,
            maintenant: { Self.maintenant }
        )
    }

    /// Connecte le service, par le navigateur ou par identifiants selon sa
    /// nature.
    @discardableResult
    func connecter() async throws -> CompteDeSuivi {
        guard service.descriptif.nature.passeParLeNavigateur else {
            return try await registre.connecter(service, compte: "lectrice", motDePasse: "mot-de-passe-de-test")
        }

        let demande = try registre.demandeDAutorisation(
            pour: service,
            configuration: configuration,
            tirage: TirageFige()
        )

        return try await registre.connecter(
            service,
            redirection: Self.retour(pour: demande, code: "code-de-test"),
            pour: demande
        )
    }

    /// Ajoute une regle qui prend le pas sur celles du montage.
    func servir(_ regle: RegleDeSuivi) async {
        await transport.prioriser(regle)
    }

    /// Le meme atelier, capable de repondre a une recherche de series.
    ///
    /// La regle depend du service, parce que le chemin et le verbe d une
    /// recherche ne sont pas les memes chez les quatre. Elle est posee a part
    /// et non dans le montage commun pour que les tests de connexion ne servent
    /// que ce dont ils ont besoin.
    func avecRecherche() async -> AtelierDeSuivi {
        await servir(Self.regleDeRecherche(pour: service))

        return self
    }

    /// Le meme atelier, capable de recevoir une publication de progression.
    ///
    /// Le service qui tient ses progressions dans une entree de bibliotheque
    /// recoit deux regles, la lecture de l entree et son ecriture, parce qu il
    /// fait deux appels la ou les trois autres en font un.
    func avecPublication() async -> AtelierDeSuivi {
        for regle in Self.reglesDePublication(pour: service) {
            await servir(regle)
        }

        return self
    }

    /// Regles qui servent la publication d un service.
    static func reglesDePublication(pour service: ServiceDeSuivi) -> [RegleDeSuivi] {
        switch service {
        case .aniList:
            [
                .json(
                    .post,
                    "graphql.anilist.co",
                    ReponsesFigeesDesSuivis.publicationAniList,
                    corpsContient: "SaveMediaListEntry"
                ),
            ]
        case .myAnimeList:
            [.json(.patch, "/my_list_status", ReponsesFigeesDesSuivis.publicationVide)]
        case .kitsu:
            [
                .json(.get, "/library-entries", ReponsesFigeesDesSuivis.entreeKitsuExistante),
                .json(.patch, "/library-entries/9001", ReponsesFigeesDesSuivis.publicationVide),
                .json(.post, "/library-entries", ReponsesFigeesDesSuivis.publicationVide),
            ]
        case .mangaUpdates:
            [.json(.post, "/lists/series/update", ReponsesFigeesDesSuivis.publicationVide)]
        }
    }

    /// Regle qui sert la recherche d un service.
    static func regleDeRecherche(pour service: ServiceDeSuivi) -> RegleDeSuivi {
        let corps = RegleDeService.recherche(pour: service)

        return switch service {
        case .aniList: .json(.post, "graphql.anilist.co", corps, corpsContient: "media(search")
        case .myAnimeList: .json(.get, "/manga", corps)
        case .kitsu: .json(.get, "/manga", corps)
        case .mangaUpdates: .json(.post, "/series/search", corps)
        }
    }

    /// Adresse par laquelle le navigateur revient, pour une demande donnee.
    static func retour(pour demande: DemandeDAutorisation, code: String?, etat: String? = nil) throws -> URL {
        guard var composants = URLComponents(string: redirection) else {
            throw ErreurDeMontage.adresseInvalide
        }

        var parametres = [URLQueryItem(name: "state", value: etat ?? demande.etat)]

        if let code {
            parametres.append(URLQueryItem(name: "code", value: code))
        }

        composants.queryItems = parametres

        guard let adresse = composants.url else {
            throw ErreurDeMontage.adresseInvalide
        }

        return adresse
    }

    /// Adresse de retour portant un refus du service.
    static func refus(pour demande: DemandeDAutorisation, motif: String) throws -> URL {
        guard var composants = URLComponents(string: redirection) else {
            throw ErreurDeMontage.adresseInvalide
        }

        composants.queryItems = [
            URLQueryItem(name: "state", value: demande.etat),
            URLQueryItem(name: "error", value: motif),
        ]

        guard let adresse = composants.url else {
            throw ErreurDeMontage.adresseInvalide
        }

        return adresse
    }

    /// Dialecte du service.
    static func dialecte(de service: ServiceDeSuivi) -> any DialecteDeSuivi {
        switch service {
        case .aniList: DialecteAniList()
        case .myAnimeList: DialecteMyAnimeList()
        case .kitsu: DialecteKitsu()
        case .mangaUpdates: DialecteMangaUpdates()
        }
    }

    /// Cles connues pour les quatre services.
    static func configurationComplete() -> ConfigurationDesSuivis {
        let retour = URL(string: redirection) ?? URL(fileURLWithPath: "/retour")
        let entrees = ServiceDeSuivi.allCases.map { service in
            (
                service,
                ConfigurationDeServiceDeSuivi(
                    identifiantDeClient: "client-" + service.rawValue,
                    secretDeClient: service.descriptif.nature == .codeDAutorisationAvecSecret
                        ? "secret-de-test"
                        : nil,
                    redirection: retour
                )
            )
        }

        return ConfigurationDesSuivis(Dictionary(uniqueKeysWithValues: entrees))
    }
}

/// Ce qui peut mal tourner dans le montage d un test.
enum ErreurDeMontage: Error {
    case adresseInvalide
}

/// Tirage qui rend une suite connue, pour que l adresse d autorisation produite
/// se compare a une valeur ecrite dans le test.
///
/// Les valeurs sortent dans l ordre : l etat d abord, le verifieur de la preuve
/// de cle ensuite, ce qui est l ordre dans lequel la preparation de la demande
/// les tire. Deux valeurs identiques auraient cache une inversion des deux.
///
/// `@unchecked Sendable` est sur ici parce que le seul etat mutable est le rang
/// de la prochaine valeur, et que tous ses acces passent par le verrou.
final class TirageFige: TirageAleatoire, @unchecked Sendable {
    private let valeurs: [String]
    private let verrou = NSLock()
    private var rang = 0

    init(valeurs: [String] = ["etat-fige", "verifieur-fige"]) {
        self.valeurs = valeurs
    }

    func valeur(octets _: Int) -> String {
        verrou.withLock {
            defer { rang += 1 }

            return rang < valeurs.count ? valeurs[rang] : "fige-\(rang)"
        }
    }
}
