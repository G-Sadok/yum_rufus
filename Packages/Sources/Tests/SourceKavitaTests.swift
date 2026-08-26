import Core
import Foundation
import Testing
@testable import Sources

//
// SourceKavitaTests
//
// Premiere moitie du second critere de la fonctionnalite : la connexion et le
// parcours du catalogue. La lecture est couverte par `LectureKavitaTests`, qui
// reprend la chaine la ou celui ci l arrete.
//

struct SourceKavitaTests {
    // MARK: Connexion

    @Test("La verification de connexion ouvre une session puis interroge le catalogue")
    func connexionReussie() async throws {
        let serveur = ServeurKavitaDeTest(ServeurKavitaDeTest.reglesCompletes)
        let source = try await serveur.source()

        #expect(await source.verifierConnexion() == .connecte)

        let journal = await serveur.transport.journal
        let connexion = try #require(journal.first)

        // La connexion part la premiere, et porte le compte dans son corps et
        // non dans un entete : Kavita n accepte pas l authentification basique.
        #expect(connexion.chemin.hasSuffix("/api/Account/login"))
        #expect(connexion.methode == "POST")
        #expect(connexion.corpsJson()?["username"] as? String == ServeurKavitaDeTest.compte)
        #expect(connexion.entete("Authorization") == nil)

        let derniere = try #require(await serveur.transport.derniere)

        #expect(derniere.chemin.hasSuffix("/api/Series/all-v2"))
        #expect(derniere.entete("Authorization") == "Bearer " + ServeurKavitaDeTest.jetonValable)
    }

    @Test("La verification ne demande qu une seule serie au serveur")
    func connexionNeChargePasLeCatalogue() async throws {
        let serveur = ServeurKavitaDeTest(ServeurKavitaDeTest.reglesCompletes)
        let source = try await serveur.source()

        _ = await source.verifierConnexion()

        // Verifier la connexion ne doit pas ramener cinquante fiches : c est
        // fait a chaque ouverture de l ecran Parcourir, pour chaque serveur.
        #expect(await serveur.transport.derniere?.parametre("PageSize") == "1")
    }

    @Test("Un refus d identifiants se lit comme tel, pas comme une panne")
    func connexionRefusee() async throws {
        let serveur = ServeurKavitaDeTest([.statut(CheminsKavita.connexion, 401, methode: .post)])
        let source = try await serveur.source()

        #expect(await source.verifierConnexion() == .identifiantsInvalides)
    }

    @Test("Un serveur qui refuse la connexion rend injoignable")
    func serveurInjoignable() async throws {
        let serveur = ServeurKavitaDeTest([
            .panne(CheminsKavita.connexion, .connexionRefusee, methode: .post),
        ])
        let source = try await serveur.source()

        #expect(await source.verifierConnexion() == .injoignable)
    }

