import Core
import Foundation
import GRDB
import Testing
@testable import Storage

/// Verifie que le decalage de couverture du mode double page est une valeur
/// reglee et persistee, et non une valeur recomposee a chaque ouverture.
///
/// Le test central est `leDecalageSurvitAUneReouverture` : il ferme la base, la
/// rouvre depuis le disque et relit la valeur. Une implementation qui garderait
/// le reglage en memoire, ou qui le deduirait de la forme de la premiere page,
/// echoue la.
struct DecalageDeCouverturePersisteTests {
    @Test("La migration installe le reglage global sur couverture seule")
    func reglageInstalleParLaMigration() throws {
        let base = try BaseDeDonnees.enMemoire()

        let lignes = try base.ecrivain.read { connexion in
            try Int.fetchOne(connexion, sql: "SELECT COUNT(*) FROM reglageDeDoublePage")
        }

        #expect(lignes == 1, "Le reglage global doit exister des la premiere ouverture")

        let magasin = MagasinDeDoublePage(base: base)
        #expect(try magasin.decalageGlobal() == .couvertureSeule)
    }

    @Test("La table du reglage refuse une seconde ligne")
    func uneSeuleLigneDeReglage() throws {
        let base = try BaseDeDonnees.enMemoire()

        #expect(throws: DatabaseError.self) {
            try base.ecrivain.write { connexion in
                try connexion.execute(
                    sql: "INSERT INTO reglageDeDoublePage (id, decalageGlobal) VALUES (2, 0)"
                )
            }
        }
    }

    @Test("La base refuse un decalage qui ne compose aucune paire connue")
    func decalageHorsDesDeuxFormes() throws {
        let base = try BaseDeDonnees.enMemoire()

        #expect(throws: DatabaseError.self) {
            try base.ecrivain.write { connexion in
                try connexion.execute(sql: "UPDATE reglageDeDoublePage SET decalageGlobal = 7")
            }
        }
    }

    @Test("Le decalage global se pose et se relit pour les deux valeurs", arguments: DecalageDeCouverture.allCases)
    func decalageGlobalPourChaqueValeur(decalage: DecalageDeCouverture) throws {
        let base = try BaseDeDonnees.enMemoire()
        let magasin = MagasinDeDoublePage(base: base)

        try magasin.definirLeDecalageGlobal(decalage)

        #expect(try magasin.decalageGlobal() == decalage)
        #expect(try magasin.reglageGlobal().decalageGlobal == decalage)
    }

    @Test("Le decalage survit a une fermeture et a une reouverture de la base")
    func leDecalageSurvitAUneReouverture() throws {
        let dossier = FileManager.default.temporaryDirectory
            .appendingPathComponent("decalage-de-couverture-\(UUID().uuidString)", isDirectory: true)
        let fichier = dossier.appendingPathComponent("bibliotheque.sqlite")

        defer { try? FileManager.default.removeItem(at: dossier) }

        for decalage in DecalageDeCouverture.allCases {
            do {
                let base = try BaseDeDonnees.surDisque(a: fichier)
                try MagasinDeDoublePage(base: base).definirLeDecalageGlobal(decalage)
                try base.ecrivain.close()
            }

            let relue = try BaseDeDonnees.surDisque(a: fichier)
            let relu = try MagasinDeDoublePage(base: relue).decalageGlobal()
            try relue.ecrivain.close()

            #expect(relu == decalage, "Le decalage \(decalage.rawValue) n a pas survecu a la reouverture")
        }
    }

    @Test("La surcharge d une serie survit a une reouverture et prime sur le global")
    func laSurchargeSurvitEtPrime() throws {
        let dossier = FileManager.default.temporaryDirectory
            .appendingPathComponent("decalage-de-serie-\(UUID().uuidString)", isDirectory: true)
        let fichier = dossier.appendingPathComponent("bibliotheque.sqlite")

        defer { try? FileManager.default.removeItem(at: dossier) }

        let serie: UUID

        do {
            let base = try BaseDeDonnees.surDisque(a: fichier)
            let jeu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 1)
            serie = jeu.manga.id

            let magasin = MagasinDeDoublePage(base: base)
            try magasin.definirLeDecalageGlobal(.couvertureSeule)
            try magasin.definirLaSurcharge(.aucun, pourSerie: serie)
            try base.ecrivain.close()
        }

        let relue = try BaseDeDonnees.surDisque(a: fichier)
        let magasin = MagasinDeDoublePage(base: relue)

        #expect(try magasin.surcharge(pourSerie: serie) == .aucun)
        #expect(try magasin.decalage(pourSerie: serie) == .aucun)
        #expect(try magasin.decalageGlobal() == .couvertureSeule)

        try relue.ecrivain.close()
    }

    @Test("Sans surcharge, la serie suit le reglage global, pour les deux valeurs")
    func sansSurchargeLeGlobalDecide() throws {
        let base = try BaseDeDonnees.enMemoire()
        let magasin = MagasinDeDoublePage(base: base)
        let jeu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 1)

        #expect(try magasin.surcharge(pourSerie: jeu.manga.id) == nil)

        for decalage in DecalageDeCouverture.allCases {
            try magasin.definirLeDecalageGlobal(decalage)

            #expect(try magasin.decalage(pourSerie: jeu.manga.id) == decalage)
        }
    }

    @Test("Retirer la surcharge rend la serie au reglage global")
    func retraitDeLaSurcharge() throws {
        let base = try BaseDeDonnees.enMemoire()
        let magasin = MagasinDeDoublePage(base: base)
        let jeu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 1)

        try magasin.definirLeDecalageGlobal(.couvertureSeule)
        try magasin.definirLaSurcharge(.aucun, pourSerie: jeu.manga.id)
        #expect(try magasin.decalage(pourSerie: jeu.manga.id) == .aucun)

        try magasin.definirLaSurcharge(nil, pourSerie: jeu.manga.id)

        #expect(try magasin.surcharge(pourSerie: jeu.manga.id) == nil)
        #expect(try magasin.decalage(pourSerie: jeu.manga.id) == .couvertureSeule)
    }

    @Test("Une serie inconnue produit une erreur nommee, jamais un decalage invente")
    func serieInconnue() throws {
        let base = try BaseDeDonnees.enMemoire()
        let magasin = MagasinDeDoublePage(base: base)
        let inconnue = UUID()

        #expect(throws: ErreurDeDoublePage.serieInconnue(identifiant: inconnue)) {
            try magasin.decalage(pourSerie: inconnue)
        }

        #expect(throws: ErreurDeDoublePage.serieInconnue(identifiant: inconnue)) {
            try magasin.definirLaSurcharge(.aucun, pourSerie: inconnue)
        }
    }

    @Test("Le reglage global efface se reinstalle a sa valeur par defaut")
    func reglageEfface() throws {
        let base = try BaseDeDonnees.enMemoire()
        let magasin = MagasinDeDoublePage(base: base)

        try magasin.definirLeDecalageGlobal(.aucun)
        try base.ecrivain.write { connexion in
            try connexion.execute(sql: "DELETE FROM reglageDeDoublePage")
        }

        #expect(try magasin.decalageGlobal() == DecalageDeCouverture.parDefaut)

        let lignes = try base.ecrivain.read { connexion in
            try Int.fetchOne(connexion, sql: "SELECT COUNT(*) FROM reglageDeDoublePage")
        }

        #expect(lignes == 1, "La valeur retournee doit etre reellement persistee")
    }

    @Test("La surcharge posee sur la serie se relit par l entite elle meme")
    func surchargeLueParLEntite() throws {
        let base = try BaseDeDonnees.enMemoire()
        let magasin = MagasinDeDoublePage(base: base)
        let jeu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 1)

        try magasin.definirLaSurcharge(.aucun, pourSerie: jeu.manga.id)

        let relue = try base.ecrivain.read { connexion in
            try Manga.fetchOne(connexion, key: jeu.manga.id)
        }

        #expect(relue?.decalageDeCouvertureForce == .aucun)
        #expect(try magasin.reglageGlobal().decalage(surchargeDeSerie: relue?.decalageDeCouvertureForce) == .aucun)
    }
}
