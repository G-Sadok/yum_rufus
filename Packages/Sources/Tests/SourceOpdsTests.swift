import Core
import Foundation
import Testing
@testable import Sources

//
// SourceOpdsTests
//
// Les trois criteres de la fonctionnalite, pris de bout en bout, transport
// compris.
//
// Le deuxieme critere est celui qui demande le plus d attention, parce qu il se
// prouve mal. Verifier qu une page suivante rend d autres elements ne prouve
// rien : une source qui fabriquerait ses adresses de page passerait ce test.
// Ce qui prouve le suivi du lien `next`, c est l adresse reellement demandee,
// et c est le journal du transport fige qui la donne.
//

struct SourceOpdsTests {
    // MARK: Connexion et authentification basique

    @Test("La verification de connexion lit le flux racine avec l identite basique")
    func connexionReussie() async throws {
        let catalogue = CatalogueOpdsDeTest(CatalogueOpdsDeTest.reglesCompletes())
        let source = try await catalogue.source()

        #expect(await source.verifierConnexion() == .connecte)

        let derniere = try #require(await catalogue.transport.derniere)

        #expect(derniere.chemin.hasSuffix("/opds/v1.2/series"))
        #expect(derniere.entete("Authorization") == CatalogueOpdsDeTest.enteteBasique)
    }

    @Test("Un catalogue protege par authentification basique se parcourt")
    func catalogueProtege() async throws {
        // Chaque regle exige l entete d authentification. Une requete qui ne le
        // porte pas ne correspond a aucune regle et recoit un 404, ce qui fait
        // echouer le parcours : le test ne peut donc pas passer sans que le mot
        // de passe soit reellement pose sur chaque requete.
        let exigeantes = CatalogueOpdsDeTest.reglesCompletes().map {
            $0.exigeant(entete: "Authorization", CatalogueOpdsDeTest.enteteBasique)
        }
        let catalogue = CatalogueOpdsDeTest(exigeantes)
        let source = try await catalogue.source()

        let premiere = try await source.parcourir(.tout, page: 0)
        let chapitres = try await source.chapitres(pour: identifiantDeLaSerieAtom)

        #expect(premiere.elements.map(\.titre) == ["Berserk", "Vinland Saga"])
        #expect(chapitres.count == 3)

        let journal = await catalogue.transport.journal

        #expect(journal.isEmpty == false)
        #expect(journal.allSatisfy { $0.entete("Authorization") == CatalogueOpdsDeTest.enteteBasique })
    }

    @Test("Un catalogue ouvert se parcourt sans aucun entete d identite")
    func catalogueOuvert() async throws {
        let catalogue = CatalogueOpdsDeTest(CatalogueOpdsDeTest.reglesCompletes())
        let source = try await catalogue.source(authentification: .aucune)

        #expect(await source.verifierConnexion() == .connecte)
        #expect(await catalogue.transport.derniere?.entete("Authorization") == nil)
    }

    @Test("Un refus d identifiants se lit comme tel, pas comme une panne")
    func connexionRefusee() async throws {
        let catalogue = CatalogueOpdsDeTest([
            .statut(ReponsesFigeesDOpds.cheminDuCatalogueAtom, 401),
        ])
        let source = try await catalogue.source()

        #expect(await source.verifierConnexion() == .identifiantsInvalides)
    }

    @Test("Un catalogue injoignable rend injoignable et non une erreur")
    func catalogueInjoignable() async throws {
        let catalogue = CatalogueOpdsDeTest([
            .panne(ReponsesFigeesDOpds.cheminDuCatalogueAtom, .connexionRefusee),
        ])
        let source = try await catalogue.source()

        #expect(await source.verifierConnexion() == .injoignable)
    }

    // MARK: Transport chiffre et domaine

    @Test("Une adresse en clair non confirmee ne laisse partir aucune requete")
    func adresseEnClairRefusee() async throws {
        let catalogue = CatalogueOpdsDeTest(CatalogueOpdsDeTest.reglesCompletes())
        let source = try await catalogue.source(adresse: ReponsesFigeesDOpds.adresseEnClair)

        #expect(await source.verifierConnexion() == .erreur)
        #expect(await catalogue.transport.journal.isEmpty)
    }

