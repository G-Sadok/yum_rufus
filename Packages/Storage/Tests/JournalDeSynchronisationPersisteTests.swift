import Core
import Foundation
import GRDB
import Testing
@testable import Storage

//
// Couvre la partie du troisieme critere que seule une vraie base peut prouver :
// les changements accumules hors ligne survivent a la fermeture de
// l application, et l application d un changement recu ne double pas
// l historique de lecture.
//
// Les tests de survie ouvrent un fichier sur disque et non une base en memoire.
// Une base en memoire disparait avec le processus quel que soit le code teste,
// elle ne prouverait donc rien de ce que la reprise doit retrouver.
//

struct JournalDeSynchronisationPersisteTests {
    /// Dossier temporaire supprime quand le test le relache.
    final class DossierTemporaire {
        let url: URL

        init() throws {
            url = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("synchronisation-\(UUID().uuidString)")

            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }

        var fichierDeBase: URL {
            url.appendingPathComponent("bibliotheque.sqlite")
        }

        deinit {
            try? FileManager.default.removeItem(at: url)
        }
    }

    static let depart = Date(timeIntervalSince1970: 1_700_000_000)

    static func progression(
        chapitre: UUID,
        page: Int,
        secondes: TimeInterval,
        estLu: Bool = false
    ) throws -> ChangementSynchronise {
        try ProgressionSynchronisee(
            chapitreId: chapitre,
            pageAtteinte: page,
            estLu: estLu,
            dateLecture: depart.addingTimeInterval(secondes)
        ).changement(depuis: "appareil-a")
    }

    @Test("Le journal survit a une fermeture brutale de l application")
    func journalPersistant() async throws {
        let dossier = try DossierTemporaire()
        let chapitre = UUID()

        do {
            let base = try BaseDeDonnees.surDisque(a: dossier.fichierDeBase)
            let magasin = MagasinDeSynchronisation(base: base)

            try await magasin.consigner([Self.progression(chapitre: chapitre, page: 17, secondes: 0)])
            try await magasin.definirLeJetonDistant(Data("jeton-42".utf8))
        }

        let relancee = try BaseDeDonnees.surDisque(a: dossier.fichierDeBase)
        let magasin = MagasinDeSynchronisation(base: relancee)
        let journal = try await magasin.journal()

        #expect(journal.nombreEnAttente == 1)
        #expect(try await magasin.jetonDistant() == Data("jeton-42".utf8))

        let ligne = try #require(journal.changements.first)

        #expect(try ProgressionSynchronisee.lire(ligne).pageAtteinte == 17)
    }

    @Test("L identifiant d appareil ne change pas d un lancement a l autre")
    func identifiantDAppareilStable() async throws {
        let dossier = try DossierTemporaire()
        let premier: String

        do {
            let base = try BaseDeDonnees.surDisque(a: dossier.fichierDeBase)
            let magasin = MagasinDeSynchronisation(base: base)

            premier = try await magasin.identifiantDAppareil()

            #expect(try await magasin.identifiantDAppareil() == premier)
        }

        let relancee = try BaseDeDonnees.surDisque(a: dossier.fichierDeBase)

        #expect(try await MagasinDeSynchronisation(base: relancee).identifiantDAppareil() == premier)
        #expect(premier.isEmpty == false)
    }

    @Test("Deux cents enregistrements du meme chapitre tiennent en une ligne de table")
    func regroupementEnBase() async throws {
        let base = try BaseDeDonnees.enMemoire()
        let magasin = MagasinDeSynchronisation(base: base)
        let chapitre = UUID()

        for page in 0..<200 {
            try await magasin.consigner([
                Self.progression(chapitre: chapitre, page: page, secondes: Double(page) * 2),
            ])
        }

        let lignes = try await base.ecrivain.read { connexion in
            try ChangementPersiste.fetchCount(connexion)
        }

        #expect(lignes == 1)
        #expect(try await magasin.journal().nombreEnAttente == 1)
    }

    @Test("Une ligne remplacee pendant l envoi n est pas retiree")
    func retraitSelectif() async throws {
        let base = try BaseDeDonnees.enMemoire()
        let magasin = MagasinDeSynchronisation(base: base)
        let chapitre = UUID()

        let partie = try Self.progression(chapitre: chapitre, page: 10, secondes: 0)
        try await magasin.consigner([partie])
        try await magasin.consigner([Self.progression(chapitre: chapitre, page: 11, secondes: 2)])
        try await magasin.retirer([partie])

        let journal = try await magasin.journal()
        let restante = try #require(journal.changements.first)

        #expect(journal.nombreEnAttente == 1)
        #expect(try ProgressionSynchronisee.lire(restante).pageAtteinte == 11)
    }

