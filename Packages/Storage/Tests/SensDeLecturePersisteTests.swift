import Core
import Foundation
import GRDB
import Testing
@testable import Storage

/// Verifie que le sens de lecture est bien une valeur persistee et non une
/// valeur reconstruite a chaque ouverture.
///
/// Le test central est `leSensGlobalSurvitAUneReouverture` : il ferme la base,
/// la rouvre depuis le disque et relit la valeur. Une implementation qui
/// garderait le reglage en memoire, ou qui le recalculerait a partir de la
/// langue du systeme, echoue la.
struct SensDeLecturePersisteTests {
    @Test("La migration installe le reglage global au defaut du cahier")
    func reglageInstalleParLaMigration() throws {
        let base = try BaseDeDonnees.enMemoire()

        let lignes = try base.ecrivain.read { connexion in
            try Int.fetchOne(connexion, sql: "SELECT COUNT(*) FROM reglageDeSensDeLecture")
        }

        #expect(lignes == 1, "Le reglage global doit exister des la premiere ouverture")

        let magasin = MagasinDeSensDeLecture(base: base)
        #expect(try magasin.sensGlobal() == .droiteGauche)
    }

    @Test("La table du reglage refuse une seconde ligne")
    func uneSeuleLigneDeReglage() throws {
        let base = try BaseDeDonnees.enMemoire()

        #expect(throws: DatabaseError.self) {
            try base.ecrivain.write { connexion in
                try connexion.execute(
                    sql: "INSERT INTO reglageDeSensDeLecture (id, sensGlobal) VALUES (2, 'hautBas')"
                )
            }
        }
    }

    @Test("Le sens global se pose et se relit pour les trois valeurs", arguments: SensDeLecture.allCases)
    func sensGlobalPourChaqueValeur(sens: SensDeLecture) throws {
        let base = try BaseDeDonnees.enMemoire()
        let magasin = MagasinDeSensDeLecture(base: base)

        try magasin.definirLeSensGlobal(sens)

        #expect(try magasin.sensGlobal() == sens)
        #expect(try magasin.reglageGlobal().sensGlobal == sens)
    }

    @Test("Le sens global survit a une fermeture et a une reouverture de la base")
    func leSensGlobalSurvitAUneReouverture() throws {
        let dossier = FileManager.default.temporaryDirectory
            .appendingPathComponent("sens-de-lecture-\(UUID().uuidString)", isDirectory: true)
        let fichier = dossier.appendingPathComponent("bibliotheque.sqlite")

        defer { try? FileManager.default.removeItem(at: dossier) }

        for sens in SensDeLecture.allCases {
            do {
                let base = try BaseDeDonnees.surDisque(a: fichier)
                try MagasinDeSensDeLecture(base: base).definirLeSensGlobal(sens)
                try base.ecrivain.close()
            }

            let relue = try BaseDeDonnees.surDisque(a: fichier)
            let relu = try MagasinDeSensDeLecture(base: relue).sensGlobal()
            try relue.ecrivain.close()

            #expect(relu == sens, "Le sens \(sens.rawValue) n a pas survecu a la reouverture")
        }
    }

    @Test("La surcharge d une serie se pose et se relit pour les trois valeurs")
    func surchargeDeSeriePourChaqueValeur() throws {
        let base = try BaseDeDonnees.enMemoire()
        let magasin = MagasinDeSensDeLecture(base: base)
        let jeu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 1)

        try magasin.definirLeSensGlobal(.hautBas)

        for sens in SensDeLecture.allCases {
            try magasin.definirLaSurcharge(sens, pourSerie: jeu.manga.id)

            #expect(try magasin.surcharge(pourSerie: jeu.manga.id) == sens)
            #expect(
                try magasin.sens(pourSerie: jeu.manga.id) == sens,
                "La surcharge \(sens.rawValue) doit primer sur le reglage global"
            )
        }
    }

    @Test("Sans surcharge, la serie suit le reglage global, pour les trois valeurs")
    func sansSurchargeLeGlobalDecide() throws {
        let base = try BaseDeDonnees.enMemoire()
        let magasin = MagasinDeSensDeLecture(base: base)
        let jeu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 1)

        #expect(try magasin.surcharge(pourSerie: jeu.manga.id) == nil)

        for sens in SensDeLecture.allCases {
            try magasin.definirLeSensGlobal(sens)

            #expect(try magasin.sens(pourSerie: jeu.manga.id) == sens)
        }
    }

    @Test("Retirer la surcharge rend la serie au reglage global")
    func retraitDeLaSurcharge() throws {
        let base = try BaseDeDonnees.enMemoire()
        let magasin = MagasinDeSensDeLecture(base: base)
        let jeu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 1)

        try magasin.definirLeSensGlobal(.gaucheDroite)
        try magasin.definirLaSurcharge(.droiteGauche, pourSerie: jeu.manga.id)
        #expect(try magasin.sens(pourSerie: jeu.manga.id) == .droiteGauche)

        try magasin.definirLaSurcharge(nil, pourSerie: jeu.manga.id)

        #expect(try magasin.surcharge(pourSerie: jeu.manga.id) == nil)
        #expect(try magasin.sens(pourSerie: jeu.manga.id) == .gaucheDroite)
    }

    @Test("Une serie inconnue produit une erreur nommee, jamais un sens invente")
    func serieInconnue() throws {
        let base = try BaseDeDonnees.enMemoire()
        let magasin = MagasinDeSensDeLecture(base: base)
        let inconnue = UUID()

        #expect(throws: ErreurDeSensDeLecture.serieInconnue(identifiant: inconnue)) {
            try magasin.sens(pourSerie: inconnue)
        }

        #expect(throws: ErreurDeSensDeLecture.serieInconnue(identifiant: inconnue)) {
            try magasin.definirLaSurcharge(.hautBas, pourSerie: inconnue)
        }
    }

    @Test("Le reglage global efface se reinstalle a sa valeur par defaut")
    func reglageEfface() throws {
        let base = try BaseDeDonnees.enMemoire()
        let magasin = MagasinDeSensDeLecture(base: base)

        try magasin.definirLeSensGlobal(.hautBas)
        try base.ecrivain.write { connexion in
            try connexion.execute(sql: "DELETE FROM reglageDeSensDeLecture")
        }

        #expect(try magasin.sensGlobal() == SensDeLecture.parDefaut)

        let lignes = try base.ecrivain.read { connexion in
            try Int.fetchOne(connexion, sql: "SELECT COUNT(*) FROM reglageDeSensDeLecture")
        }

        #expect(lignes == 1, "La valeur retournee doit etre reellement persistee")
    }
}
