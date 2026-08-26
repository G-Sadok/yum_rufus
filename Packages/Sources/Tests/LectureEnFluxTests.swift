import Core
import Foundation
import Testing
@testable import Sources

//
// LectureEnFluxTests
//
// Les deux premiers criteres de la fonctionnalite, mesures et non constates.
//
// Le premier critere se prouve par un compteur, pas par une ouverture reussie.
// Une source qui rapatrierait le conteneur entier ouvrirait la page tout aussi
// bien. Ce qui separe les deux comportements est le nombre d octets qui a
// traverse le partage, et c est la seule chose que ces tests regardent.
//
// Le deuxieme se prouve par un compteur lui aussi. Verifier qu une lecture
// relancee finit par aboutir ne prouve pas la reprise : une lecture qui
// recommencerait de zero aboutirait pareil, en repayant tout. Ce qui prouve la
// reprise, c est que la seconde tentative ne redemande que ce qui manquait.
//

struct LectureEnFluxTests {
    /// Reglages de flux sans attente ni nouvel essai.
    ///
    /// Les nouveaux essais sont retires parce que le test de coupure veut voir
    /// l erreur, pas la voir rattrapee. L attente est retiree parce qu une suite
    /// de tests n a pas a dormir.
    static let reglagesSansReprise = ReglagesDeFlux(essais: 1, attendre: { _ in })

    // MARK: Premier critere

    @Test("Un CBZ de 200 Mo s ouvre sans etre copie entierement en local")
    func ouvertureSansCopieComplete() async throws {
        let archive = ArchiveSynthetique(nombreDePages: 40, octetsParPage: 5 * 1024 * 1024)

        // Le conteneur pese bien les deux cents mega octets du critere.
        #expect(archive.taille > 200_000_000)

        let partage = PartageSimule()
        await partage.ajouter(fichier: "Berserk 01.cbz", contenu: .archive(archive))

        let conteneur = ConteneurDePartage(
            partage: partage,
            chemin: "Berserk 01.cbz",
            taille: archive.taille,
            nom: "Berserk 01",
            reglages: Self.reglagesSansReprise
        )

        let pages = try await conteneur.pages()

        #expect(pages.count == 40)
        #expect(pages.map(\.nom) == archive.nomsDesPages)

        // Enumerer les pages ne lit que la queue du fichier et son index central.
        let apresLIndex = await partage.octetsServis

        #expect(apresLIndex < 2 * 1024 * 1024)

        let octets = try await conteneur.donnees(page: pages[20])

        #expect(octets == archive.contenuDUnePage)

        // L index, plus une page de cinq mega octets, et rien d autre. Un
        // rapatriement complet en aurait servi deux cents fois plus.
        let total = await partage.octetsServis

        #expect(total < 8 * 1024 * 1024)
        #expect(total < archive.taille / 20)
    }

    @Test("Ouvrir la page vingt ne lit jamais les octets de la page dix neuf")
    func accesDirectSansLirePagesPrecedentes() async throws {
        let archive = ArchiveSynthetique(nombreDePages: 12, octetsParPage: 512 * 1024)
        let partage = PartageSimule()
        await partage.ajouter(fichier: "Serie/Tome 01.cbz", contenu: .archive(archive))

        let conteneur = ConteneurDePartage(
            partage: partage,
            chemin: "Serie/Tome 01.cbz",
            taille: archive.taille,
            nom: "Tome 01",
            reglages: Self.reglagesSansReprise
        )

        let pages = try await conteneur.pages()
        _ = try await conteneur.donnees(page: pages[9])

        // Le poids d une page, plus les blocs ou vivent la queue du fichier et
        // l index central. Jamais le poids des dix pages qui la precedent, ce
        // qu une lecture sequentielle aurait paye.
        let total = await partage.octetsServis

        #expect(total < UInt64(4 * 512 * 1024))
        #expect(total < archive.taille / 2)
    }

    @Test("Une page relue ne redemande rien au partage")
    func relectureSansTransfert() async throws {
        let archive = ArchiveSynthetique(nombreDePages: 4, octetsParPage: 256 * 1024)
        let partage = PartageSimule()
        await partage.ajouter(fichier: "Tome.cbz", contenu: .archive(archive))

        let conteneur = ConteneurDePartage(
            partage: partage,
            chemin: "Tome.cbz",
            taille: archive.taille,
            nom: "Tome",
            reglages: Self.reglagesSansReprise
        )

        let pages = try await conteneur.pages()
        _ = try await conteneur.donnees(page: pages[1])

        let apresLaPremiere = await partage.octetsServis
        let relue = try await conteneur.donnees(page: pages[1])

        #expect(relue == archive.contenuDUnePage)
        #expect(await partage.octetsServis == apresLaPremiere)
    }

    // MARK: Deuxieme critere