    @Test("Une adresse qui ne sert pas Kavita ne passe pas pour une connexion reussie")
    func serveurQuiNEstPasKavita() async throws {
        // Un corps accepte mais vide de jeton : c est ce que rend une adresse
        // qui pointe vers un autre service, ou vers un proxy bavard.
        let serveur = ServeurKavitaDeTest([
            .json(.post, CheminsKavita.connexion, #"{"message": "ok"}"#),
        ])
        let source = try await serveur.source()

        #expect(await source.verifierConnexion() == .identifiantsInvalides)
    }

    @Test("Une cle d API ouvre une session par le point d entree des extensions")
    func cleDApiOuvreUneSession() async throws {
        let serveur = ServeurKavitaDeTest(ServeurKavitaDeTest.reglesCompletes)
        let source = try await serveur.source(identifiants: .cleDApi(ServeurKavitaDeTest.cleDApi))

        #expect(await source.verifierConnexion() == .connecte)

        let journal = await serveur.transport.journal
        let authentification = try #require(journal.first)

        #expect(authentification.chemin.hasSuffix("/api/Plugin/authenticate"))
        #expect(authentification.parametre("apiKey") == ServeurKavitaDeTest.cleDApi)
        #expect(authentification.parametre("pluginName")?.isEmpty == false)
    }

    @Test("Une source sans identifiants est refusee, Kavita ne sert rien d anonyme")
    func sourceAnonymeRefusee() async throws {
        let serveur = ServeurKavitaDeTest(ServeurKavitaDeTest.reglesCompletes)
        let source = try await serveur.source(identifiants: .aucun)

        #expect(await source.verifierConnexion() == .identifiantsInvalides)
        #expect(await serveur.transport.journal.isEmpty)
    }

    // MARK: Transport chiffre

    @Test("Une adresse en clair non confirmee ne laisse partir aucune requete")
    func adresseEnClairRefusee() async throws {
        let serveur = ServeurKavitaDeTest(ServeurKavitaDeTest.reglesCompletes)
        let source = try await serveur.source(adresse: ReponsesFigeesDeKavita.adresseEnClair)

        #expect(await source.verifierConnexion() == .erreur)
        // Le refus est prononce avant que le mot de passe soit ecrit dans un
        // corps de requete non chiffre.
        #expect(await serveur.transport.journal.isEmpty)
    }

    @Test("Une adresse en clair confirmee par l utilisateur est acceptee")
    func adresseEnClairConfirmee() async throws {
        let serveur = ServeurKavitaDeTest(ServeurKavitaDeTest.reglesCompletes)
        let source = try await serveur.source(
            adresse: ReponsesFigeesDeKavita.adresseEnClair,
            accepteLeHttpEnClair: true
        )

        #expect(await source.verifierConnexion() == .connecte)
    }

    @Test("Une source sans adresse ne se construit pas")
    func sourceSansAdresseRefusee() async throws {
        let serveur = ServeurKavitaDeTest([])

        await #expect(throws: ErreurDeConfigurationDeSource.illisible) {
            _ = try await serveur.source(adresse: nil)
        }
    }

    // MARK: Parcours du catalogue

    @Test("Le catalogue est rendu par tranches, et la suite est annoncee")
    func parcoursParTranches() async throws {
        let serveur = ServeurKavitaDeTest(ServeurKavitaDeTest.reglesCompletes)
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

    @Test("La tranche demandee est traduite dans la numerotation du serveur")
    func numerotationDesTranches() async throws {
        let serveur = ServeurKavitaDeTest(ServeurKavitaDeTest.reglesCompletes)
        let source = try await serveur.source()

        _ = try await source.parcourir(.tout, page: 1)

        // Kavita compte a partir de un, le modele a partir de zero. Envoyer le
        // numero du modele tel quel rendrait deux fois la premiere tranche.
        #expect(await serveur.transport.derniere?.parametre("PageNumber") == "2")
    }

    @Test("Une pagination absente de l entete ne fait pas perdre la suite")
    func paginationSansEntete() async throws {
        // Un proxy inverse qui filtre les entetes inconnus est frequent.
        let serveur = ServeurKavitaDeTest([
            .json(.post, CheminsKavita.connexion, ReponsesFigeesDeKavita.connexion(
                jeton: ServeurKavitaDeTest.jetonValable
            )),
            .json(.post, CheminsKavita.toutesLesSeries, ReponsesFigeesDeKavita.premiereTrancheDeSeries),
        ])
        let source = try await serveur.source()

        let tranche = try await source.parcourir(.tout, page: 0)

        // Deux series pour une taille de page de deux : la suite est possible,
        // et la promettre coute une requete vide la ou la nier perdrait la
        // moitie du catalogue.
        #expect(tranche.elements.count == 2)
        #expect(tranche.ilResteDesPages)
    }

    @Test("La section recentes trie sur l arrivee du dernier chapitre")
    func sectionRecentes() async throws {
        let serveur = ServeurKavitaDeTest(ServeurKavitaDeTest.reglesCompletes)
        let source = try await serveur.source()

        _ = try await source.parcourir(.recentes, page: 0)

        let envoyee = try #require(await serveur.transport.derniere)
        let tri = envoyee.corpsJson()?["sortOptions"] as? [String: any Sendable]

        #expect(tri?["sortField"] as? Int == 4)
        #expect(tri?["isAscending"] as? Bool == false)
    }

    @Test("La section populaires est refusee, Kavita ne mesure aucune popularite")
    func sectionPopulairesRefusee() async throws {
        let serveur = ServeurKavitaDeTest(ServeurKavitaDeTest.reglesCompletes)
        let source = try await serveur.source()

        await #expect(
            throws: ErreurDeSource.sectionNonPriseEnCharge(section: .populaires, source: serveur.nom)
        ) {
            _ = try await source.parcourir(.populaires, page: 0)
        }
        #expect(await serveur.transport.journal.isEmpty)
    }

