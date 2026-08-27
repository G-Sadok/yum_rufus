import Core
import Foundation
import Testing
@testable import Sources

//
// Couvre le second critere de bout en bout : la suppression automatique
// respecte le reglage.
//
// La decision est deja prouvee dans CoreTests, sur la fonction pure. Ce qui est
// prouve ici est le tour complet : le disque est bien lu, le reglage bien
// applique au dossier reel, et la file bien avertie de ce qui vient de partir.
// Une regle juste appliquee au mauvais dossier resterait une perte de donnees.
//

/// Journal de test, qui repond ce que le test lui a dit de repondre.
///
/// Il est un acteur et non une structure : le nettoyage l interroge de facon
/// asynchrone, et la liste des chapitres oublies est ecrite pendant cet appel.
actor JournalDeStockageDeTest: JournalDuStockage {
    private let lus: [UUID: TelechargementLu]
    private(set) var oublies: [UUID] = []

    init(lus: [TelechargementLu]) {
        self.lus = Dictionary(uniqueKeysWithValues: lus.map { ($0.chapitreId, $0) })
    }

    func chapitresLus(parmi chapitres: [UUID]) async throws -> [TelechargementLu] {
        chapitres.compactMap { lus[$0] }
    }

    func oublierLesTelechargements(de chapitres: [UUID]) async throws {
        oublies.append(contentsOf: chapitres)
    }
}

struct NettoyageDesTelechargementsLusTests {
    private let maintenant = Date(timeIntervalSince1970: 1_700_000_000)

    private var jour: TimeInterval {
        24 * 60 * 60
    }

    /// Chapitre lu il y a le nombre de secondes demande.
    private func lecture(_ chapitre: UUID, ilYA secondes: TimeInterval = 0) -> TelechargementLu {
        TelechargementLu(
            chapitreId: chapitre,
            dateLecture: maintenant.addingTimeInterval(-secondes)
        )
    }

    /// Pose deux chapitres sur le disque, l un lu, l autre non.
    private func poser(
        dans dossier: borrowing DossierDeStockageDeTest,
        lu: UUID,
        nonLu: UUID
    ) throws {
        try dossier.ecrire(600, dans: "\(lu.uuidString)/page-0000", sous: dossier.telechargements)
        try dossier.ecrire(400, dans: "\(nonLu.uuidString)/page-0000", sous: dossier.telechargements)
    }

    @Test("Jamais ne touche pas au disque")
    func jamaisNeToucheRien() async throws {
        let dossier = try DossierDeStockageDeTest()
        let inspecteur = InspecteurDeStockageSurDisque(emplacements: dossier.emplacements)
        let lu = UUID()
        let nonLu = UUID()

        try poser(dans: dossier, lu: lu, nonLu: nonLu)

        let journal = JournalDeStockageDeTest(lus: [lecture(lu, ilYA: 365 * jour)])
        let nettoyage = NettoyageDesTelechargementsLus(inspecteur: inspecteur, journal: journal)

        let effaces = try await nettoyage.executer(reglage: .jamais, maintenant: maintenant)

        #expect(effaces.isEmpty)
        #expect(inspecteur.octets(de: .chapitresTelecharges) == 1000)
        #expect(await journal.oublies.isEmpty)
    }

    @Test("Immediatement efface le chapitre lu et laisse le chapitre non lu")
    func immediatementNEffaceQueCeQuiEstLu() async throws {
        let dossier = try DossierDeStockageDeTest()
        let inspecteur = InspecteurDeStockageSurDisque(emplacements: dossier.emplacements)
        let lu = UUID()
        let nonLu = UUID()

        try poser(dans: dossier, lu: lu, nonLu: nonLu)

        let journal = JournalDeStockageDeTest(lus: [lecture(lu)])
        let nettoyage = NettoyageDesTelechargementsLus(inspecteur: inspecteur, journal: journal)

        let effaces = try await nettoyage.executer(reglage: .immediatement, maintenant: maintenant)

        #expect(effaces == [lu])
        #expect(inspecteur.octets(de: .chapitresTelecharges) == 400)
        #expect(inspecteur.pesages(de: .chapitresTelecharges).map(\.nom) == [nonLu.uuidString])
    }

