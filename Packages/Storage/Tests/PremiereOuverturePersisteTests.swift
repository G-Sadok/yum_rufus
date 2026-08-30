import Core
import Foundation
import GRDB
import Testing
@testable import Storage

//
// Verifie que le parcours de premiere ouverture ne revient pas au lancement
// suivant, et que son rejeu depuis l ecran Reglages n en fait pas revenir un
// troisieme.
//
// Le test central est `leDrapeauSurvitAUneReouverture` : il ferme la base, la
// rouvre depuis le disque et relit le drapeau. Une implementation qui garderait
// l information en memoire echoue la, et le parcours reviendrait a chaque
// demarrage.
//

struct PremiereOuverturePersisteTests {
    @Test("Sur une installation neuve, le parcours n a jamais ete fait")
    func installationNeuve() throws {
        let base = try BaseDeDonnees.enMemoire()
        let magasin = MagasinDuParcoursDePremiereOuverture(base: base)

        #expect(try magasin.aEteFait() == false)

        var parcours = try magasin.parcours()
        let ouvert = parcours.ouvrirAuLancement()

        #expect(parcours.dejaFait == false)
        #expect(ouvert)
        #expect(parcours.etape == .sensDeLecture)
    }

    @Test("Le drapeau se pose et se relit")
    func drapeauPose() throws {
        let base = try BaseDeDonnees.enMemoire()
        let magasin = MagasinDuParcoursDePremiereOuverture(base: base)

        try magasin.marquerFait()

        #expect(try magasin.aEteFait())
        #expect(try magasin.parcours().dejaFait)
    }

    @Test("Marquer deux fois laisse une seule ligne")
    func ecritureIdempotente() throws {
        let base = try BaseDeDonnees.enMemoire()
        let magasin = MagasinDuParcoursDePremiereOuverture(base: base)

        try magasin.marquerFait()
        try magasin.marquerFait()

        let lignes = try base.ecrivain.read { connexion in
            try Int.fetchOne(
                connexion,
                sql: "SELECT COUNT(*) FROM reglageDeLApplication WHERE cle = ?",
                arguments: [MagasinDuParcoursDePremiereOuverture.cle]
            )
        }

        #expect(lignes == 1)
        #expect(try magasin.aEteFait())
    }

    @Test("Le drapeau survit a une reouverture de la base")
    func leDrapeauSurvitAUneReouverture() throws {
        let dossier = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dossier) }

        let fichier = dossier.appendingPathComponent("yum.sqlite")

        try MagasinDuParcoursDePremiereOuverture(base: BaseDeDonnees.surDisque(a: fichier))
            .marquerFait()

        let relu = try MagasinDuParcoursDePremiereOuverture(
            base: BaseDeDonnees.surDisque(a: fichier)
        )

        #expect(try relu.aEteFait())

        var parcours = try relu.parcours()
        let ouverture = parcours.ouvrirAuLancement()

        #expect(ouverture == false)
        #expect(parcours.estOuvert == false)
    }

    @Test("Le rejeu rouvre le parcours sans le faire revenir au lancement suivant")
    func rejeuSansRetour() throws {
        let base = try BaseDeDonnees.enMemoire()
        let magasin = MagasinDuParcoursDePremiereOuverture(base: base)

        try magasin.marquerFait()

        var parcours = try magasin.parcours()
        parcours.rejouer()

        #expect(parcours.estOuvert)
        #expect(parcours.etape == .sensDeLecture)

        // Le rejeu n efface pas la ligne : le lancement suivant reste calme.
        #expect(try magasin.aEteFait())
        #expect(try magasin.parcours().estOuvert == false)
    }

    @Test("La cle du parcours n est pas un reglage de la section 5.5")
    func cleHorsDesReglages() throws {
        #expect(IdentifiantDeReglage(rawValue: MagasinDuParcoursDePremiereOuverture.cle) == nil)

        let base = try BaseDeDonnees.enMemoire()

        try MagasinDuParcoursDePremiereOuverture(base: base).marquerFait()

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
        #expect(
            ValeurDeReglage.booleen(true).texte
                == MagasinDuParcoursDePremiereOuverture.marqueDeParcoursFait
        )
    }
}
