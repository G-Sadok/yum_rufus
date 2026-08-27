import Core
import Foundation
import Testing
@testable import Sources

//
// Couvre le moteur de la file, section 4.11 de DESIGN-SPEC.md.
//
// Les trois criteres d acceptation de la fonctionnalite se jouent ici, chacun
// sur le comportement reel du moteur et non sur un calcul isole.
//
// La reprise est verifiee sur ce que le serveur recoit, pas seulement sur ce que
// la file affiche : une tache qui repartirait de zero en le cachant afficherait
// exactement la meme progression finale, et seule la liste des chemins demandes
// fait la difference.
//

struct MoteurDeTelechargementTests {
    private static let nombreDePages = 6

    private func moteur(
        journal: FileDeTest,
        depot: DepotDeTest,
        serveur: ServeurDePages
    ) -> MoteurDeTelechargement {
        MoteurDeTelechargement(
            journal: journal,
            depot: depot,
            pages: PagesFigees(nombreDePages: Self.nombreDePages),
            transport: serveur
        )
    }

    // MARK: Un chapitre entier

    @Test("Un chapitre se telecharge page par page, dans l ordre de lecture")
    func chapitreComplet() async throws {
        let chapitre = UUID()
        let journal = FileDeTest()
        let depot = DepotDeTest()
        let serveur = ServeurDePages()

        let tache = await journal.ajouter(chapitre: chapitre)

        await moteur(journal: journal, depot: depot, serveur: serveur).vider { .wifi }

        let terminee = try #require(await journal.tache(tache))

        #expect(terminee.etat == .termine)
        #expect(terminee.progression == 1)
        #expect(await depot.nombreDePagesScellees(du: chapitre) == Self.nombreDePages)

        for page in 0..<Self.nombreDePages {
            #expect(await depot.page(page, du: chapitre) == ServeurDePages.contenu(page: page))
        }
    }

    // MARK: Reprise apres interruption

    @Test("Un telechargement interrompu ne redemande pas les pages deja scellees")
    func repriseALaPageSuivante() async throws {
        let chapitre = UUID()
        let journal = FileDeTest()
        let depot = DepotDeTest()
        let serveur = ServeurDePages()

        let tache = await journal.ajouter(chapitre: chapitre)
        await serveur.programmerUnePanne(.reponseTronquee, page: 3, du: chapitre)

        await moteur(journal: journal, depot: depot, serveur: serveur).vider { .wifi }

        let interrompue = try #require(await journal.tache(tache))

        #expect(interrompue.etat == .echoue)
        #expect(interrompue.pagesTerminees == 3, "Trois pages scellees avant la coupure")
        #expect(await depot.nombreDePagesScellees(du: chapitre) == 3)

        // Relance : le serveur repond de nouveau, la tache repart dans la file.
        await serveur.reparer()
        try await journal.remettreEnAttente(tache)

        await moteur(journal: journal, depot: depot, serveur: serveur).vider { .wifi }

        let reprise = try #require(await journal.tache(tache))

        #expect(reprise.etat == .termine)
        #expect(await depot.nombreDePagesScellees(du: chapitre) == Self.nombreDePages)

        // Les trois premieres pages n ont ete demandees qu une seule fois. C est
        // le critere : la reprise repart ou elle s est arretee, elle ne
        // recommence pas le chapitre.
        let chemins = await serveur.journal()

        for page in 0..<3 {
            let chemin = ServeurDePages.chemin(chapitre: chapitre, page: page)

            #expect(chemins.filter { $0 == chemin }.count == 1, "Page \(page) redemandee")
        }
    }

    @Test("Un fragment laisse par une coupure est complete, pas jete")
    func repriseAuMilieuDUnePage() async throws {
        let chapitre = UUID()
        let journal = FileDeTest()
        let depot = DepotDeTest()
        let serveur = ServeurDePages()

        let tache = await journal.ajouter(chapitre: chapitre)

        // Une fermeture brutale entre l ecriture et le scellement laisse un
        // fichier partiel. C est exactement ce que le suffixe de fragment sert a
        // distinguer d une page complete.
        let debut = ServeurDePages.contenu(page: 0).prefix(200)
        await depot.deposerUnFragment(Data(debut), page: 0, du: chapitre)

        await moteur(journal: journal, depot: depot, serveur: serveur).vider { .wifi }

        #expect(await serveur.plage(page: 0, du: chapitre) == "bytes=200-")
        #expect(await depot.page(0, du: chapitre) == ServeurDePages.contenu(page: 0))
        #expect(try #require(await journal.tache(tache)).etat == .termine)
    }

    @Test("Un serveur qui refuse la tranche fait repartir la page de zero")
    func trancheRefusee() async throws {
        let chapitre = UUID()
        let journal = FileDeTest()
        let depot = DepotDeTest()
        let serveur = ServeurDePages()

        let tache = await journal.ajouter(chapitre: chapitre)

        // Un fragment plus long que la page servie : le serveur repond 416, la
        // page doit repartir de zero plutot que de rester coincee.
        let trop = Data(repeating: 7, count: ServeurDePages.poidsDUnePage + 64)
        await depot.deposerUnFragment(trop, page: 0, du: chapitre)

        await moteur(journal: journal, depot: depot, serveur: serveur).vider { .wifi }

        #expect(await depot.page(0, du: chapitre) == ServeurDePages.contenu(page: 0))
        #expect(try #require(await journal.tache(tache)).etat == .termine)
    }

