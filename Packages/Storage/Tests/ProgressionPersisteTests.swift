import Core
import Foundation
import GRDB
import Testing
@testable import Storage

/// Position de reprise et marquage automatique, section 7.5.
///
/// Les deux premiers tests ouvrent une vraie base sur disque et non une base en
/// memoire. Une base en memoire ne prouverait rien de la survie a une fermeture
/// brutale : elle disparait avec le processus, quel que soit le code teste.
struct ProgressionPersisteTests {
    /// Dossier temporaire supprime quand le test le relache.
    final class DossierTemporaire {
        let url: URL

        init() throws {
            url = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("progression-\(UUID().uuidString)")

            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }

        var fichierDeBase: URL {
            url.appendingPathComponent("bibliotheque.sqlite")
        }

        deinit {
            try? FileManager.default.removeItem(at: url)
        }
    }

    @Test("La position survit a une fermeture brutale de l application")
    func laPositionSurvitAUneFermetureBrutale() throws {
        let dossier = try DossierTemporaire()
        let chapitre: UUID

        // Premiere session. Rien n est ferme, rien n est vide a la main : la
        // session se termine comme si le processus avait ete tue.
        do {
            let base = try BaseDeDonnees.surDisque(a: dossier.fichierDeBase)
            let jeu = try JeuDeDonneesDeTest.inserer(
                dans: base,
                nombreDeChapitres: 3,
                pagesParChapitre: 40
            )

            chapitre = jeu.chapitres[1].id

            try MagasinDeProgression(base: base).enregistrer(
                PositionDeLecture(chapitreId: chapitre, pageIndex: 17, decalageDeDefilement: 0.25)
            )
        }

        // Seconde session, sur le meme fichier, avec une connexion neuve.
        let relancee = try BaseDeDonnees.surDisque(a: dossier.fichierDeBase)
        let reprise = try MagasinDeProgression(base: relancee).position(duChapitre: chapitre)

        #expect(reprise.pageIndex == 17)
        #expect(reprise.decalageDeDefilement == 0.25)
    }

    @Test("La position est lisible avant meme la fermeture de la session")
    func laPositionEstLisibleParUneAutreConnexion() throws {
        let dossier = try DossierTemporaire()

        let base = try BaseDeDonnees.surDisque(a: dossier.fichierDeBase)
        let jeu = try JeuDeDonneesDeTest.inserer(
            dans: base,
            nombreDeChapitres: 1,
            pagesParChapitre: 40
        )
        let chapitre = jeu.chapitres[0].id

        try MagasinDeProgression(base: base).enregistrer(
            PositionDeLecture(chapitreId: chapitre, pageIndex: 9, decalageDeDefilement: 0.5)
        )

        // La premiere base reste ouverte et n est ni fermee ni vidangee. Une
        // seconde connexion, independante, doit deja voir la position : c est
        // la preuve que la transaction est validee sur le disque et non
        // retenue en attendant une fermeture propre.
        let autreConnexion = try BaseDeDonnees.surDisque(a: dossier.fichierDeBase)
        let vue = try MagasinDeProgression(base: autreConnexion).position(duChapitre: chapitre)

        #expect(vue.pageIndex == 9)
        #expect(vue.decalageDeDefilement == 0.5)
    }

    @Test("Le decalage de defilement est enregistre avec la page")
    func leDecalageEstEnregistre() throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(
            dans: base,
            nombreDeChapitres: 1,
            pagesParChapitre: 30
        )
        let magasin = MagasinDeProgression(base: base)
        let chapitre = jeu.chapitres[0].id

        try magasin.enregistrer(
            PositionDeLecture(chapitreId: chapitre, pageIndex: 4, decalageDeDefilement: 0.62)
        )

        let colonne = try base.ecrivain.read { connexion in
            try Double.fetchOne(
                connexion,
                sql: "SELECT decalageDeDefilement FROM chapitre WHERE id = ?",
                arguments: [chapitre]
            )
        }