    // MARK: Recherche et filtres

    @Test("La recherche passe par le point d entree dedie et rend des series")
    func rechercheParTexte() async throws {
        let serveur = ServeurKavitaDeTest(ServeurKavitaDeTest.reglesCompletes)
        let source = try await serveur.source()

        let trouves = try await source.rechercher(RequeteRecherche(texte: "  berserk  "))

        #expect(trouves.elements.map(\.titre) == ["Berserk", "vagabond"])
        #expect(trouves.ilResteDesPages == false)

        let envoyee = try #require(await serveur.transport.derniere)

        #expect(envoyee.chemin.hasSuffix("/api/Search/search"))
        #expect(envoyee.parametre("queryString") == "berserk")
    }

    @Test("Une recherche vidée de son texte retombe sur le catalogue pagine")
    func rechercheSansTexte() async throws {
        let serveur = ServeurKavitaDeTest(ServeurKavitaDeTest.reglesCompletes)
        let source = try await serveur.source()

        let trouves = try await source.rechercher(RequeteRecherche(texte: "   "))

        // Servir la recherche ici rendrait une liste tronquee la ou
        // l utilisateur a simplement efface sa saisie.
        #expect(trouves.elements.map(\.titre) == ["Berserk", "vagabond"])
        #expect(trouves.ilResteDesPages)
        #expect(await serveur.transport.derniere?.chemin.hasSuffix("/api/Series/all-v2") == true)
    }

    @Test("La recherche n a qu une page, les suivantes sont vides et non refusees")
    func rechercheNonPaginee() async throws {
        let serveur = ServeurKavitaDeTest(ServeurKavitaDeTest.reglesCompletes)
        let source = try await serveur.source()

        let suite = try await source.rechercher(RequeteRecherche(texte: "berserk", page: 1))

        // Lever au premier point d arret ferait echouer un defilement infini
        // qui atteint simplement la fin de la liste.
        #expect(suite.elements.isEmpty)
        #expect(suite.ilResteDesPages == false)
    }

    @Test("Une recherche filtree est refusee, la capacite n est pas declaree")
    func filtresRefuses() async throws {
        let serveur = ServeurKavitaDeTest(ServeurKavitaDeTest.reglesCompletes)
        let source = try await serveur.source()
        let requete = RequeteRecherche(
            texte: "berserk",
            filtres: FiltresDeRecherche(genres: ["Seinen"])
        )

        // La grammaire de filtre de Kavita designe ses champs par des ordinaux
        // que la source ne sait pas encore construire. Rendre une liste non
        // filtree serait pire qu un refus : elle ne correspondrait pas a la
        // demande sans que rien ne le dise.
        await #expect(
            throws: ErreurDeSource.capaciteIndisponible(capacite: .filtres, source: serveur.nom)
        ) {
            _ = try await source.rechercher(requete)
        }
        #expect(await serveur.transport.journal.isEmpty)
    }

    @Test("Une recherche par langue est refusee, la capacite n est pas declaree")
    func langueRefusee() async throws {
        let serveur = ServeurKavitaDeTest(ServeurKavitaDeTest.reglesCompletes)
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
        let serveur = ServeurKavitaDeTest([])
        let source = try await serveur.source()

        // Les capacites sont hors acteur : l ecran Parcourir les lit pour
        // decider quels boutons afficher, et les attendre ferait suspendre le
        // rendu d une liste pour une valeur constante.
        #expect(source.capacites == [
            .recherche,
            .pagination,
            .telechargement,
            .progressionDistante,
        ])
        #expect(source.declare(.filtres) == false)
        #expect(source.declare(.plusieursLangues) == false)
        #expect(source.offre(.publierLaProgression))
    }
}