    @Test("Un echec nomme la cause reelle plutot que de rester vague")
    func lEchecNommeSaCause() async throws {
        let chapitre = UUID()
        let journal = FileDeTest()
        let depot = DepotDeTest()
        let serveur = ServeurDePages()

        let tache = await journal.ajouter(chapitre: chapitre)
        await serveur.programmerUnePanne(.horsLigne, page: 0, du: chapitre)

        await moteur(journal: journal, depot: depot, serveur: serveur).vider { .wifi }

        let echouee = try #require(await journal.tache(tache))

        #expect(echouee.etat == .echoue)
        #expect(echouee.messageErreur == ErreurReseau.horsLigne.messageUtilisateur)
    }

    // MARK: Limite de telechargements simultanes

    @Test("Le moteur ne mene jamais plus de chapitres de front que la limite", arguments: [1, 2, 3, 5])
    func laLimiteEstTenue(limite: Int) async throws {
        let journal = FileDeTest(reglages: ReglagesDeTelechargement(simultanes: limite))
        let depot = DepotDeTest()
        let serveur = ServeurDePages()

        var taches: [UUID] = []

        for rang in 0..<8 {
            await taches.append(journal.ajouter(chapitre: UUID(), numero: Double(rang + 1), rang: rang))
        }

        await moteur(journal: journal, depot: depot, serveur: serveur).vider { .wifi }

        #expect(await journal.pointeDeTachesEnCours <= limite)
        #expect(await serveur.pointeDeRequetesDeFront <= limite)

        for tache in taches {
            #expect(try #require(await journal.tache(tache)).etat == .termine)
        }
    }

    @Test("La limite se voit vraiment, sinon le test ne prouverait rien")
    func laLimiteEstAtteinte() async {
        let journal = FileDeTest(reglages: ReglagesDeTelechargement(simultanes: 3))
        let depot = DepotDeTest()
        let serveur = ServeurDePages()

        for rang in 0..<6 {
            await journal.ajouter(chapitre: UUID(), numero: Double(rang + 1), rang: rang)
        }

        await moteur(journal: journal, depot: depot, serveur: serveur).vider { .wifi }

        // Sans cette verification, une limite tenue a un par accident passerait
        // pour une limite de trois respectee.
        #expect(await journal.pointeDeTachesEnCours == 3)
    }

    // MARK: Restriction au reseau

    @Test("Hors Wi-Fi, la file ne travaille pas et ne se vide pas")
    func leWiFiSeulementArreteLeMoteur() async throws {
        let chapitre = UUID()
        let journal = FileDeTest(
            reglages: ReglagesDeTelechargement(simultanes: 3, enWiFiSeulement: true)
        )
        let depot = DepotDeTest()
        let serveur = ServeurDePages()

        let tache = await journal.ajouter(chapitre: chapitre)

        await moteur(journal: journal, depot: depot, serveur: serveur).vider { .cellulaire }

        let restee = try #require(await journal.tache(tache))

        #expect(restee.etat == .enAttente, "La file se remplit hors Wi-Fi, elle ne se vide pas")
        #expect(await serveur.journal().isEmpty)
        #expect(await depot.nombreDePagesScellees(du: chapitre) == 0)
    }

    // MARK: Progression

    @Test("La progression avance d exactement une page par page scellee")
    func laProgressionEstExacte() async throws {
        let chapitre = UUID()
        let journal = FileDeTest()
        let depot = DepotDeTest()
        let serveur = ServeurDePages()

        let tache = await journal.ajouter(chapitre: chapitre)
        await serveur.programmerUnePanne(.delaiDepasse, page: 4, du: chapitre)

        await moteur(journal: journal, depot: depot, serveur: serveur).vider { .wifi }

        let arretee = try #require(await journal.tache(tache))

        #expect(arretee.pagesTerminees == 4)
        #expect(arretee.nombreDePages == Self.nombreDePages)
        #expect(arretee.progression == 4.0 / Double(Self.nombreDePages))

        // Les octets comptes correspondent aux pages reellement posees, ce qui
        // est la seule facon d afficher un poids juste sur la ligne terminee.
        #expect(arretee.octetsRecus == 4 * ServeurDePages.poidsDUnePage)
    }

    @Test("Le cumul d octets ne compte pas deux fois ceux d avant la coupure")
    func leCumulNeCompteJamaisDeuxFois() async throws {
        let chapitre = UUID()
        let journal = FileDeTest()
        let depot = DepotDeTest()
        let serveur = ServeurDePages()

        let tache = await journal.ajouter(chapitre: chapitre)
        let debut = ServeurDePages.contenu(page: 0).prefix(200)
        await depot.deposerUnFragment(Data(debut), page: 0, du: chapitre)

        await moteur(journal: journal, depot: depot, serveur: serveur).vider { .wifi }

        let terminee = try #require(await journal.tache(tache))

        // Le fragment de 200 octets etait deja sur le disque et n avait jamais
        // ete compte. Le cumul ne retient donc que les 312 octets rapportes par
        // la reprise, plus les cinq pages suivantes.
        let attendu = (ServeurDePages.poidsDUnePage - 200)
            + (Self.nombreDePages - 1) * ServeurDePages.poidsDUnePage

        #expect(terminee.octetsRecus == attendu)
    }
}