    @Test("Un changement recu ecrit la position sans toucher a l historique")
    func applicationSansHistorique() async throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 2, pagesParChapitre: 40)
        let magasin = MagasinDeSynchronisation(base: base)
        let chapitre = jeu.chapitres[0].id

        let appliques = try await magasin.appliquer([
            Self.progression(chapitre: chapitre, page: 20, secondes: 100),
        ])

        let relu = try await base.ecrivain.read { connexion in
            try Chapitre.fetchOne(connexion, key: chapitre)
        }
        let entreesDHistorique = try await base.ecrivain.read { connexion in
            try EntreeHistorique.fetchCount(connexion)
        }

        #expect(appliques.count == 1)
        #expect(relu?.pageAtteinte == 20)
        #expect(relu?.dateLecture == Self.depart.addingTimeInterval(100))
        #expect(entreesDHistorique == 0)
    }

    @Test("Une lecture locale plus recente resiste au changement recu")
    func lectureLocalePlusRecente() async throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 1, pagesParChapitre: 40)
        let magasin = MagasinDeSynchronisation(base: base)
        let chapitre = jeu.chapitres[0].id

        try MagasinDeProgression(base: base).enregistrer(
            PositionDeLecture(chapitreId: chapitre, pageIndex: 30),
            le: Self.depart.addingTimeInterval(200)
        )

        let appliques = try await magasin.appliquer([
            Self.progression(chapitre: chapitre, page: 5, secondes: 100),
        ])

        let relu = try await base.ecrivain.read { connexion in
            try Chapitre.fetchOne(connexion, key: chapitre)
        }

        #expect(appliques.isEmpty)
        #expect(relu?.pageAtteinte == 30)
    }

    @Test("Un chapitre lu ici ne redevient pas non lu")
    func marquageQuiNeReculePas() async throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 1, pagesParChapitre: 40)
        let magasin = MagasinDeSynchronisation(base: base)
        let chapitre = jeu.chapitres[0].id

        try await magasin.appliquer([Self.progression(chapitre: chapitre, page: 39, secondes: 100, estLu: true)])
        try await magasin.appliquer([Self.progression(chapitre: chapitre, page: 2, secondes: 200)])

        let relu = try await base.ecrivain.read { connexion in
            try Chapitre.fetchOne(connexion, key: chapitre)
        }

        #expect(relu?.estLu == true)
        #expect(relu?.pageAtteinte == 2)
    }

    @Test("Le meme lot rejoue deux fois ne change rien la seconde fois")
    func applicationIdempotente() async throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 1, pagesParChapitre: 40)
        let magasin = MagasinDeSynchronisation(base: base)
        let lot = try [Self.progression(chapitre: jeu.chapitres[0].id, page: 12, secondes: 100)]

        let premier = try await magasin.appliquer(lot)
        let second = try await magasin.appliquer(lot)

        #expect(premier.count == 1)
        #expect(second.isEmpty)
    }

    @Test("Un chapitre absent de cet appareil ne fait pas tomber le lot")
    func chapitreAbsentIgnore() async throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 1, pagesParChapitre: 40)
        let magasin = MagasinDeSynchronisation(base: base)

        let appliques = try await magasin.appliquer([
            Self.progression(chapitre: UUID(), page: 3, secondes: 100),
            Self.progression(chapitre: jeu.chapitres[0].id, page: 7, secondes: 100),
        ])

        #expect(appliques.count == 1)
    }

    @Test("La serie recue entre dans la bibliotheque et en sort")
    func applicationDeLaSerie() async throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 1)
        let magasin = MagasinDeSynchronisation(base: base)

        let retrait = try SerieSynchronisee(
            mangaId: jeu.manga.id,
            estDansBibliotheque: false,
            dateAjout: jeu.manga.dateAjout,
            dateDeChangement: Self.depart.addingTimeInterval(100)
        ).changement(depuis: "appareil-b")

        try await magasin.appliquer([retrait])

        let relu = try await base.ecrivain.read { connexion in
            try Manga.fetchOne(connexion, key: jeu.manga.id)
        }

        #expect(relu?.estDansBibliotheque == false)
    }

    @Test("Un retrait de serie rejoue apres un ajout plus recent est ignore")
    func serieArbitreeParHorodatage() async throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 1)
        let magasin = MagasinDeSynchronisation(base: base)

        let retrait = try SerieSynchronisee(
            mangaId: jeu.manga.id,
            estDansBibliotheque: false,
            dateAjout: jeu.manga.dateAjout,
            dateDeChangement: Self.depart.addingTimeInterval(100)
        ).changement(depuis: "appareil-b")

        let ajout = try SerieSynchronisee(
            mangaId: jeu.manga.id,
            estDansBibliotheque: true,
            dateAjout: jeu.manga.dateAjout,
            dateDeChangement: Self.depart.addingTimeInterval(200)
        ).changement(depuis: "appareil-b")

        try await magasin.appliquer([retrait])
        try await magasin.appliquer([ajout])

        // Le distant renvoie l ancien retrait apres un jeton perime.
        try await magasin.appliquer([retrait])

        let relu = try await base.ecrivain.read { connexion in
            try Manga.fetchOne(connexion, key: jeu.manga.id)
        }

        #expect(relu?.estDansBibliotheque == true)
    }

    @Test("La serie remonte dans la grille apres une lecture sur un autre appareil")
    func rangDeLaSerieMisAJour() async throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 1, pagesParChapitre: 40)
        let magasin = MagasinDeSynchronisation(base: base)

        try await magasin.appliquer([
            Self.progression(chapitre: jeu.chapitres[0].id, page: 4, secondes: 300),
        ])

        let relu = try await base.ecrivain.read { connexion in
            try Manga.fetchOne(connexion, key: jeu.manga.id)
        }

        #expect(relu?.dateDerniereLecture == Self.depart.addingTimeInterval(300))
    }
}
