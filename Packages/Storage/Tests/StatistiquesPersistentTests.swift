import Core
import Foundation
import GRDB
import Testing
@testable import Storage

//
// Premier critere de F059 : les statistiques ne comptabilisent pas les sessions
// incognito.
//
// La verification suit la meme methode que `IncognitoNEcritRienTests` : une
// session de lecture complete est jouee deux fois, une fois en incognito et une
// fois sans, et les deux tables de F059 sont comparees avant et apres. Le test
// temoin existe pour la meme raison qu ailleurs, sans lui un comptage casse qui
// n ecrirait plus rien passerait le premier test.
//
// Le reste de la suite couvre le comptage lui meme : ce qu une page tournee
// ajoute, ce qu un chapitre termine ajoute, et ce qu un retour en arriere
// n ajoute pas.
//

struct StatistiquesPersistentTests {
    /// Instant de reference, midi, pour que la journee civile ne depende pas du
    /// fuseau de la machine.
    private var reference: Date {
        Date(timeIntervalSince1970: 1_700_000_000)
    }

    /// Base peuplee de trois chapitres de cent pages.
    private func basePeuplee() throws -> (BaseDeDonnees, [UUID]) {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(
            dans: base,
            nombreDeChapitres: 3,
            pagesParChapitre: 100
        )

        return (base, jeu.chapitres.map(\.id))
    }

    /// Contenu des deux tables de F059, tel quel.
    private func empreinteDesStatistiques(de base: BaseDeDonnees) throws -> [String] {
        try base.ecrivain.read { connexion in
            let journees = try Row.fetchAll(
                connexion,
                sql: "SELECT * FROM \(JourneeDeLecturePersistee.databaseTableName) ORDER BY jour"
            )
            let objectif = try Row.fetchAll(
                connexion,
                sql: "SELECT * FROM \(ObjectifPersiste.databaseTableName) ORDER BY id"
            )

            return (journees + objectif).map(String.init(describing:))
        }
    }

    /// Une session de lecture ordinaire, telle que le moteur la produit.
    private func lireTroisChapitres(
        progression: MagasinDeProgression,
        chapitres: [UUID]
    ) throws {
        for (rang, chapitre) in chapitres.enumerated() {
            for page in stride(from: 0, to: 100, by: 20) {
                try progression.enregistrer(
                    PositionDeLecture(chapitreId: chapitre, pageIndex: page),
                    le: reference.addingTimeInterval(Double(rang * 100 + page))
                )
            }

            try progression.enregistrer(
                PositionDeLecture(chapitreId: chapitre, pageIndex: 99),
                le: reference.addingTimeInterval(Double(rang * 100 + 99))
            )
        }
    }

    // MARK: Le schema

