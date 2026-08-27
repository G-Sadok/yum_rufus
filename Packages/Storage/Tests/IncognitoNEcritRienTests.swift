import Core
import Foundation
import GRDB
import Testing
@testable import Storage

//
// Premier critere de F051 : aucune ecriture n a lieu pendant une session
// incognito.
//
// Le critere n est pas verifiable par un compteur d appels. Un magasin peut
// tres bien refuser d ecrire la position et laisser passer la date de derniere
// lecture de la serie, ou l entree d historique, ou le marquage automatique, qui
// partent tous dans la meme transaction. La suite compare donc la base entiere,
// table par table et ligne par ligne, avant et apres une session de lecture
// complete. S il reste la moindre difference, le test vire au rouge sans avoir
// eu besoin de savoir laquelle.
//
// Le test temoin fait exactement la meme session sans le mode incognito et exige
// que l empreinte change. Sans lui, un magasin casse qui n ecrirait plus rien du
// tout passerait le premier test.
//

struct IncognitoNEcritRienTests {
    /// Empreinte complete de la base : toutes les tables, toutes les lignes.
    ///
    /// Les lignes sont triees sur leur representation, parce que SQLite ne
    /// promet aucun ordre sans clause explicite et qu une comparaison sensible a
    /// l ordre virerait au rouge sans qu aucune donnee ait bouge.
    static func empreinte(de base: BaseDeDonnees) throws -> [String: [String]] {
        try base.ecrivain.read { connexion in
            let tables = try String.fetchAll(
                connexion,
                sql: """
                SELECT name FROM sqlite_master
                WHERE type = 'table'
                  AND name NOT LIKE 'sqlite_%'
                  AND name NOT LIKE 'grdb_%'
                ORDER BY name
                """
            )

            var empreinte: [String: [String]] = [:]

            for table in tables {
                let lignes = try Row.fetchAll(connexion, sql: "SELECT * FROM \"\(table)\"")
                empreinte[table] = lignes.map(String.init(describing:)).sorted()
            }

            return empreinte
        }
    }

