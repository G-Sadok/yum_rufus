import Core
import Foundation
import GRDB
import Testing
@testable import Storage

//
// Couvre la gestion et l application des prereglages de lecture, section 7 du
// tableau de la section 5.5 de DESIGN-SPEC.md.
//
// Le second critere de la fonctionnalite dit que l application est immediate.
// Le test qui le porte compte les transactions : un prereglage s applique en
// une seule ecriture, donc en une seule notification aux observateurs et une
// seule repeinture. Compter les valeurs finales ne dirait rien de cela, une
// application ligne par ligne rendrait le meme resultat en cinq secousses.
//

struct PrereglagesPersistentTests {
    // MARK: Materiel

    private func base() throws -> BaseDeDonnees {
        try BaseDeDonnees.enMemoire()
    }

    private func contenuDeTest() -> ContenuDePrereglage {
        var filtres = ReglagesDeFiltres.parDefaut
        filtres.regler(.luminosite, a: 40)
        filtres.regler(.chaleur, a: 25)
        filtres.basculer(.reductionDuBruit, true)

        return ContenuDePrereglage(
            sens: .gaucheDroite,
            miseEnPage: .doublePage,
            fond: .sepia,
            rognerLesBords: true,
            filtres: filtres
        )
    }

    // MARK: Gestion de la liste

    @Test("Un prereglage enregistre se relit avec tout ce qu il capture")
    func enregistrementEtRelecture() throws {
        let magasin = try MagasinDePrereglages(base: base())
        let enregistre = try magasin.enregistrer(nom: "Manga papier", contenu: contenuDeTest())

        let relu = try magasin.contenu(de: enregistre.id)

        #expect(relu == contenuDeTest())
        #expect(try magasin.nombre() == 1)
        #expect(try magasin.prereglages().map(\.nom) == ["Manga papier"])
    }

    @Test("La liste est vide sur une installation neuve")
    func listeVideALInstallation() throws {
        let magasin = try MagasinDePrereglages(base: base())

        #expect(try magasin.prereglages().isEmpty)
        #expect(try magasin.nombre() == 0)
    }

    @Test("La liste rend les prereglages dans l ordre naturel des noms")
    func ordreDeLaListe() throws {
        let magasin = try MagasinDePrereglages(base: base())

        for nom in ["Webtoon 10", "Webtoon 2", "Manga"] {
            try magasin.enregistrer(nom: nom, contenu: .parDefaut)
        }

        #expect(try magasin.prereglages().map(\.nom) == ["Manga", "Webtoon 2", "Webtoon 10"])
    }

    @Test("Un nom deja pris est refuse, aux accents et a la casse pres")
    func nomDejaPris() throws {
        let magasin = try MagasinDePrereglages(base: base())
        try magasin.enregistrer(nom: "Lecture nocturne", contenu: .parDefaut)

        #expect(throws: ErreurDePrereglage.nomDejaPris(nom: "LECTURE NOCTURNE")) {
            try magasin.enregistrer(nom: "LECTURE NOCTURNE", contenu: .parDefaut)
        }