        #expect(colonne == 0.62)
        #expect(try magasin.position(duChapitre: chapitre).decalageDeDefilement == 0.62)
    }

    @Test("Un decalage hors bornes est ramene entre zero et un")
    func leDecalageEstBorne() throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(
            dans: base,
            nombreDeChapitres: 1,
            pagesParChapitre: 30
        )
        let magasin = MagasinDeProgression(base: base)
        let chapitre = jeu.chapitres[0].id

        try magasin.enregistrer(
            PositionDeLecture(chapitreId: chapitre, pageIndex: 2, decalageDeDefilement: 4.2)
        )

        #expect(try magasin.position(duChapitre: chapitre).decalageDeDefilement == 1)
    }

    @Test("Un chapitre atteint a plus de 95 pour cent est marque lu")
    func auDelaDuSeuilLeChapitreEstMarqueLu() throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(
            dans: base,
            nombreDeChapitres: 2,
            pagesParChapitre: 100
        )
        let magasin = MagasinDeProgression(base: base)
        let chapitre = jeu.chapitres[0].id

        // Page quatre vingt seize sur cent : quatre vingt seize pour cent.
        try magasin.enregistrer(PositionDeLecture(chapitreId: chapitre, pageIndex: 95))

        let relu = try Self.chapitre(chapitre, dans: base)

        #expect(relu.estLu)
        #expect(relu.pageAtteinte == 95)
        #expect(relu.dateLecture != nil)

        // Le compteur denormalise suit, par declencheur et non par le magasin.
        #expect(try JeuDeDonneesDeTest.chapitresNonLus(de: jeu.manga.id, dans: base) == 1)
    }

    @Test("Un chapitre pile a 95 pour cent reste en cours")
    func pileAuSeuilLeChapitreResteEnCours() throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(
            dans: base,
            nombreDeChapitres: 1,
            pagesParChapitre: 100
        )
        let magasin = MagasinDeProgression(base: base)
        let chapitre = jeu.chapitres[0].id

        // Page quatre vingt quinze sur cent : exactement le seuil.
        try magasin.enregistrer(PositionDeLecture(chapitreId: chapitre, pageIndex: 94))

        let relu = try Self.chapitre(chapitre, dans: base)

        #expect(relu.estLu == false)
        #expect(try JeuDeDonneesDeTest.chapitresNonLus(de: jeu.manga.id, dans: base) == 1)
    }

    @Test("La derniere page d un chapitre court le marque lu")
    func laDernierePageMarqueLu() throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(
            dans: base,
            nombreDeChapitres: 1,
            pagesParChapitre: 20
        )
        let magasin = MagasinDeProgression(base: base)
        let chapitre = jeu.chapitres[0].id

        try magasin.enregistrer(PositionDeLecture(chapitreId: chapitre, pageIndex: 18))
        #expect(try Self.chapitre(chapitre, dans: base).estLu == false)

        try magasin.enregistrer(PositionDeLecture(chapitreId: chapitre, pageIndex: 19))
        #expect(try Self.chapitre(chapitre, dans: base).estLu)
    }

    @Test("Un chapitre deja lu que l on rouvre au debut reste lu")
    func unChapitreLuNeRedevientPasNonLu() throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(
            dans: base,
            nombreDeChapitres: 1,
            pagesParChapitre: 20
        )
        let magasin = MagasinDeProgression(base: base)
        let chapitre = jeu.chapitres[0].id

        try magasin.enregistrer(PositionDeLecture(chapitreId: chapitre, pageIndex: 19))
        try magasin.enregistrer(PositionDeLecture(chapitreId: chapitre, pageIndex: 0))

        let relu = try Self.chapitre(chapitre, dans: base)

        #expect(relu.estLu, "Le marquage automatique ne doit aller que dans un sens")
        #expect(relu.pageAtteinte == 0, "La reprise doit suivre l utilisateur, meme en arriere")
    }

    @Test("Une page au dela du chapitre est ramenee a la derniere")
    func lIndexEstBorneParLeChapitre() throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(
            dans: base,
            nombreDeChapitres: 1,
            pagesParChapitre: 20
        )
        let magasin = MagasinDeProgression(base: base)
        let chapitre = jeu.chapitres[0].id

        try magasin.enregistrer(PositionDeLecture(chapitreId: chapitre, pageIndex: 400))

        #expect(try Self.chapitre(chapitre, dans: base).pageAtteinte == 19)
    }

    @Test("La serie porte la date de sa derniere lecture")
    func laSeriePorteLaDateDeDerniereLecture() throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(
            dans: base,
            nombreDeChapitres: 1,
            pagesParChapitre: 20
        )
        let date = Date(timeIntervalSince1970: 1_700_000_000)

        try MagasinDeProgression(base: base).enregistrer(
            PositionDeLecture(chapitreId: jeu.chapitres[0].id, pageIndex: 3),
            le: date
        )

        let lue = try base.ecrivain.read { connexion in
            try Date.fetchOne(
                connexion,
                sql: "SELECT dateDerniereLecture FROM manga WHERE id = ?",
                arguments: [jeu.manga.id]
            )
        }

        #expect(lue == date)
    }

    @Test("Un chapitre supprime remonte une erreur nommee")
    func unChapitreInconnuRemonteUneErreur() throws {
        let base = try BaseDeDonnees.enMemoire()
        let magasin = MagasinDeProgression(base: base)
        let fantome = UUID()

        #expect(throws: ErreurDeProgression.chapitreInconnu(identifiant: fantome)) {
            try magasin.enregistrer(PositionDeLecture(chapitreId: fantome, pageIndex: 0))
        }

        #expect(throws: ErreurDeProgression.chapitreInconnu(identifiant: fantome)) {
            try magasin.position(duChapitre: fantome)
        }
    }

    @Test("Un chapitre jamais ouvert reprend en premiere page")
    func unChapitreNeufReprendAuDebut() throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(
            dans: base,
            nombreDeChapitres: 1,
            pagesParChapitre: 20
        )

        let position = try MagasinDeProgression(base: base).position(duChapitre: jeu.chapitres[0].id)

        #expect(position.pageIndex == 0)
        #expect(position.decalageDeDefilement == 0)
    }

    /// Relit un chapitre depuis la base.
    private static func chapitre(_ identifiant: UUID, dans base: BaseDeDonnees) throws -> Chapitre {
        try base.ecrivain.read { connexion in
            try #require(try Chapitre.fetchOne(connexion, key: identifiant))
        }
    }
}
