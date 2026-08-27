import Core
import Foundation
import GRDB
import Testing
@testable import Storage

//
// Verifie que le tutoriel des zones de toucher ne revient pas au lancement
// suivant.
//
// Le test central est `leDrapeauSurvitAUneReouverture` : il ferme la base, la
// rouvre depuis le disque et relit le drapeau. Une implementation qui garderait
// l information en memoire, ou dans une propriete d instance, echoue la, et le
// critere une seule fois ne tiendrait que le temps d une session.
//

struct TutorielDeZonesPersisteTests {
    @Test("Sur une installation neuve, le tutoriel n a jamais ete vu")
    func installationNeuve() throws {
        let base = try BaseDeDonnees.enMemoire()
        let magasin = MagasinDuTutorielDeZones(base: base)

        #expect(try magasin.aEteVu() == false)
        #expect(try magasin.tutoriel().dejaVu == false)
    }

    @Test("Le drapeau se pose et se relit")
    func drapeauPose() throws {
        let base = try BaseDeDonnees.enMemoire()
        let magasin = MagasinDuTutorielDeZones(base: base)

        try magasin.marquerVu()

        #expect(try magasin.aEteVu())
        #expect(try magasin.tutoriel().dejaVu)
    }

    @Test("Marquer deux fois laisse une seule ligne")
    func ecritureIdempotente() throws {
        let base = try BaseDeDonnees.enMemoire()
        let magasin = MagasinDuTutorielDeZones(base: base)

        try magasin.marquerVu()
        try magasin.marquerVu()

        let lignes = try base.ecrivain.read { connexion in
            try Int.fetchOne(
                connexion,
                sql: "SELECT COUNT(*) FROM reglageDeLApplication WHERE cle = ?",
                arguments: [MagasinDuTutorielDeZones.cle]
            )
        }

        #expect(lignes == 1)
        #expect(try magasin.aEteVu())
    }

    @Test("Le drapeau survit a une reouverture de la base")
    func leDrapeauSurvitAUneReouverture() throws {
        let dossier = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dossier) }

        let fichier = dossier.appendingPathComponent("yum.sqlite")

        try MagasinDuTutorielDeZones(base: BaseDeDonnees.surDisque(a: fichier)).marquerVu()

        let relu = try MagasinDuTutorielDeZones(base: BaseDeDonnees.surDisque(a: fichier))

        #expect(try relu.aEteVu())

        var tutoriel = try relu.tutoriel()
        let apparait = tutoriel.ouvrirLeLecteur(disposition: .standard, instant: 0)

        #expect(apparait == false)
        #expect(tutoriel.estAffiche == false)
    }

    @Test("La cle du tutoriel n est pas un reglage de la section 5.5")
    func cleHorsDesReglages() throws {
        #expect(IdentifiantDeReglage(rawValue: MagasinDuTutorielDeZones.cle) == nil)

        let base = try BaseDeDonnees.enMemoire()

        try MagasinDuTutorielDeZones(base: base).marquerVu()

        // La ligne partage la table des reglages, elle ne doit pourtant
        // apparaitre dans aucun reglage lu par l ecran Reglages.
        let reglages = try MagasinDeReglages(base: base).reglages()

        for identifiant in IdentifiantDeReglage.allCases {
            #expect(
                reglages[identifiant] == CatalogueDeReglages.valeurParDefaut(de: identifiant),
                "\(identifiant.rawValue)"
            )
        }
    }

    @Test("La forme persistee du drapeau est celle des reglages booleens")
    func memeEcritureQueLesReglages() {
        #expect(ValeurDeReglage.booleen(true).texte == MagasinDuTutorielDeZones.marqueDeVisionnage)
    }
}
