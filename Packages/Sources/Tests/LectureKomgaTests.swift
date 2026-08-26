import Core
import Foundation
import Testing
@testable import Sources

//
// LectureKomgaTests
//
// Seconde moitie du premier critere : de la fiche de serie jusqu a la requete
// qui rapporte les octets d une page.
//
// Le dernier test refait la chaine entiere sans fabriquer aucun etat
// intermediaire. C est ce qui distingue une suite qui verifie des fonctions
// d une suite qui verifie que la source fonctionne : chaque etape n y consomme
// que ce que la precedente a reellement rendu.
//

struct LectureKomgaTests {
    // MARK: Fiche et chapitres

    @Test("Le detail d une serie absente nomme la serie, pas le code HTTP")
    func detailIntrouvable() async throws {
        let serveur = ServeurKomgaDeTest([.statut("api/v1/series/disparue", 404)])
        let source = try await serveur.source()

        await #expect(throws: ErreurDeSource.mangaIntrouvable(identifiant: "disparue")) {
            _ = try await source.detailsManga("disparue")
        }
    }

    @Test("La liste des chapitres suit la pagination jusqu au dernier livre")
    func chapitresSurPlusieursTranches() async throws {
        let serveur = ServeurKomgaDeTest(ServeurKomgaDeTest.reglesCompletes)
        let source = try await serveur.source()
        let serie = ReponsesFigeesDeKomga.identifiantDeSerie
        let chapitres = try await source.chapitres(pour: serie)

        #expect(chapitres.count == 3)
        #expect(chapitres.map(\.ordre) == [0, 1, 2])
        // Le premier porte son numero trie, le deuxieme n a que son numero
        // textuel, le troisieme n a aucune metadonnee et retombe sur son rang.
        #expect(chapitres.map(\.numero) == [1, 2.5, 3])
        #expect(chapitres.map(\.identifiantManga).allSatisfy { $0 == serie })
        #expect(chapitres.map(\.titre) == ["L oeuf du roi", "Tome 02 bonus", nil])
        // Zero page veut dire inconnu chez Komga, jamais vide.
        #expect(chapitres.map(\.nombrePages) == [3, nil, 12])
    }

    @Test("La date de parution d un chapitre est lue au format du serveur")
    func dateDeParutionLue() async throws {
        let serveur = ServeurKomgaDeTest(ServeurKomgaDeTest.reglesCompletes)
        let source = try await serveur.source()
        let chapitres = try await source.chapitres(pour: ReponsesFigeesDeKomga.identifiantDeSerie)
        let premier = try #require(chapitres.first)

        #expect(premier.datePublication == DatesDeTest.jour(1990, 11, 26))
        // Le serveur rend une date nulle sur le deuxieme livre, elle le reste.
        #expect(chapitres[1].datePublication == nil)
    }

    // MARK: Pages

    @Test("Les pages sont triees et indexees a partir de zero")
    func pagesTriees() async throws {
        let serveur = ServeurKomgaDeTest(ServeurKomgaDeTest.reglesCompletes)
        let source = try await serveur.source()
        let livre = ReponsesFigeesDeKomga.identifiantDuPremierLivre
        let pages = try await source.pages(pour: livre)

        #expect(pages.map(\.index) == [0, 1, 2])
        #expect(pages.map(\.octets) == [102_400, 204_800, nil])
        #expect(pages.allSatisfy { $0.identifiantChapitre == livre })
        #expect(pages.allSatisfy { $0.estDansUnConteneur == false })
        // Komga numerote ses pages a partir de un dans l adresse.
        #expect(pages.map(\.emplacement.lastPathComponent) == ["1", "2", "3"])
    }

    @Test("Un chapitre absent nomme le chapitre, pas le code HTTP")
    func pagesDUnChapitreAbsent() async throws {
        let serveur = ServeurKomgaDeTest([.statut("api/v1/books/disparu/pages", 404)])
        let source = try await serveur.source()

        await #expect(throws: ErreurDeSource.chapitreIntrouvable(identifiant: "disparu")) {
            _ = try await source.pages(pour: "disparu")
        }
    }

    @Test("La requete d image porte l identite de la source")
    func requeteImageAuthentifiee() async throws {
        let serveur = ServeurKomgaDeTest(ServeurKomgaDeTest.reglesCompletes)
        let source = try await serveur.source()
        let pages = try await source.pages(pour: ReponsesFigeesDeKomga.identifiantDuPremierLivre)
        let page = try #require(pages.first)
        let requete = try await source.requeteImage(pour: page)

        #expect(requete.url == page.emplacement)
        #expect(requete.value(forHTTPHeaderField: "Authorization")?.hasPrefix("Basic ") == true)
    }

    @Test("Une page rangee dans un conteneur n est pas adressable par requete")
    func requeteImageRefuseeSurUnConteneur() async throws {
        let serveur = ServeurKomgaDeTest(ServeurKomgaDeTest.reglesCompletes)
        let source = try await serveur.source()
        let page = try PageDistante(
            identifiantChapitre: "livre",
            index: 0,
            emplacement: #require(ReponsesFigeesDeKomga.adresse),
            entree: "001.jpg"
        )

        await #expect(throws: ErreurDeSource.pageNonAdressableParRequete(entree: "001.jpg")) {
            _ = try await source.requeteImage(pour: page)
        }
    }

    // MARK: De bout en bout

    @Test("Connexion, parcours puis lecture s enchainent sans etat fabrique")
    func chaineComplete() async throws {
        let serveur = ServeurKomgaDeTest(ServeurKomgaDeTest.reglesCompletes)
        let source = try await serveur.source()

        #expect(await source.verifierConnexion() == .connecte)

        let catalogue = try await source.parcourir(.tout, page: 0)
        let premiere = try #require(catalogue.elements.first)
        let fiche = try await source.detailsManga(premiere.identifiant)
        let chapitres = try await source.chapitres(pour: fiche.identifiant)
        let premierChapitre = try #require(chapitres.first)
        let pages = try await source.pages(pour: premierChapitre.identifiant)
        let premierePage = try #require(pages.first)
        let requete = try await source.requeteImage(pour: premierePage)

        #expect(fiche.titre == "Berserk")
        #expect(chapitres.count == 3)
        #expect(pages.count == 3)
        #expect(premierChapitre.nombrePages == pages.count)
        #expect(requete.url?.absoluteString.hasSuffix(
            "/api/v1/books/\(ReponsesFigeesDeKomga.identifiantDuPremierLivre)/pages/1"
        ) == true)
    }

    @Test("Un serveur publie derriere un sous chemin garde ce sous chemin")
    func sousCheminDeProxyConserve() async throws {
        let serveur = ServeurKomgaDeTest(ServeurKomgaDeTest.reglesCompletes)
        let identite = SourceID()

        await serveur.magasin.enregistrer(.aucun, pour: identite)

        let source = try SourceKomga(
            id: identite,
            nom: serveur.nom,
            configuration: ConfigurationDeSource(
                adresse: ReponsesFigeesDeKomga.adresse,
                chemin: "komga"
            ),
            magasin: serveur.magasin,
            transport: serveur.transport
        )

        #expect(await source.verifierConnexion() == .connecte)
        #expect(await serveur.transport.derniere?.chemin == "/komga/api/v1/users/me")
    }
}
