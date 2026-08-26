import Core
import Foundation
import Testing
@testable import Sources

//
// SourceKomgaTests
//
// Premiere moitie du premier critere de la fonctionnalite : la connexion et le
// parcours du catalogue. La lecture est couverte par `LectureKomgaTests`, qui
// reprend la chaine la ou celui ci l arrete.
//

struct SourceKomgaTests {
    // MARK: Connexion

    @Test("La verification de connexion interroge le compte avec l identite basique")
    func connexionReussie() async throws {
        let serveur = ServeurKomgaDeTest(ServeurKomgaDeTest.reglesCompletes)
        let source = try await serveur.source()

        #expect(await source.verifierConnexion() == .connecte)

        let derniere = try #require(await serveur.transport.derniere)
        let attendue = Data("\(ServeurKomgaDeTest.compte):\(ServeurKomgaDeTest.motDePasse)".utf8)

        #expect(derniere.chemin.hasSuffix("/api/v1/users/me"))
        #expect(derniere.entete("Authorization") == "Basic " + attendue.base64EncodedString())
    }

    @Test("Un refus d identifiants se lit comme tel, pas comme une panne")
    func connexionRefusee() async throws {
        let serveur = ServeurKomgaDeTest([.statut("api/v1/users/me", 401)])
        let source = try await serveur.source()

        #expect(await source.verifierConnexion() == .identifiantsInvalides)
    }

    @Test("Un serveur qui refuse la connexion rend injoignable")
    func serveurInjoignable() async throws {
        let serveur = ServeurKomgaDeTest([.panne("api/v1/users/me", .connexionRefusee)])
        let source = try await serveur.source()

        #expect(await source.verifierConnexion() == .injoignable)
    }

    @Test("Une cle d API part dans l entete que Komga attend")
    func cleDApiPoseSonEntete() async throws {
        let serveur = ServeurKomgaDeTest(ServeurKomgaDeTest.reglesCompletes)
        let source = try await serveur.source(authentification: .cleDApi)

        #expect(await source.verifierConnexion() == .connecte)
        #expect(await serveur.transport.derniere?.entete("X-API-Key") == "cle-de-test")
    }

    @Test("Un jeton rafraichissable est refuse, Komga n en emet aucun")
    func jetonRefuse() async throws {
        let serveur = ServeurKomgaDeTest(ServeurKomgaDeTest.reglesCompletes)
        let source = try await serveur.source(authentification: .jeton)

        #expect(await source.verifierConnexion() == .identifiantsInvalides)
        #expect(await serveur.transport.journal.isEmpty)
    }

    // MARK: Transport chiffre

    @Test("Une adresse en clair non confirmee ne laisse partir aucune requete")
    func adresseEnClairRefusee() async throws {
        let serveur = ServeurKomgaDeTest(ServeurKomgaDeTest.reglesCompletes)
        let source = try await serveur.source(adresse: ServeurKomgaDeTest.adresseEnClair)

        #expect(await source.verifierConnexion() == .erreur)
        // La requete ne part pas du tout : le refus est prononce avant que le
        // mot de passe soit pose dans un entete non chiffre.
        #expect(await serveur.transport.journal.isEmpty)
    }

    @Test("Une adresse en clair confirmee par l utilisateur est acceptee")
    func adresseEnClairConfirmee() async throws {
        let serveur = ServeurKomgaDeTest(ServeurKomgaDeTest.reglesCompletes)
        let source = try await serveur.source(
            adresse: ServeurKomgaDeTest.adresseEnClair,
            accepteLeHttpEnClair: true
        )

        #expect(await source.verifierConnexion() == .connecte)
    }

