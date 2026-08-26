import Core
import Foundation
import Testing
@testable import Sources

//
// SourcePartageReseauTests
//
// La source vue du dessus : ce que l ecran Parcourir en obtiendra, et ce que la
// lecture en obtiendra.
//
// Le deuxieme critere est repris ici, et ce n est pas une redite du test de
// `LectureEnFluxTests`. Celui la prouve que la reprise ne repaie pas ce qui est
// deja arrive ; celui ci prouve que la coupure remonte jusqu a l utilisateur
// sous une erreur qui nomme la cause et indique la sortie, au lieu d un echec
// inattendu que personne ne saurait lire.
//

struct SourcePartageReseauTests {
    static let adresse = URL(fileURLWithPath: "/partage-de-test")

    /// Reglages de flux sans attente ni nouvel essai.
    static let reglagesSansReprise = ReglagesDeFlux(essais: 1, attendre: { _ in })

    /// Une bibliotheque a deux niveaux, comme un utilisateur la range.
    static func partageGarni(
        archive: ArchiveSynthetique = ArchiveSynthetique(nombreDePages: 5, octetsParPage: 300 * 1024)
    ) async -> PartageSimule {
        let partage = PartageSimule()

        await partage.ajouter(fichier: "Berserk/Tome 01.cbz", contenu: .archive(archive))
        await partage.ajouter(fichier: "Berserk/Tome 02.cbz", contenu: .archive(archive))
        await partage.ajouter(fichier: "Vinland Saga/Chapitre 1/page02.jpg", octets: Data(repeating: 2, count: 40))
        await partage.ajouter(fichier: "Vinland Saga/Chapitre 1/page10.jpg", octets: Data(repeating: 10, count: 60))
        await partage.ajouter(fichier: "Vinland Saga/Chapitre 1/.DS_Store", octets: Data(repeating: 0, count: 8))
        await partage.ajouter(fichier: "Tome unique.cbz", contenu: .archive(archive))

        return partage
    }

    static func source(sur partage: PartageSimule) -> SourcePartageReseau {
        SourcePartageReseau(
            nom: "Partage de test",
            partage: partage,
            adresse: adresse,
            reglages: reglagesSansReprise,
            dossierDeCache: FileManager.default.temporaryDirectory
                .appending(path: "tsuzuki-tests/\(UUID().uuidString)")
        )
    }

    // MARK: Catalogue

    @Test("Le partage se parcourt selon la convention a deux niveaux")
    func parcoursDuPartage() async throws {
        let source = await Self.source(sur: Self.partageGarni())
        let catalogue = try await source.parcourir(.tout, page: 0)

        #expect(catalogue.elements.map(\.titre) == ["Berserk", "Tome unique", "Vinland Saga"])
        #expect(catalogue.ilResteDesPages == false)

        let chapitres = try await source.chapitres(pour: "Berserk")

        #expect(chapitres.map(\.titre) == ["Tome 01", "Tome 02"])
        #expect(chapitres.map(\.ordre) == [0, 1])
        #expect(chapitres.map(\.numero) == [1, 2])
    }

    @Test("Une archive posee a la racine est une serie a chapitre unique")
    func archiveALaRacine() async throws {
        let source = await Self.source(sur: Self.partageGarni())
        let serie = try await source.detailsManga("Tome unique.cbz")

        #expect(serie.titre == "Tome unique")
        #expect(serie.nombreChapitres == 1)
    }

    @Test("La recherche filtre sur le titre, sans casse ni accent")
    func recherche() async throws {
        let source = await Self.source(sur: Self.partageGarni())
        let trouves = try await source.rechercher(RequeteRecherche(texte: "berserk"))

        #expect(trouves.elements.map(\.titre) == ["Berserk"])
    }