    @Test("La perte de connexion produit une erreur claire")
    func coupureNommee() async throws {
        let archive = ArchiveSynthetique(nombreDePages: 8, octetsParPage: 1024 * 1024)
        let partage = PartageSimule()
        await partage.ajouter(fichier: "Tome.cbz", contenu: .archive(archive))

        let conteneur = ConteneurDePartage(
            partage: partage,
            chemin: "Tome.cbz",
            taille: archive.taille,
            nom: "Tome",
            reglages: Self.reglagesSansReprise
        )

        let pages = try await conteneur.pages()
        await partage.couper(apres: partage.octetsServis)

        await #expect(throws: ErreurReseau.horsLigne) {
            _ = try await conteneur.donnees(page: pages[3])
        }
    }

    @Test("La lecture reprise apres coupure ne redemande que ce qui manquait")
    func repriseApresCoupure() async throws {
        let archive = ArchiveSynthetique(nombreDePages: 8, octetsParPage: 2 * 1024 * 1024)
        let partage = PartageSimule()
        await partage.ajouter(fichier: "Tome.cbz", contenu: .archive(archive))

        let conteneur = ConteneurDePartage(
            partage: partage,
            chemin: "Tome.cbz",
            taille: archive.taille,
            nom: "Tome",
            reglages: Self.reglagesSansReprise
        )

        let pages = try await conteneur.pages()

        // La coupure tombe apres un mega octet de page, donc au milieu des deux
        // que la page pese. Ce qui est deja arrive doit survivre a la coupure.
        let avantLaPage = await partage.octetsServis
        await partage.couper(apres: avantLaPage + 1024 * 1024)

        await #expect(throws: ErreurReseau.horsLigne) {
            _ = try await conteneur.donnees(page: pages[5])
        }

        let apresLaCoupure = await partage.octetsServis

        #expect(apresLaCoupure > avantLaPage)

        await partage.retablir()

        let octets = try await conteneur.donnees(page: pages[5])

        #expect(octets == archive.contenuDUnePage)

        // La reprise n a paye que le reste de la page. Une lecture qui aurait
        // recommence de zero aurait servi les deux mega octets une seconde fois.
        let apresLaReprise = await partage.octetsServis
        let coutDeLaReprise = apresLaReprise - apresLaCoupure

        #expect(coutDeLaReprise < UInt64(2 * 1024 * 1024))
        #expect(apresLaReprise - avantLaPage < UInt64(3 * 1024 * 1024))
    }

    @Test("Une panne passagere est retentee, un refus d identifiants ne l est pas")
    func nouvelEssaiSurLesSeulesPannesPassageres() async throws {
        let archive = ArchiveSynthetique(nombreDePages: 2, octetsParPage: 64 * 1024)
        let partage = PartageSimule()
        await partage.ajouter(fichier: "Tome.cbz", contenu: .archive(archive))

        let conteneur = ConteneurDePartage(
            partage: partage,
            chemin: "Tome.cbz",
            taille: archive.taille,
            nom: "Tome",
            reglages: ReglagesDeFlux(essais: 3, attendre: { _ in })
        )

        await partage.couper(apres: 0, panne: .authentificationRefusee)

        await #expect(throws: ErreurReseau.authentificationRefusee) {
            _ = try await conteneur.pages()
        }

        // Un refus d identifiants ne se rejoue pas : une seule lecture est
        // partie, alors que trois essais etaient accordes.
        #expect(await partage.lectures.count == 1)

        await partage.remettreLesCompteurs()
        await partage.couper(apres: 0, panne: .delaiDepasse)

        await #expect(throws: ErreurReseau.delaiDepasse) {
            _ = try await conteneur.pages()
        }

        // Un delai depasse, lui, vaut les trois essais accordes.
        #expect(await partage.lectures.count == 3)
    }

    // MARK: Tampon

    @Test("Une reponse plus courte que demandee est completee, pas refusee")
    func reponsesCourtesCompletees() async throws {
        let archive = ArchiveSynthetique(nombreDePages: 3, octetsParPage: 700 * 1024)
        // Le partage ne rend que soixante quatre kilo octets par lecture, la ou
        // le tampon en demande cinq cent douze. Sans reclamation de la suite, la
        // lecture echouerait sur chaque bloc.
        let partage = PartageSimule(plafondParLecture: 64 * 1024)
        await partage.ajouter(fichier: "Tome.cbz", contenu: .archive(archive))

        let conteneur = ConteneurDePartage(
            partage: partage,
            chemin: "Tome.cbz",
            taille: archive.taille,
            nom: "Tome",
            reglages: Self.reglagesSansReprise
        )

        let pages = try await conteneur.pages()
        let octets = try await conteneur.donnees(page: pages[2])

        #expect(octets == archive.contenuDUnePage)
    }

    @Test("Le tampon ne garde jamais plus que son plafond")
    func plafondMemoireTenu() async throws {
        let archive = ArchiveSynthetique(nombreDePages: 20, octetsParPage: 256 * 1024)
        let partage = PartageSimule()
        await partage.ajouter(fichier: "Tome.cbz", contenu: .archive(archive))

        let tampon = TamponDePartage(
            partage: partage,
            chemin: "Tome.cbz",
            taille: archive.taille,
            nom: "Tome",
            reglages: ReglagesDeFlux(
                tailleDeBloc: 64 * 1024,
                plafond: 256 * 1024,
                essais: 1,
                attendre: { _ in }
            )
        )

        for rang in 0..<16 {
            try await tampon.hydrater(offset: UInt64(rang) * 64 * 1024, longueur: 64 * 1024)
        }

        let vue = await tampon.vue()
        let poids = vue.blocs.values.reduce(0) { $0 + $1.count }

        #expect(poids <= 256 * 1024)
    }

    @Test("Une plage qui sort du fichier est refusee sans aller sur le reseau")
    func plageHorsBornes() async throws {
        let partage = PartageSimule()
        await partage.ajouter(fichier: "petit.bin", octets: Data(repeating: 7, count: 100))

        let tampon = TamponDePartage(
            partage: partage,
            chemin: "petit.bin",
            taille: 100,
            nom: "petit.bin",
            reglages: Self.reglagesSansReprise
        )
        let vue = await tampon.vue()

        #expect(throws: ErreurDeDocument.conteneurTronque(chemin: "petit.bin")) {
            _ = try vue.lire(a: 90, longueur: 20)
        }
    }
}
