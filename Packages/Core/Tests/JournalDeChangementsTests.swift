import Foundation
import Testing
@testable import Core

//
// Couvre le journal de changements lui meme, celui sur lequel repose le
// troisieme critere : le mode hors ligne accumule les changements et les
// rejoue a la reconnexion.
//
// Accumuler ne veut pas dire empiler. Une lecture enregistre sa position toutes
// les deux secondes, et un journal qui empilerait tout ferait partir des
// centaines de lignes perimees a la reconnexion, pour un etat final identique.
// Le test du regroupement verifie donc les deux choses a la fois : le nombre de
// lignes gardees, et le fait que la ligne gardee soit bien la derniere.
//

@Suite("Journal de changements")
struct JournalDeChangementsTests {
    static let base = Date(timeIntervalSince1970: 1_700_000_000)

    static func changement(
        chapitre: UUID,
        page: Int,
        secondes: TimeInterval,
        appareil: String = "appareil-a"
    ) throws -> ChangementSynchronise {
        try ProgressionSynchronisee(
            chapitreId: chapitre,
            pageAtteinte: page,
            dateLecture: base.addingTimeInterval(secondes)
        ).changement(depuis: appareil)
    }

    @Test("Cent enregistrements du meme chapitre tiennent en une ligne")
    func regroupementParCle() throws {
        let chapitre = UUID()
        var journal = JournalDeChangements()

        for page in 0..<100 {
            try journal.consigner(Self.changement(chapitre: chapitre, page: page, secondes: Double(page) * 2))
        }

        #expect(journal.nombreEnAttente == 1)

        let garde = try #require(journal.changement(pour: CleDeChangement(
            entite: .progressionDeChapitre,
            identifiant: chapitre
        )))

        #expect(try ProgressionSynchronisee.lire(garde).pageAtteinte == 99)
    }

    @Test("Chaque chapitre garde sa propre ligne")
    func uneLigneParChapitre() throws {
        var journal = JournalDeChangements()
        let chapitres = (0..<5).map { _ in UUID() }

        for (rang, chapitre) in chapitres.enumerated() {
            try journal.consigner(Self.changement(chapitre: chapitre, page: rang, secondes: Double(rang)))
        }

        #expect(journal.nombreEnAttente == 5)
    }

    @Test("Une horloge qui recule ne fait pas reculer la page")
    func horlogeQuiRecule() throws {
        let chapitre = UUID()
        var journal = JournalDeChangements()

        try journal.consigner(Self.changement(chapitre: chapitre, page: 40, secondes: 100))
        try journal.consigner(Self.changement(chapitre: chapitre, page: 2, secondes: 10))

        let garde = try #require(journal.changements.first)

        #expect(journal.nombreEnAttente == 1)
        #expect(try ProgressionSynchronisee.lire(garde).pageAtteinte == 40)
    }

    @Test("L ordre d envoi ne depend pas de l ordre d insertion")
    func ordreStable() throws {
        let chapitres = (0..<4).map { _ in UUID() }
        let lignes = try chapitres.enumerated().map { rang, chapitre in
            try Self.changement(chapitre: chapitre, page: rang, secondes: Double(rang))
        }

        let unSens = JournalDeChangements(lignes).changements
        let autreSens = JournalDeChangements(lignes.reversed()).changements

        #expect(unSens == autreSens)
        #expect(unSens.map(\.horodatage) == unSens.map(\.horodatage).sorted())
    }

    @Test("Le retrait n emporte que ce qui est reellement parti")
    func retraitSelectif() throws {
        let chapitre = UUID()
        var journal = JournalDeChangements()

        let parti = try Self.changement(chapitre: chapitre, page: 10, secondes: 0)
        journal.consigner(parti)

        // Le lecteur continue pendant l envoi. La ligne en attente n est plus
        // celle qui est partie.
        let pendantLEnvoi = try Self.changement(chapitre: chapitre, page: 11, secondes: 2)
        journal.consigner(pendantLEnvoi)

        journal.retirer([parti])

        #expect(journal.nombreEnAttente == 1)
        #expect(journal.changements.first == pendantLEnvoi)
    }

    @Test("Le retrait de ce qui est parti vide le journal")
    func retraitComplet() throws {
        let chapitre = UUID()
        var journal = JournalDeChangements()
        let ligne = try Self.changement(chapitre: chapitre, page: 10, secondes: 0)

        journal.consigner(ligne)
        journal.retirer([ligne])

        #expect(journal.estVide)
    }

    @Test("Le journal survit a son encodage")
    func journalPersistable() throws {
        let chapitre = UUID()
        var journal = JournalDeChangements()
        try journal.consigner(Self.changement(chapitre: chapitre, page: 10, secondes: 0))

        let relu = try JSONDecoder().decode(
            JournalDeChangements.self,
            from: JSONEncoder().encode(journal)
        )

        #expect(relu == journal)
    }

    @Test("Une cle se relit depuis sa forme textuelle")
    func cleReversible() {
        let cle = CleDeChangement(entite: .serieDeBibliotheque, identifiant: UUID())

        #expect(CleDeChangement.lire(cle.texte) == cle)
        #expect(CleDeChangement.lire("entite-inconnue:1") == nil)
        #expect(CleDeChangement.lire("progressionDeChapitre") == nil)
    }
}