    @Test("La migration installe les deux tables de F059")
    func lesTablesExistent() throws {
        let base = try BaseDeDonnees.enMemoire()

        try base.ecrivain.read { connexion in
            #expect(try connexion.tableExists(JourneeDeLecturePersistee.databaseTableName))
            #expect(try connexion.tableExists(ObjectifPersiste.databaseTableName))

            let journee = try Set(
                connexion.columns(in: JourneeDeLecturePersistee.databaseTableName).map(\.name)
            )
            #expect(journee == ["jour", "chapitresLus", "pagesLues"])

            let objectif = try Set(
                connexion.columns(in: ObjectifPersiste.databaseTableName).map(\.name)
            )
            #expect(
                objectif == [
                    "id", "chapitresParJour", "rappelActif", "heureDeRappel", "minuteDeRappel",
                ]
            )
        }
    }

    @Test("Une installation neuve est livree sans objectif et sans rappel")
    func valeursLivrees() throws {
        let base = try BaseDeDonnees.enMemoire()
        let magasin = MagasinDeStatistiques(base: base)

        #expect(try magasin.objectif() == .desactive)
        #expect(try magasin.rappel() == .eteint)
        #expect(try magasin.journees().isEmpty)
    }

    // MARK: Le premier critere

    @Test("Une session incognito ne compte aucune statistique")
    func laSessionIncognitoNeComptePas() throws {
        let (base, chapitres) = try basePeuplee()
        let registre = RegistreDIncognito()
        registre.demarrer(le: reference)

        let avant = try empreinteDesStatistiques(de: base)

        try lireTroisChapitres(
            progression: MagasinDeProgression(base: base, incognito: registre),
            chapitres: chapitres
        )

        #expect(try empreinteDesStatistiques(de: base) == avant)
        #expect(try MagasinDeStatistiques(base: base).journees().isEmpty)
    }

    @Test("Temoin : la meme session hors incognito compte bien")
    func laMemeSessionHorsIncognitoCompte() throws {
        let (base, chapitres) = try basePeuplee()

        let avant = try empreinteDesStatistiques(de: base)

        try lireTroisChapitres(
            progression: MagasinDeProgression(base: base),
            chapitres: chapitres
        )

        #expect(try empreinteDesStatistiques(de: base) != avant)

        let journees = try MagasinDeStatistiques(base: base).journees()
        #expect(journees.count == 1)
        #expect(journees.first?.chapitresLus == 3)
    }

    @Test("L ecriture directe du magasin est gardee elle aussi")
    func lEcritureDirecteEstGardee() throws {
        let base = try BaseDeDonnees.enMemoire()
        let registre = RegistreDIncognito()
        registre.demarrer(le: reference)

        let magasin = MagasinDeStatistiques(base: base, incognito: registre)
        try magasin.consigner(chapitresLus: 2, pagesLues: 40, le: reference)

        #expect(try magasin.journees().isEmpty)
    }

    @Test("Le comptage reprend des que la session est arretee")
    func leComptageReprend() throws {
        let base = try BaseDeDonnees.enMemoire()
        let registre = RegistreDIncognito()
        registre.demarrer(le: reference)

        let magasin = MagasinDeStatistiques(base: base, incognito: registre)
        try magasin.consigner(chapitresLus: 1, le: reference)
        #expect(try magasin.journees().isEmpty)

        registre.arreter()
        try magasin.consigner(chapitresLus: 1, le: reference)

        #expect(try magasin.journees().first?.chapitresLus == 1)
    }

    @Test("Une session incognito n efface pas ce qui a ete compte avant elle")
    func lHistoriqueDesComptagesSurvit() throws {
        let base = try BaseDeDonnees.enMemoire()
        let registre = RegistreDIncognito()
        let magasin = MagasinDeStatistiques(base: base, incognito: registre)

        try magasin.consigner(chapitresLus: 4, pagesLues: 80, le: reference)
        registre.demarrer(le: reference)

        // L ecran reste consultable pendant la session, il n avance plus.
        #expect(try magasin.journees().first?.chapitresLus == 4)
        #expect(try magasin.statistiques(le: reference).totalDeChapitres == 4)
    }

    // MARK: Le comptage

    @Test("Un chapitre termine compte pour un, une seule fois")
    func chapitreTermineUneSeuleFois() throws {
        let (base, chapitres) = try basePeuplee()
        let progression = MagasinDeProgression(base: base)
        let premier = try #require(chapitres.first)

        try progression.enregistrer(PositionDeLecture(chapitreId: premier, pageIndex: 99), le: reference)
        try progression.enregistrer(PositionDeLecture(chapitreId: premier, pageIndex: 99), le: reference)

        #expect(try MagasinDeStatistiques(base: base).journees().first?.chapitresLus == 1)
    }

    @Test("Seules les pages franchies vers l avant sont comptees")
    func pagesFranchiesVersLAvant() throws {
        let (base, chapitres) = try basePeuplee()
        let progression = MagasinDeProgression(base: base)
        let premier = try #require(chapitres.first)
        let magasin = MagasinDeStatistiques(base: base)

        try progression.enregistrer(PositionDeLecture(chapitreId: premier, pageIndex: 30), le: reference)
        #expect(try magasin.journees().first?.pagesLues == 30)

        // Retour en arriere : rien ne s ajoute, rien ne se retire.
        try progression.enregistrer(PositionDeLecture(chapitreId: premier, pageIndex: 10), le: reference)
        #expect(try magasin.journees().first?.pagesLues == 30)

        // Puis on repasse sur les memes pages, elles ne comptent pas deux fois.
        try progression.enregistrer(PositionDeLecture(chapitreId: premier, pageIndex: 30), le: reference)
        #expect(try magasin.journees().first?.pagesLues == 50)
    }

    @Test("Deux jours de lecture donnent deux lignes")
    func deuxJoursDeuxLignes() throws {
        let base = try BaseDeDonnees.enMemoire()
        let magasin = MagasinDeStatistiques(base: base)
        let calendrier = Calendar(identifier: .gregorian)
        let lendemain = try #require(calendrier.date(byAdding: .day, value: 1, to: reference))

        try magasin.consigner(chapitresLus: 1, pagesLues: 20, le: reference, calendrier: calendrier)
        try magasin.consigner(chapitresLus: 2, pagesLues: 40, le: reference, calendrier: calendrier)
        try magasin.consigner(chapitresLus: 1, pagesLues: 10, le: lendemain, calendrier: calendrier)

        let journees = try magasin.journees()

        #expect(journees.count == 2)
        #expect(journees.first?.chapitresLus == 3)
        #expect(journees.first?.pagesLues == 60)
        #expect(journees.last?.chapitresLus == 1)
    }

    @Test("Un passage qui n a rien produit n ecrit aucune ligne")
    func passageSansEffet() throws {
        let base = try BaseDeDonnees.enMemoire()
        let magasin = MagasinDeStatistiques(base: base)

        try magasin.consigner(chapitresLus: 0, pagesLues: 0, le: reference)

        #expect(try magasin.journees().isEmpty)
    }

    // MARK: L objectif

    @Test("Les vingt objectifs de la plage survivent a un aller retour en base")
    func lObjectifPersiste() throws {
        let base = try BaseDeDonnees.enMemoire()
        let magasin = MagasinDeStatistiques(base: base)

        for vise in ObjectifQuotidien.minimum...ObjectifQuotidien.maximum {
            try magasin.definirLObjectif(ObjectifQuotidien(chapitresParJour: vise))
            #expect(try magasin.objectif().chapitresParJour == vise)
        }

        try magasin.definirLObjectif(.desactive)
        #expect(try magasin.objectif().estActif == false)
    }

    @Test("Le rappel survit a un aller retour en base")
    func leRappelPersiste() throws {
        let base = try BaseDeDonnees.enMemoire()
        let magasin = MagasinDeStatistiques(base: base)

        try magasin.definirLeRappel(RappelDObjectif(actif: true, heure: 7, minute: 30))
        let relu = try magasin.rappel()

        #expect(relu.actif)
        #expect(relu.heure == 7)
        #expect(relu.minute == 30)
    }

    @Test("L objectif et les journees sont lus ensemble par l instantane")
    func lInstantaneEstCoherent() throws {
        let base = try BaseDeDonnees.enMemoire()
        let magasin = MagasinDeStatistiques(base: base)

        try magasin.definirLObjectif(ObjectifQuotidien(chapitresParJour: 2))
        try magasin.consigner(chapitresLus: 2, pagesLues: 30, le: reference)

        let instantane = try magasin.statistiques(le: reference)

        #expect(instantane.objectif.chapitresParJour == 2)
        #expect(instantane.journeeDuJour.chapitresLus == 2)
        #expect(instantane.serieDeJours == 1)
        #expect(instantane.estVide == false)
    }

    @Test("Le prochain rappel se tait pendant une session incognito")
    func leProchainRappelSeTait() throws {
        let base = try BaseDeDonnees.enMemoire()
        let registre = RegistreDIncognito()
        let magasin = MagasinDeStatistiques(base: base, incognito: registre)

        try magasin.definirLObjectif(ObjectifQuotidien(chapitresParJour: 3))
        try magasin.definirLeRappel(RappelDObjectif(actif: true))

        #expect(try magasin.prochainRappel(le: reference) != nil)

        registre.demarrer(le: reference)
        #expect(try magasin.prochainRappel(le: reference) == nil)
    }
}
