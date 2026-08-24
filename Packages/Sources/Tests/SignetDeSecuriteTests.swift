import Core
import Foundation
import Testing
@testable import Sources

/// Couvre le premier critere de la fonctionnalite : le dossier choisi reste
/// accessible apres redemarrage de l application.
///
/// Le redemarrage est reproduit sans tricher : la seconde source est construite
/// par `depuisLeSignet`, qui ne recoit jamais l URL du dossier, et son magasin
/// est une instance neuve posee sur le meme fichier. Si le signet n etait pas
/// reellement persiste et resolu, aucun de ces tests ne passerait.
struct SignetDeSecuriteTests {
    // MARK: Signet seul

    @Test("Un signet cree se resout sur le meme dossier")
    func resolutionSurLeMemeDossier() throws {
        let arbre = try ArbreDeTest()
        try arbre.image("Serie/page1.jpg")

        let signet = try SignetDeSecurite.creer(pour: arbre.racine, source: "test")
        let resolution = try signet.resoudre(source: "test")

        #expect(resolution.dossier.standardizedFileURL.path == arbre.racine.standardizedFileURL.path)
    }

    @Test("Un magasin range le signet dans un fichier et le rend a une autre instance")
    func persistanceDansLeFichier() throws {
        let espace = try ArbreDeTest(nom: "magasin")
        let fichier = espace.racine.appending(path: "signets.json")
        let arbre = try ArbreDeTest()

        let signet = try SignetDeSecurite.creer(pour: arbre.racine, source: "test")
        try MagasinDeSignetsFichier(fichier: fichier).enregistrer(signet, pour: "source")

        let relu = try MagasinDeSignetsFichier(fichier: fichier).signet(pour: "source")

        #expect(relu == signet)
    }

    @Test("Un magasin vide ne rend aucun signet")
    func magasinVide() throws {
        let espace = try ArbreDeTest(nom: "magasin")
        let magasin = MagasinDeSignetsFichier(fichier: espace.racine.appending(path: "signets.json"))

        #expect(try magasin.signet(pour: "source") == nil)
    }

    @Test("Un signet oublie ne se resout plus")
    func signetOublie() throws {
        let espace = try ArbreDeTest(nom: "magasin")
        let fichier = espace.racine.appending(path: "signets.json")
        let arbre = try ArbreDeTest()

        let magasin = MagasinDeSignetsFichier(fichier: fichier)
        try magasin.enregistrer(
            SignetDeSecurite.creer(pour: arbre.racine, source: "test"),
            pour: "source"
        )
        try magasin.oublier("source")

        #expect(try MagasinDeSignetsFichier(fichier: fichier).signet(pour: "source") == nil)
    }

    // MARK: Redemarrage

    @Test("Le dossier reste lisible apres redemarrage, sans jamais revoir son URL")
    func dossierLisibleApresRedemarrage() async throws {
        let arbre = try ArbreDeTest()
        try BibliothequeDeTest.poser(dans: arbre)

        let environnement = try EnvironnementDeSource(arbre: arbre)
        let avant = try await environnement.sourcePremierLancement()
            .parcourir(.tout, page: 0)
            .elements
            .map(\.titre)

        let apres = try await environnement.sourceApresRedemarrage()
            .parcourir(.tout, page: 0)
            .elements
            .map(\.titre)

        #expect(avant == ["Serie A", "Serie B", "Serie C", "Tome unique"])
        #expect(apres == avant)
    }

    @Test("Les pages restent lisibles apres redemarrage")
    func pagesLisiblesApresRedemarrage() async throws {
        let arbre = try ArbreDeTest()
        try BibliothequeDeTest.poser(dans: arbre)

        let environnement = try EnvironnementDeSource(arbre: arbre)
        _ = try await environnement.sourcePremierLancement().analyse()

        let pages = try await environnement.sourceApresRedemarrage()
            .pages(pour: "Serie A/Chapitre 1.cbz")

        #expect(pages.map(\.entree) == ["page1.jpg", "page2.jpg", "page10.jpg"])
    }

    @Test("Le dossier renomme entre deux lancements reste accessible")
    func dossierRenommeResteAccessible() async throws {
        let arbre = try ArbreDeTest()
        try BibliothequeDeTest.poser(dans: arbre)

        let environnement = try EnvironnementDeSource(arbre: arbre)
        _ = try await environnement.sourcePremierLancement().analyse()

        // Le signet designe le noeud du systeme de fichiers, pas le chemin.
        // Un dossier renomme reste donc le meme dossier.
        try arbre.renommerLaRacine(en: "bibliotheque-renommee")

        let titres = try await environnement.sourceApresRedemarrage()
            .parcourir(.tout, page: 0)
            .elements
            .map(\.titre)

        #expect(titres == ["Serie A", "Serie B", "Serie C", "Tome unique"])
    }

    @Test("La verification de connexion repond connecte quand le dossier est la")
    func connexionVerifiee() async throws {
        let arbre = try ArbreDeTest()
        try arbre.image("Serie/page1.jpg")

        let environnement = try EnvironnementDeSource(arbre: arbre)
        _ = try environnement.sourcePremierLancement()

        #expect(await environnement.sourceApresRedemarrage().verifierConnexion() == .connecte)
    }

    // MARK: Acces perdu

    @Test("Sans signet range, la source declare son acces perdu")
    func sansSignet() async throws {
        let arbre = try ArbreDeTest()
        try BibliothequeDeTest.poser(dans: arbre)

        let source = try EnvironnementDeSource(arbre: arbre).sourceSansSignet()

        await #expect(throws: ErreurDeSource.accesAuDossierPerdu(source: EnvironnementDeSource.nomDeLaSource)) {
            _ = try await source.parcourir(.tout, page: 0)
        }
        #expect(await source.verifierConnexion() == .injoignable)
    }

    @Test("Un dossier supprime rend la source injoignable")
    func dossierSupprime() async throws {
        let arbre = try ArbreDeTest()
        try BibliothequeDeTest.poser(dans: arbre)

        let environnement = try EnvironnementDeSource(arbre: arbre)
        _ = try environnement.sourcePremierLancement()

        try arbre.supprimerLaRacine()

        let source = environnement.sourceApresRedemarrage()

        #expect(await source.verifierConnexion() == .injoignable)
        await #expect(throws: ErreurDeSource.accesAuDossierPerdu(source: EnvironnementDeSource.nomDeLaSource)) {
            _ = try await source.parcourir(.tout, page: 0)
        }
    }
}