        #expect(try magasin.nombre() == 1)
    }

    @Test("Un nom vide est refuse")
    func nomVide() throws {
        let magasin = try MagasinDePrereglages(base: base())

        #expect(throws: ErreurDePrereglage.nomVide) {
            try magasin.enregistrer(nom: "   ", contenu: .parDefaut)
        }
    }

    @Test("Un renommage garde ce que le prereglage capture")
    func renommage() throws {
        let magasin = try MagasinDePrereglages(base: base())
        let enregistre = try magasin.enregistrer(nom: "Ancien", contenu: contenuDeTest())

        let renomme = try magasin.renommer(enregistre.id, en: "  Nouveau  ")

        #expect(renomme.nom == "Nouveau")
        #expect(try magasin.contenu(de: enregistre.id) == contenuDeTest())
    }

    @Test("Un renommage vers un nom deja pris est refuse")
    func renommageEnCollision() throws {
        let magasin = try MagasinDePrereglages(base: base())
        let premier = try magasin.enregistrer(nom: "Webtoon", contenu: .parDefaut)
        try magasin.enregistrer(nom: "Manga", contenu: .parDefaut)

        #expect(throws: ErreurDePrereglage.nomDejaPris(nom: "Manga")) {
            try magasin.renommer(premier.id, en: "Manga")
        }

        #expect(try magasin.prereglages().map(\.nom) == ["Manga", "Webtoon"])
    }

    @Test("Un prereglage garde son nom quand on remplace ce qu il capture")
    func remplacementDuContenu() throws {
        let magasin = try MagasinDePrereglages(base: base())
        let enregistre = try magasin.enregistrer(nom: "Webtoon", contenu: .parDefaut)

        try magasin.remplacer(enregistre.id, par: contenuDeTest())

        #expect(try magasin.contenu(de: enregistre.id) == contenuDeTest())
        #expect(try magasin.prereglages().map(\.nom) == ["Webtoon"])
    }

    @Test("Une suppression retire le prereglage sans toucher aux reglages en place")
    func suppression() throws {
        let base = try base()
        let magasin = MagasinDePrereglages(base: base)
        let reglages = MagasinDeReglages(base: base)

        let enregistre = try magasin.enregistrer(nom: "Webtoon", contenu: contenuDeTest())
        try magasin.appliquer(enregistre.id)
        try magasin.supprimer(enregistre.id)

        #expect(try magasin.nombre() == 0)
        #expect(try reglages.reglages().choix(.fondDuLecteur, comme: ChoixDeFondDuLecteur.self) == .sepia)
    }

    @Test("Renommer, supprimer ou appliquer un prereglage disparu est refuse")
    func prereglageInconnu() throws {
        let magasin = try MagasinDePrereglages(base: base())
        let fantome = UUID()
        let attendue = ErreurDePrereglage.prereglageInconnu(identifiant: fantome)

        #expect(throws: attendue) { try magasin.renommer(fantome, en: "Webtoon") }
        #expect(throws: attendue) { try magasin.supprimer(fantome) }
        #expect(throws: attendue) { try magasin.appliquer(fantome) }
        #expect(throws: attendue) { try magasin.contenu(de: fantome) }
    }

    // MARK: Capture de l etat courant

    @Test("La capture prend les reglages tels qu ils sont ecrits en base")
    func captureDeLEtatCourant() throws {
        let base = try base()
        let magasin = MagasinDePrereglages(base: base)
        let reglages = MagasinDeReglages(base: base)

        try reglages.definir(.choix(SensDeLecture.gaucheDroite.rawValue), pour: .sensDeLecture)
        try reglages.definir(.choix(ChoixDeFondDuLecteur.blanc.rawValue), pour: .fondDuLecteur)
        try reglages.definir(.booleen(true), pour: .rognerLesBords)

        var filtres = ReglagesDeFiltres.parDefaut
        filtres.regler(.gamma, a: 70)
        filtres.basculer(.colorisationIA, true)

        let capture = try magasin.capturer(nom: "Actuel", filtres: filtres)
        let contenu = try magasin.contenu(de: capture.id)

        #expect(contenu.sens == .gaucheDroite)
        #expect(contenu.fond == .blanc)
        #expect(contenu.rognerLesBords)
        #expect(contenu.filtres.valeur(.gamma) == 70)
        #expect(contenu.filtres.estActif(.colorisationIA))
    }

    // MARK: Application

    @Test("L application repose tous les reglages captures")
    func applicationDesReglages() throws {
        let base = try base()
        let magasin = MagasinDePrereglages(base: base)
        let reglages = MagasinDeReglages(base: base)

        let enregistre = try magasin.enregistrer(nom: "Manga papier", contenu: contenuDeTest())
        let applique = try magasin.appliquer(enregistre.id)

        let apres = try reglages.reglages()

        #expect(applique == contenuDeTest())
        #expect(apres[.sensDeLecture] == .choix(SensDeLecture.gaucheDroite.rawValue))
        #expect(apres.choix(.miseEnPage, comme: MiseEnPage.self) == .doublePage)
        #expect(apres.choix(.fondDuLecteur, comme: ChoixDeFondDuLecteur.self) == .sepia)
        #expect(apres.booleen(.rognerLesBords))
        #expect(apres.curseur(.luminositeDuLecteur) == 40)
    }

    @Test("L application aligne le sens de lecture global de la table")
    func applicationDuSensGlobal() throws {
        let base = try base()
        let magasin = MagasinDePrereglages(base: base)
        let sens = MagasinDeSensDeLecture(base: base)

        let enregistre = try magasin.enregistrer(nom: "Manga papier", contenu: contenuDeTest())
        try magasin.appliquer(enregistre.id)

        #expect(try sens.sensGlobal() == .gaucheDroite)
    }

    @Test("Un prereglage en defilement continu pose le sens vertical dans la table")
    func applicationDuSensVertical() throws {
        let base = try base()
        let magasin = MagasinDePrereglages(base: base)
        let sens = MagasinDeSensDeLecture(base: base)

        // La ligne de reglage garde un sens horizontal, le menu ne propose que
        // ceux la. C est la mise en page qui impose le vertical au moteur.
        let contenu = ContenuDePrereglage(sens: .droiteGauche, miseEnPage: .continuVertical)
        let enregistre = try magasin.enregistrer(nom: "Webtoon", contenu: contenu)
        try magasin.appliquer(enregistre.id)

        #expect(try sens.sensGlobal() == .hautBas)
    }

    @Test("L application tient dans une seule transaction")
    func applicationImmediate() throws {
        let base = try base()
        let magasin = MagasinDePrereglages(base: base)
        let enregistre = try magasin.enregistrer(nom: "Manga papier", contenu: contenuDeTest())

        let compteur = CompteurDeTransactions()
        base.ecrivain.add(transactionObserver: compteur, extent: .observerLifetime)

        try magasin.appliquer(enregistre.id)

        // Cinq lignes de reglage et le sens global, une seule secousse. Une
        // ecriture par ligne ferait passer les observateurs par cinq etats
        // intermediaires, et le lecteur repeindrait la page a chaque fois.
        #expect(compteur.validations == 1)
    }

    @Test("L application ne touche a aucun reglage etranger a la lecture")
    func applicationSansDegats() throws {
        let base = try base()
        let magasin = MagasinDePrereglages(base: base)
        let reglages = MagasinDeReglages(base: base)

        try reglages.definir(.choix(ChoixDeTheme.paper.rawValue), pour: .theme)
        try reglages.definir(.compteur(3), pour: .pagesGardeesEnMemoire)

        let enregistre = try magasin.enregistrer(nom: "Manga papier", contenu: contenuDeTest())
        try magasin.appliquer(enregistre.id)

        let apres = try reglages.reglages()

        #expect(apres.choix(.theme, comme: ChoixDeTheme.self) == .paper)
        #expect(apres.compteur(.pagesGardeesEnMemoire) == 3)
    }

    @Test("Un prereglage dont la colonne est abimee ne s applique pas")
    func applicationDUnContenuAbime() throws {
        let base = try base()
        let magasin = MagasinDePrereglages(base: base)

        let abime = PrereglageLecture(nom: "Abime", donneesReglages: Data([0xAA, 0xBB]))
        try base.ecrivain.write { connexion in
            try abime.insert(connexion)
        }

        #expect(throws: ErreurDePrereglage.contenuIllisible) {
            try magasin.appliquer(abime.id)
        }
    }

    // MARK: Sauvegarde

    @Test("Les prereglages sont exportes dans la sauvegarde")
    func exportDansLaSauvegarde() throws {
        let magasin = try MagasinDePrereglages(base: base())
        try magasin.enregistrer(nom: "Manga papier", contenu: contenuDeTest())
        try magasin.enregistrer(nom: "Webtoon", contenu: .parDefaut)

        let sauvegarde = try magasin.sauvegarde()
        let relue = try SauvegardeDesPrereglages(donnees: sauvegarde.donnees())

        #expect(relue.prereglages.map(\.nom) == ["Manga papier", "Webtoon"])
        #expect(relue.prereglages.first?.contenu == contenuDeTest())
    }

    @Test("Une restauration en remplacement reconstruit la liste a l identique")
    func restaurationEnRemplacement() throws {
        let source = try MagasinDePrereglages(base: base())
        try source.enregistrer(nom: "Manga papier", contenu: contenuDeTest())
        try source.enregistrer(nom: "Webtoon", contenu: .parDefaut)
        let sauvegarde = try source.sauvegarde()

        let cible = try MagasinDePrereglages(base: base())
        try cible.enregistrer(nom: "A jeter", contenu: .parDefaut)
        try cible.restaurer(sauvegarde, enRemplacant: true)

        #expect(try cible.prereglages().map(\.nom) == ["Manga papier", "Webtoon"])

        let restaure = try #require(try cible.prereglages().first)

        #expect(try cible.contenu(de: restaure.id) == contenuDeTest())
    }

    @Test("Une restauration en fusion garde ce qui est deja en place")
    func restaurationEnFusion() throws {
        let source = try MagasinDePrereglages(base: base())
        try source.enregistrer(nom: "Manga papier", contenu: contenuDeTest())
        let sauvegarde = try source.sauvegarde()

        let cible = try MagasinDePrereglages(base: base())
        try cible.enregistrer(nom: "Deja la", contenu: .parDefaut)
        try cible.restaurer(sauvegarde, enRemplacant: false)

        #expect(try cible.prereglages().map(\.nom) == ["Deja la", "Manga papier"])
    }

    @Test("Une restauration deux fois de suite ne cree pas de double")
    func restaurationIdempotente() throws {
        let source = try MagasinDePrereglages(base: base())
        try source.enregistrer(nom: "Manga papier", contenu: contenuDeTest())
        let sauvegarde = try source.sauvegarde()

        let cible = try MagasinDePrereglages(base: base())
        try cible.restaurer(sauvegarde, enRemplacant: false)
        try cible.restaurer(sauvegarde, enRemplacant: false)

        #expect(try cible.nombre() == 1)
    }

    @Test("Une fusion refuse un nom deja porte par un autre prereglage")
    func fusionEnCollisionDeNom() throws {
        let source = try MagasinDePrereglages(base: base())
        try source.enregistrer(nom: "Webtoon", contenu: .parDefaut)
        let sauvegarde = try source.sauvegarde()

        let cible = try MagasinDePrereglages(base: base())
        try cible.enregistrer(nom: "webtoon", contenu: .parDefaut)

        #expect(throws: ErreurDePrereglage.nomDejaPris(nom: "Webtoon")) {
            try cible.restaurer(sauvegarde, enRemplacant: false)
        }

        #expect(try cible.prereglages().map(\.nom) == ["webtoon"])
    }
}

/// Compte les transactions validees sur la base.
///
/// Le compteur n est lu qu apres l ecriture, depuis le fil du test, et la file
/// de la base a deja rendu la main a ce moment la. Aucun acces concurrent n est
/// donc possible, ce que la classe ne peut pas prouver au compilateur.
private final class CompteurDeTransactions: TransactionObserver {
    private(set) var validations = 0

    func observes(eventsOfKind _: DatabaseEventKind) -> Bool {
        true
    }

    func databaseDidChange(with _: DatabaseEvent) {}

    func databaseDidCommit(_: Database) {
        validations += 1
    }

    func databaseDidRollback(_: Database) {}
}