    /// Une session de lecture ordinaire, telle que le moteur la produit.
    ///
    /// Trois chapitres parcourus, dont un mene assez loin pour franchir le seuil
    /// de marquage automatique, plus une consignation d historique demandee
    /// directement. Tout ce qu une heure de lecture depose en base passe par la.
    static func lireTroisChapitres(
        progression: MagasinDeProgression,
        historique: MagasinDHistorique,
        chapitres: [UUID]
    ) async throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)

        for (rang, chapitre) in chapitres.enumerated() {
            for page in stride(from: 0, to: 100, by: 20) {
                try progression.enregistrer(
                    PositionDeLecture(
                        chapitreId: chapitre,
                        pageIndex: page,
                        decalageDeDefilement: 0.5
                    ),
                    le: date.addingTimeInterval(Double(rang * 100 + page))
                )
            }

            // Le dernier passage franchit les quatre vingt quinze pour cent, ce
            // qui declenche le marquage automatique et le compteur de non lus.
            try await progression.enregistrer(
                PositionDeLecture(chapitreId: chapitre, pageIndex: 99)
            )

            try historique.consigner(
                chapitre: chapitre,
                pageAtteinte: 99,
                le: date.addingTimeInterval(Double(rang * 100 + 99))
            )
        }
    }

    /// Base peuplee, avec ses trois chapitres de cent pages.
    static func basePeuplee() throws -> (BaseDeDonnees, [UUID]) {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(
            dans: base,
            nombreDeChapitres: 3,
            pagesParChapitre: 100
        )

        return (base, jeu.chapitres.map(\.id))
    }

    @Test("Une session incognito ne change pas un octet de la base")
    func laSessionIncognitoNEcritRien() async throws {
        let (base, chapitres) = try Self.basePeuplee()
        let registre = RegistreDIncognito()
        registre.demarrer(le: Date(timeIntervalSince1970: 1_700_000_000))

        let avant = try Self.empreinte(de: base)

        try await Self.lireTroisChapitres(
            progression: MagasinDeProgression(base: base, incognito: registre),
            historique: MagasinDHistorique(base: base, incognito: registre),
            chapitres: chapitres
        )

        let apres = try Self.empreinte(de: base)

        #expect(apres == avant, "Une session incognito a laisse une trace en base")
    }

    @Test("Temoin : la meme session hors incognito change bien la base")
    func laMemeSessionHorsIncognitoEcrit() async throws {
        let (base, chapitres) = try Self.basePeuplee()
        let registre = RegistreDIncognito()

        let avant = try Self.empreinte(de: base)

        try await Self.lireTroisChapitres(
            progression: MagasinDeProgression(base: base, incognito: registre),
            historique: MagasinDHistorique(base: base, incognito: registre),
            chapitres: chapitres
        )

        let apres = try Self.empreinte(de: base)

        #expect(apres != avant, "Le test principal ne prouverait rien si celui ci passait")
    }

    @Test("Aucune entree d historique n apparait pendant une session incognito")
    func aucuneEntreeDHistorique() async throws {
        let (base, chapitres) = try Self.basePeuplee()
        let registre = RegistreDIncognito()
        registre.demarrer(le: Date(timeIntervalSince1970: 1_700_000_000))

        let historique = MagasinDHistorique(base: base, incognito: registre)

        try await Self.lireTroisChapitres(
            progression: MagasinDeProgression(base: base, incognito: registre),
            historique: historique,
            chapitres: chapitres
        )

        #expect(try historique.entrees().isEmpty)
    }

    @Test("La progression et le marquage automatique restent au point de depart")
    func laProgressionNeBougePas() async throws {
        let (base, chapitres) = try Self.basePeuplee()
        let registre = RegistreDIncognito()
        registre.demarrer(le: Date(timeIntervalSince1970: 1_700_000_000))

        let progression = MagasinDeProgression(base: base, incognito: registre)

        try await Self.lireTroisChapitres(
            progression: progression,
            historique: MagasinDHistorique(base: base, incognito: registre),
            chapitres: chapitres
        )

        for chapitre in chapitres {
            let relu = try await base.ecrivain.read { connexion in
                try Chapitre.fetchOne(connexion, key: chapitre)
            }

            #expect(relu?.pageAtteinte == 0)
            #expect(relu?.estLu == false)
            #expect(relu?.dateLecture == nil)
            #expect(try progression.position(duChapitre: chapitre).pageIndex == 0)
        }
    }

    @Test("Le rang de la serie dans la grille ne bouge pas non plus")
    func leRangDeLaSerieNeBougePas() throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(
            dans: base,
            nombreDeChapitres: 1,
            pagesParChapitre: 100
        )
        let registre = RegistreDIncognito()
        registre.demarrer(le: Date(timeIntervalSince1970: 1_700_000_000))

        // La date est passee explicitement pour viser la surcharge synchrone du
        // magasin, et non celle du protocole `EnregistreurDePosition`.
        try MagasinDeProgression(base: base, incognito: registre).enregistrer(
            PositionDeLecture(chapitreId: jeu.chapitres[0].id, pageIndex: 40),
            le: Date(timeIntervalSince1970: 1_700_000_100)
        )

        let date = try base.ecrivain.read { connexion in
            try Date.fetchOne(
                connexion,
                sql: "SELECT dateDerniereLecture FROM manga WHERE id = ?",
                arguments: [jeu.manga.id]
            )
        }

        #expect(date == nil, "La grille trie par derniere lecture, cette date est une trace")
        #expect(try JeuDeDonneesDeTest.chapitresNonLus(de: jeu.manga.id, dans: base) == 1)
    }

    @Test("Les ecritures reprennent des que la session est arretee")
    func lesEcrituresReprennentApresLaSession() throws {
        let (base, chapitres) = try Self.basePeuplee()
        let registre = RegistreDIncognito()
        registre.demarrer(le: Date(timeIntervalSince1970: 1_700_000_000))

        let progression = MagasinDeProgression(base: base, incognito: registre)
        let premier = try #require(chapitres.first)
        let position = PositionDeLecture(chapitreId: premier, pageIndex: 30)
        let date = Date(timeIntervalSince1970: 1_700_000_100)

        try progression.enregistrer(position, le: date)
        #expect(try progression.position(duChapitre: premier).pageIndex == 0)

        registre.arreter()

        try progression.enregistrer(position, le: date)
        #expect(try progression.position(duChapitre: premier).pageIndex == 30)
    }

    @Test("Effacer l historique reste possible pendant une session incognito")
    func lEffacementResteOffert() throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(
            dans: base,
            nombreDeChapitres: 1,
            pagesParChapitre: 10
        )
        let registre = RegistreDIncognito()

        // Une lecture ordinaire, avant que le mode incognito ne s allume.
        let historique = MagasinDHistorique(base: base, incognito: registre)
        try historique.consigner(chapitre: jeu.chapitres[0].id, pageAtteinte: 4)
        #expect(try historique.entrees().count == 1)

        registre.demarrer(le: Date(timeIntervalSince1970: 1_700_000_000))
        try historique.effacer()

        // La commande va dans le sens du mode incognito, elle reste offerte.
        #expect(try historique.entrees().isEmpty)
    }
}