    @Test("Apres 7 jours attend le delai avant d effacer quoi que ce soit")
    func leDelaiEstRespecteSurLeDisque() async throws {
        let dossier = try DossierDeStockageDeTest()
        let inspecteur = InspecteurDeStockageSurDisque(emplacements: dossier.emplacements)
        let lu = UUID()
        let nonLu = UUID()

        try poser(dans: dossier, lu: lu, nonLu: nonLu)

        let journal = JournalDeStockageDeTest(lus: [lecture(lu, ilYA: 2 * jour)])
        let nettoyage = NettoyageDesTelechargementsLus(inspecteur: inspecteur, journal: journal)

        let tot = try await nettoyage.executer(reglage: .apres7Jours, maintenant: maintenant)

        #expect(tot.isEmpty)
        #expect(inspecteur.octets(de: .chapitresTelecharges) == 1000)

        let plusTard = try await nettoyage.executer(
            reglage: .apres7Jours,
            maintenant: maintenant.addingTimeInterval(8 * jour)
        )

        #expect(plusTard == [lu])
        #expect(inspecteur.octets(de: .chapitresTelecharges) == 400)
    }

    @Test("La file oublie exactement les chapitres qui viennent de partir")
    func laFileOublieCeQuiEstParti() async throws {
        let dossier = try DossierDeStockageDeTest()
        let inspecteur = InspecteurDeStockageSurDisque(emplacements: dossier.emplacements)
        let lu = UUID()
        let nonLu = UUID()

        try poser(dans: dossier, lu: lu, nonLu: nonLu)

        let journal = JournalDeStockageDeTest(lus: [lecture(lu)])
        let nettoyage = NettoyageDesTelechargementsLus(inspecteur: inspecteur, journal: journal)

        try await nettoyage.executer(reglage: .immediatement, maintenant: maintenant)

        #expect(await journal.oublies == [lu])
    }

    @Test("Un chapitre que la bibliotheque ne connait plus n est jamais efface")
    func lInconnuNEstJamaisEfface() async throws {
        let dossier = try DossierDeStockageDeTest()
        let inspecteur = InspecteurDeStockageSurDisque(emplacements: dossier.emplacements)
        let inconnu = UUID()

        try dossier.ecrire(
            300,
            dans: "\(inconnu.uuidString)/page-0000",
            sous: dossier.telechargements
        )

        let journal = JournalDeStockageDeTest(lus: [])
        let nettoyage = NettoyageDesTelechargementsLus(inspecteur: inspecteur, journal: journal)

        let effaces = try await nettoyage.executer(reglage: .immediatement, maintenant: maintenant)

        #expect(effaces.isEmpty)
        #expect(inspecteur.octets(de: .chapitresTelecharges) == 300)
    }

    @Test("Un second passage sur un disque deja nettoye n avertit personne")
    func leSecondPassageNeFaitRien() async throws {
        let dossier = try DossierDeStockageDeTest()
        let inspecteur = InspecteurDeStockageSurDisque(emplacements: dossier.emplacements)
        let lu = UUID()

        try dossier.ecrire(300, dans: "\(lu.uuidString)/page-0000", sous: dossier.telechargements)

        let journal = JournalDeStockageDeTest(lus: [lecture(lu)])
        let nettoyage = NettoyageDesTelechargementsLus(inspecteur: inspecteur, journal: journal)

        try await nettoyage.executer(reglage: .immediatement, maintenant: maintenant)
        try await nettoyage.executer(reglage: .immediatement, maintenant: maintenant)

        #expect(await journal.oublies == [lu])
    }
}