    @Test("Une source sans adresse ne se construit pas")
    func sourceSansAdresseRefusee() async throws {
        let serveur = ServeurKomgaDeTest([])

        await #expect(throws: ErreurDeConfigurationDeSource.illisible) {
            _ = try await serveur.source(adresse: nil)
        }
    }

    // MARK: Parcours du catalogue

    @Test("Le catalogue est rendu par tranches, et la suite est annoncee")
    func parcoursParTranches() async throws {
        let serveur = ServeurKomgaDeTest(ServeurKomgaDeTest.reglesCompletes)
        let source = try await serveur.source()

        let premiere = try await source.parcourir(.tout, page: 0)
        let seconde = try await source.parcourir(.tout, page: 1)

        #expect(premiere.elements.map(\.titre) == ["Berserk", "vagabond"])
        #expect(premiere.page == 0)
        #expect(premiere.ilResteDesPages)
        #expect(seconde.elements.map(\.titre) == ["Pluto"])
        #expect(seconde.page == 1)
        #expect(seconde.ilResteDesPages == false)
    }

    @Test("Les metadonnees de serie sont traduites champ par champ")
    func traductionDesMetadonnees() async throws {
        let serveur = ServeurKomgaDeTest(ServeurKomgaDeTest.reglesCompletes)
        let source = try await serveur.source()
        let catalogue = try await source.parcourir(.tout, page: 0)
        let premiere = try #require(catalogue.elements.first)

        #expect(premiere.identifiant == ReponsesFigeesDeKomga.identifiantDeSerie)
        #expect(premiere.titre == "Berserk")
        #expect(premiere.statut == .enCours)
        #expect(premiere.genres == ["Seinen", "Dark Fantasy"])
        #expect(premiere.langue == "ja")
        #expect(premiere.nombreChapitres == 3)
        // Le scenariste n est compte qu une fois malgre ses deux roles, et
        // l encreur ne figure pas dans la liste des auteurs de la fiche.
        #expect(premiere.auteurs == ["Kentaro Miura"])
        // Le resume de la serie est une chaine de blancs, celui des livres prend
        // le relais.
        #expect(premiere.resume == "Un mercenaire marque poursuit ceux qui l ont trahi.")
        #expect(premiere.urlCouverture?.hasSuffix(
            "/api/v1/series/\(ReponsesFigeesDeKomga.identifiantDeSerie)/thumbnail"
        ) == true)
    }

    @Test("Une serie incomplete garde un titre et n invente aucun champ")
    func serieIncomplete() async throws {
        let serveur = ServeurKomgaDeTest(ServeurKomgaDeTest.reglesCompletes)
        let source = try await serveur.source()
        let catalogue = try await source.parcourir(.tout, page: 0)
        let seconde = try #require(catalogue.elements.last)

        // Le titre des metadonnees est vide, le nom du dossier prend le relais.
        #expect(seconde.titre == "vagabond")
        // Un statut que nous ne connaissons pas ne fait pas echouer la serie.
        #expect(seconde.statut == .inconnu)
        #expect(seconde.langue == nil)
        #expect(seconde.resume == nil)
        #expect(seconde.auteurs.isEmpty)
    }

    @Test("La section recentes trie sur la derniere modification")
    func sectionRecentes() async throws {
        let serveur = ServeurKomgaDeTest(ServeurKomgaDeTest.reglesCompletes)
        let source = try await serveur.source()

        _ = try await source.parcourir(.recentes, page: 0)

        #expect(await serveur.transport.derniere?.parametre("sort") == "lastModified,desc")
    }

    @Test("La section populaires est refusee, Komga ne mesure aucune popularite")
    func sectionPopulairesRefusee() async throws {
        let serveur = ServeurKomgaDeTest(ServeurKomgaDeTest.reglesCompletes)
        let source = try await serveur.source()

        await #expect(
            throws: ErreurDeSource.sectionNonPriseEnCharge(section: .populaires, source: serveur.nom)
        ) {
            _ = try await source.parcourir(.populaires, page: 0)
        }
        #expect(await serveur.transport.journal.isEmpty)
    }

    // MARK: Recherche et filtres

    @Test("La recherche envoie le texte, les genres et le statut")
    func rechercheAvecFiltres() async throws {
        let serveur = ServeurKomgaDeTest(ServeurKomgaDeTest.reglesCompletes)
        let source = try await serveur.source()
        let requete = RequeteRecherche(
            texte: "  berserk  ",
            filtres: FiltresDeRecherche(genres: ["Seinen", "  "], statut: .enCours)
        )

        _ = try await source.rechercher(requete)

        let envoyee = try #require(await serveur.transport.derniere)

        #expect(envoyee.parametre("search") == "berserk")
        // Le genre vide est ecarte plutot qu envoye, Komga refuserait la requete.
        #expect(envoyee.valeurs("genre") == ["Seinen"])
        #expect(envoyee.parametre("status") == "ONGOING")
        #expect(envoyee.parametre("size") == "2")
    }

    @Test("Une recherche par langue est refusee, la capacite n est pas declaree")
    func langueRefusee() async throws {
        let serveur = ServeurKomgaDeTest(ServeurKomgaDeTest.reglesCompletes)
        let source = try await serveur.source()
        let requete = RequeteRecherche(texte: "berserk", langue: "fr")

        await #expect(
            throws: ErreurDeSource.capaciteIndisponible(capacite: .plusieursLangues, source: serveur.nom)
        ) {
            _ = try await source.rechercher(requete)
        }
    }

    @Test("Les capacites declarees sont celles que le serveur sait tenir")
    func capacitesDeclarees() async throws {
        let serveur = ServeurKomgaDeTest([])
        let source = try await serveur.source()

        #expect(source.capacites == [
            .recherche,
            .filtres,
            .pagination,
            .telechargement,
            .progressionDistante,
        ])
        #expect(source.declare(.plusieursLangues) == false)
        #expect(source.offre(.publierLaProgression))
    }
}