    @Test("Un lien vers un autre domaine que le catalogue est refuse")
    func lienHorsDuCatalogueRefuse() async throws {
        let catalogue = CatalogueOpdsDeTest(CatalogueOpdsDeTest.reglesCompletes())
        let source = try await catalogue.source()

        // Le mot de passe de l utilisateur part sur chaque requete. Un catalogue
        // qui renverrait vers un autre hote se le ferait presenter, ce qui est
        // une fuite et non une redirection.
        await #expect(throws: ErreurDeSource.self) {
            _ = try await source.detailsManga("https://ailleurs.exemple.test/opds/v1.2/series/berserk")
        }
        #expect(await catalogue.transport.journal.isEmpty)
    }

    @Test("Une source sans adresse ne se construit pas")
    func sourceSansAdresseRefusee() async throws {
        let catalogue = CatalogueOpdsDeTest([])

        await #expect(throws: ErreurDeConfigurationDeSource.illisible) {
            _ = try await catalogue.source(adresse: nil)
        }
    }

    // MARK: Capacites

    @Test("La source declare la pagination et le telechargement, et rien d autre")
    func capacitesDeclarees() async throws {
        let catalogue = CatalogueOpdsDeTest([])
        let source = try await catalogue.source()

        #expect(source.capacites == [.pagination, .telechargement])
        #expect(source.declare(.recherche) == false)
        #expect(source.declare(.filtres) == false)
        #expect(source.declare(.progressionDistante) == false)
        #expect(source.declare(.plusieursLangues) == false)
    }

    @Test("La recherche non declaree est refusee par une erreur nommee")
    func rechercheRefusee() async throws {
        let catalogue = CatalogueOpdsDeTest(CatalogueOpdsDeTest.reglesCompletes())
        let source = try await catalogue.source()

        await #expect(throws: ErreurDeSource.self) {
            _ = try await source.rechercher(RequeteRecherche(texte: "berserk"))
        }
        // Le refus est prononce sans interroger le catalogue : la capacite est
        // une propriete de la source, pas une reponse du serveur.
        #expect(await catalogue.transport.journal.isEmpty)
    }

    @Test("Une section que le catalogue ne publie pas est refusee")
    func sectionNonPubliee() async throws {
        let catalogue = CatalogueOpdsDeTest(CatalogueOpdsDeTest.reglesCompletes())
        let source = try await catalogue.source()

        await #expect(throws: ErreurDeSource.self) {
            _ = try await source.parcourir(.populaires, page: 0)
        }
    }

    @Test("La section des nouveautes suit le lien que la racine publie")
    func sectionDesNouveautes() async throws {
        let catalogue = CatalogueOpdsDeTest(CatalogueOpdsDeTest.reglesCompletes())
        let source = try await catalogue.source()

        let nouveautes = try await source.parcourir(.recentes, page: 0)

        #expect(nouveautes.elements.map(\.titre) == ["Yotsuba"])
        #expect(await catalogue.transport.derniere?.chemin.hasSuffix("/series/nouveautes") == true)
    }

    // MARK: Parcours en OPDS 1.2

    @Test("Le catalogue Atom est rendu par pages, et la suite est annoncee")
    func parcoursDuCatalogueAtom() async throws {
        let catalogue = CatalogueOpdsDeTest(CatalogueOpdsDeTest.reglesCompletes())
        let source = try await catalogue.source()

        let premiere = try await source.parcourir(.tout, page: 0)
        let seconde = try await source.parcourir(.tout, page: 1)

        #expect(premiere.elements.map(\.titre) == ["Berserk", "Vinland Saga"])
        #expect(premiere.page == 0)
        #expect(premiere.ilResteDesPages)
        #expect(seconde.elements.map(\.titre) == ["Yotsuba"])
        #expect(seconde.page == 1)
        #expect(seconde.ilResteDesPages == false)
    }

    @Test("Les metadonnees d une serie Atom traversent jusqu au domaine")
    func metadonneesDeSerieAtom() async throws {
        let catalogue = CatalogueOpdsDeTest(CatalogueOpdsDeTest.reglesCompletes())
        let source = try await catalogue.source()

        let premiere = try await source.parcourir(.tout, page: 0)
        let berserk = try #require(premiere.elements.first)

        #expect(berserk.identifiant == identifiantDeLaSerieAtom)
        #expect(berserk.auteurs == ["Kentaro Miura"])
        #expect(berserk.genres == ["Action", "Fantasy"])
        #expect(berserk.langue == "ja")
        #expect(berserk.urlCouverture == "https://opds.exemple.test/opds/v1.2/series/berserk/couverture")
    }

    @Test("Un lien relatif sans barre de tete se resout sur le flux qui le porte")
    func lienRelatifResolu() async throws {
        let catalogue = CatalogueOpdsDeTest(CatalogueOpdsDeTest.reglesCompletes())
        let source = try await catalogue.source()

        let premiere = try await source.parcourir(.tout, page: 0)
        let vinland = try #require(premiere.elements.last)

        #expect(vinland.identifiant == "https://opds.exemple.test/opds/v1.2/series/vinland")
    }

    // MARK: Parcours en OPDS 2.0

    @Test("Le catalogue JSON est rendu par pages, groupes compris")
    func parcoursDuCatalogueJson() async throws {
        let catalogue = CatalogueOpdsDeTest(CatalogueOpdsDeTest.reglesCompletes())
        let source = try await catalogue.source(chemin: ReponsesFigeesDOpds.cheminDuCatalogueJson)

        let premiere = try await source.parcourir(.tout, page: 0)
        let seconde = try await source.parcourir(.tout, page: 1)

        #expect(premiere.elements.map(\.titre) == ["Berserk", "Vinland Saga", "Yotsuba"])
        #expect(premiere.ilResteDesPages)
        #expect(seconde.elements.map(\.titre) == ["Pluto"])
        #expect(seconde.ilResteDesPages == false)
    }

    @Test("Les chapitres d une serie JSON sont traduits champ par champ")
    func chapitresDeSerieJson() async throws {
        let catalogue = CatalogueOpdsDeTest(CatalogueOpdsDeTest.reglesCompletes())
        let source = try await catalogue.source(chemin: ReponsesFigeesDOpds.cheminDuCatalogueJson)

        let chapitres = try await source.chapitres(pour: identifiantDeLaSerieJson)
        let premier = try #require(chapitres.first)

        #expect(chapitres.map(\.titre) == ["Chapitre 1", "Chapitre 2"])
        #expect(chapitres.map(\.numero) == [1, 2])
        #expect(chapitres.map(\.ordre) == [0, 1])
        #expect(premier.identifiant == "https://opds.exemple.test/opds/v2/books/1/file")
        #expect(premier.identifiantManga == identifiantDeLaSerieJson)
        #expect(premier.langue == "ja")
        #expect(premier.nombrePages == 3)
        #expect(premier.datePublication == DatesDeTest.instant(2026, 1, 2, HeureDeTest(10, 0)))
    }

    // MARK: Pagination par les liens next

    @Test("La page suivante est demandee a l adresse du lien next, pas a une adresse calculee")
    func paginationSuitLeLienNext() async throws {
        let catalogue = CatalogueOpdsDeTest(CatalogueOpdsDeTest.reglesCompletes())
        let source = try await catalogue.source()

        _ = try await source.parcourir(.tout, page: 1)

        let journal = await catalogue.transport.journal

        // Deux requetes, dans cet ordre : la racine, puis l adresse exacte que la
        // racine a publiee. Cette adresse porte un jeton qu aucune convention de
        // pagination ne permet de fabriquer, et c est lui qui prouve que le lien
        // a ete suivi plutot que devine.
        #expect(journal.count == 2)
        #expect(journal.first?.parametre("page") == nil)
        #expect(journal.last?.parametre("page") == "1")
        #expect(journal.last?.parametre("jeton") == "suite-imprevisible")
        #expect(journal.last?.chemin.hasSuffix("/opds/v1.2/series") == true)
    }

    @Test("Une page deja atteinte est relue sans reparcourir la chaine")
    func pageDejaAtteinteRelueDirectement() async throws {
        let catalogue = CatalogueOpdsDeTest(CatalogueOpdsDeTest.reglesCompletes())
        let source = try await catalogue.source()

        _ = try await source.parcourir(.tout, page: 1)
        let avant = await catalogue.transport.journal.count
        let relue = try await source.parcourir(.tout, page: 1)
        let apres = await catalogue.transport.journal.count

        #expect(relue.elements.map(\.titre) == ["Yotsuba"])
        // Une seule requete de plus : l adresse de la page etait deja connue, la
        // racine n a pas eu a etre relue pour la retrouver.
        #expect(apres - avant == 1)
    }

    @Test("Une page au dela de la fin rend une liste vide et non la derniere page")
    func pageAuDelaDeLaFin() async throws {
        let catalogue = CatalogueOpdsDeTest(CatalogueOpdsDeTest.reglesCompletes())
        let source = try await catalogue.source()

        let trop = try await source.parcourir(.tout, page: 5)

        #expect(trop.elements.isEmpty)
        #expect(trop.ilResteDesPages == false)
    }

    @Test("Les chapitres d une serie sont collectes sur tous les flux enchaines")
    func chapitresSurPlusieursFlux() async throws {
        let catalogue = CatalogueOpdsDeTest(CatalogueOpdsDeTest.reglesCompletes())
        let source = try await catalogue.source()

        let chapitres = try await source.chapitres(pour: identifiantDeLaSerieAtom)

        // Le troisieme chapitre vit sur le second flux de la serie. S arreter au
        // premier flux le perdrait sans que rien ne le dise.
        #expect(chapitres.map(\.titre) == ["Chapitre 1", "Chapitre 2", "Chapitre 10"])
        #expect(chapitres.map(\.numero) == [1, 2, 10])
        #expect(chapitres.map(\.ordre) == [0, 1, 2])
    }

    // MARK: Fiche de serie

    @Test("Une fiche ouverte depuis le catalogue garde ce que le catalogue portait")
    func ficheDepuisLeCatalogue() async throws {
        let catalogue = CatalogueOpdsDeTest(CatalogueOpdsDeTest.reglesCompletes())
        let source = try await catalogue.source()

        _ = try await source.parcourir(.tout, page: 0)
        let fiche = try await source.detailsManga(identifiantDeLaSerieAtom)

        #expect(fiche.titre == "Berserk")
        #expect(fiche.resume == "Un mercenaire marque par un sacrifice.")
        #expect(fiche.genres == ["Action", "Fantasy"])
    }

    @Test("Une fiche ouverte sans le catalogue se rabat sur le titre du flux")
    func ficheSansLeCatalogue() async throws {
        let catalogue = CatalogueOpdsDeTest(CatalogueOpdsDeTest.reglesCompletes())
        let source = try await catalogue.source()

        let fiche = try await source.detailsManga(identifiantDeLaSerieAtom)

        // Le flux d une serie ne porte que son titre. La fiche le dit sans rien
        // inventer, plutot que de rendre un resume vide et des genres faux.
        #expect(fiche.titre == "Berserk")
        #expect(fiche.resume == nil)
        #expect(fiche.genres.isEmpty)
    }

    @Test("Une serie qui ne repond pas est nommee introuvable")
    func serieIntrouvable() async throws {
        let catalogue = CatalogueOpdsDeTest(CatalogueOpdsDeTest.reglesCompletes())
        let source = try await catalogue.source()
        let absente = "https://opds.exemple.test/opds/v1.2/series/disparue"

        await #expect(throws: ErreurDeSource.mangaIntrouvable(identifiant: absente)) {
            _ = try await source.detailsManga(absente)
        }
    }

    // MARK: Constantes

    private var identifiantDeLaSerieAtom: String {
        "https://opds.exemple.test/" + ReponsesFigeesDOpds.cheminDeLaSerieAtom
    }

    private var identifiantDeLaSerieJson: String {
        "https://opds.exemple.test/" + ReponsesFigeesDOpds.cheminDeLaSerieJson
    }
}