    @Test("Le classement par popularite est refuse plutot qu invente")
    func popularitesRefusees() async throws {
        let source = await Self.source(sur: Self.partageGarni())

        await #expect(throws: ErreurDeSource.sectionNonPriseEnCharge(section: .populaires, source: "Partage de test")) {
            _ = try await source.parcourir(.populaires, page: 0)
        }
    }

    @Test("Un partage injoignable rend un etat injoignable, pas une erreur brute")
    func partageInjoignable() async {
        let partage = PartageSimule()
        await partage.ajouter(fichier: "Serie/Tome.cbz", octets: Data(repeating: 1, count: 10))
        await partage.couper(apres: 0, panne: .connexionRefusee)

        let source = Self.source(sur: partage)

        // Le listage de la racine reste possible, la coupure ne porte que sur
        // les lectures. C est bien l etat connecte qui doit revenir.
        #expect(await source.verifierConnexion() == .connecte)
    }

    // MARK: Pages

    @Test("Les pages d un chapitre range en CBZ viennent de l index, pas du fichier")
    func pagesDUneArchive() async throws {
        let archive = ArchiveSynthetique(nombreDePages: 12, octetsParPage: 1024 * 1024)
        let partage = await Self.partageGarni(archive: archive)
        let source = Self.source(sur: partage)

        let pages = try await source.pages(pour: "Berserk/Tome 01.cbz")

        // La verification sort de la macro : `allSatisfy` y est vu comme
        // pouvant lever, et la forme qui compile a l interieur est justement
        // celle que SwiftFormat reecrit en chemin de cle.
        let toutesDansUnConteneur = pages.allSatisfy(\.estDansUnConteneur)

        #expect(pages.count == 12)
        #expect(pages.map(\.entree) == archive.nomsDesPages)
        #expect(toutesDansUnConteneur)

        let servis = await partage.octetsServis

        #expect(servis < archive.taille / 4)
    }

    @Test("Les pages d un chapitre en dossier suivent le tri naturel")
    func pagesPosees() async throws {
        let source = await Self.source(sur: Self.partageGarni())
        let pages = try await source.pages(pour: "Vinland Saga/Chapitre 1")

        // Le tri est naturel, donc `page02` avant `page10`, et le parasite du
        // systeme de fichiers a disparu.
        #expect(pages.map(\.entree) == ["page02.jpg", "page10.jpg"])
        #expect(pages.map(\.octets) == [40, 60])
    }

    @Test("Les octets d une page de dossier sont ceux du fichier")
    func octetsDUnePagePosee() async throws {
        let source = await Self.source(sur: Self.partageGarni())
        let pages = try await source.pages(pour: "Vinland Saga/Chapitre 1")
        let octets = try await source.donnees(page: pages[1])

        #expect(octets == Data(repeating: 10, count: 60))
    }

    @Test("Les octets d une page de CBZ se lisent en flux")
    func octetsDUnePageDArchive() async throws {
        let archive = ArchiveSynthetique(nombreDePages: 12, octetsParPage: 1024 * 1024)
        let partage = await Self.partageGarni(archive: archive)
        let source = Self.source(sur: partage)

        let pages = try await source.pages(pour: "Berserk/Tome 01.cbz")
        let octets = try await source.donnees(page: pages[3])

        #expect(octets == archive.contenuDUnePage)

        let rapatries = await source.octetsRapatries(pour: "Berserk/Tome 01.cbz")

        #expect(rapatries < archive.taille / 2)
        #expect(await partage.octetsServis == rapatries)
    }

    @Test("Aucune page d un partage ne s obtient par une requete")
    func aucuneRequeteDImage() async throws {
        let source = await Self.source(sur: Self.partageGarni())
        let pages = try await source.pages(pour: "Berserk/Tome 01.cbz")

        await #expect(throws: ErreurDeSource.self) {
            _ = try await source.requeteImage(pour: pages[0])
        }
    }

    // MARK: Deuxieme critere, vu de l utilisateur

    @Test("La perte de connexion remonte une erreur qui nomme la cause")
    func coupureNommeeALUtilisateur() async throws {
        let archive = ArchiveSynthetique(nombreDePages: 6, octetsParPage: 700 * 1024)
        let partage = await Self.partageGarni(archive: archive)
        let source = Self.source(sur: partage)

        let pages = try await source.pages(pour: "Berserk/Tome 01.cbz")
        await partage.couper(apres: partage.octetsServis)

        let attrapee: (any Error)?

        do {
            _ = try await source.donnees(page: pages[2])
            attrapee = nil
        } catch {
            attrapee = error
        }

        let erreur = try #require(attrapee as? ErreurDeSource)

        #expect(erreur == .reseau(.horsLigne, source: "Partage de test"))
        #expect(erreur.etatDeConnexion == .injoignable)
        #expect(erreur.messageUtilisateur.contains("Partage de test"))
        #expect(erreur.messageUtilisateur.contains(ErreurReseau.horsLigne.messageUtilisateur))

        // Le journal ne porte ni le nom du partage ni un chemin de fichier.
        #expect(erreur.codeDeJournal == "source.reseau.horsLigne")
    }

    @Test("La lecture relancee apres retablissement aboutit et ne repaie pas tout")
    func repriseVueDeLaSource() async throws {
        let archive = ArchiveSynthetique(nombreDePages: 6, octetsParPage: 2 * 1024 * 1024)
        let partage = await Self.partageGarni(archive: archive)
        let source = Self.source(sur: partage)

        let pages = try await source.pages(pour: "Berserk/Tome 01.cbz")
        let avant = await partage.octetsServis
        await partage.couper(apres: avant + 1024 * 1024)

        await #expect(throws: ErreurDeSource.reseau(.horsLigne, source: "Partage de test")) {
            _ = try await source.donnees(page: pages[4])
        }

        let apresLaCoupure = await partage.octetsServis
        await partage.retablir()

        let octets = try await source.donnees(page: pages[4])

        #expect(octets == archive.contenuDUnePage)
        #expect(await partage.octetsServis - apresLaCoupure < UInt64(2 * 1024 * 1024))
    }
}
