import Core
import Foundation
import Testing
@testable import Sources

//
// TelechargementICloudTests
//
// Le premier critere de la fonctionnalite : un fichier non telecharge declenche
// son telechargement, et ce telechargement se voit avancer.
//
// Verifier qu un fichier finit par etre lisible ne prouverait rien : une source
// qui attendrait sans rien publier passerait ce test. Ce qui prouve le critere,
// ce sont les progressions publiees entre le debut et la fin, leur croissance,
// et le fait que la derniere soit terminale.
//

struct TelechargementICloudTests {
    private static let nom = "Dossier iCloud de test"
    private static let cadence = Duration.milliseconds(1)

    // MARK: Declenchement

    @Test("Un fichier deja present ne declenche aucun telechargement")
    func fichierDejaPresent() async throws {
        let arbre = try ArbreDeTest(nom: "icloud")
        let depot = DepotICloudSimule(racine: arbre.racine)

        try await depot.poserLocal("Chapitre 1.cbz", contenu: Data(repeating: 0x2A, count: 4096))

        let telechargeur = telechargeur(depot)
        let telecharge = try await telechargeur.assurerLaPresence(
            de: arbre.racine.appending(path: "Chapitre 1.cbz"),
            identifiant: "Chapitre 1.cbz"
        )

        #expect(telecharge == false)
        #expect(await depot.nombreDeDemandes(pour: "Chapitre 1.cbz") == 0)
        #expect(await telechargeur.progression(de: "Chapitre 1.cbz") == nil)
    }

    @Test("Un fichier non telecharge est demande au systeme puis rendu lisible")
    func fichierAbsent() async throws {
        let arbre = try ArbreDeTest(nom: "icloud")
        let depot = DepotICloudSimule(racine: arbre.racine, pas: 1024)
        let contenu = Data(repeating: 0x2A, count: 4096)

        try await depot.poserAbsent("Chapitre 1.cbz", contenu: contenu)

        let fichier = arbre.racine.appending(path: "Chapitre 1.cbz")
        let telecharge = try await telechargeur(depot).assurerLaPresence(
            de: fichier,
            identifiant: "Chapitre 1.cbz"
        )

        #expect(telecharge)
        #expect(await depot.nombreDeDemandes(pour: "Chapitre 1.cbz") == 1)
        #expect(try Data(contentsOf: fichier) == contenu)
    }

    // MARK: Progression

    @Test("La progression est publiee du premier octet jusqu a la fin")
    func progressionPublieeDuDebutALaFin() async throws {
        let arbre = try ArbreDeTest(nom: "icloud")
        let depot = DepotICloudSimule(racine: arbre.racine, pas: 1024)

        try await depot.poserAbsent("Chapitre 1.cbz", contenu: Data(repeating: 0x2A, count: 4096))

        let telechargeur = telechargeur(depot)
        let flux = await telechargeur.progressions()

        async let recues = ProgressionsObservees.jusquALaFin(flux, identifiant: "Chapitre 1.cbz")

        _ = try await telechargeur.assurerLaPresence(
            de: arbre.racine.appending(path: "Chapitre 1.cbz"),
            identifiant: "Chapitre 1.cbz"
        )

        let progressions = await recues

        // Quatre pas de 1024 octets, plus la publication initiale a zero.
        #expect(progressions.count == 5)
        #expect(progressions.map(\.octetsRecus) == [0, 1024, 2048, 3072, 4096])
        #expect(progressions.allSatisfy { $0.octetsAttendus == 4096 })
        #expect(progressions.first?.fraction == 0)
        #expect(progressions.dropLast().allSatisfy { $0.estTermine == false })
        #expect(progressions.last?.estTermine == true)
        #expect(progressions.last?.fraction == 1)
    }

    @Test("La derniere progression connue reste consultable apres coup")
    func derniereProgressionConsultable() async throws {
        let arbre = try ArbreDeTest(nom: "icloud")
        let depot = DepotICloudSimule(racine: arbre.racine, pas: 2048)

        try await depot.poserAbsent("Chapitre 1.cbz", contenu: Data(repeating: 0x2A, count: 4096))

        let telechargeur = telechargeur(depot)

        _ = try await telechargeur.assurerLaPresence(
            de: arbre.racine.appending(path: "Chapitre 1.cbz"),
            identifiant: "Chapitre 1.cbz"
        )

        let derniere = await telechargeur.progression(de: "Chapitre 1.cbz")

        #expect(derniere?.estTermine == true)
        #expect(derniere?.octetsRecus == 4096)
    }

    // MARK: Concurrence

    @Test("Deux demandes simultanees sur le meme fichier ne le telechargent qu une fois")
    func demandesSimultanees() async throws {
        let arbre = try ArbreDeTest(nom: "icloud")
        let depot = DepotICloudSimule(racine: arbre.racine, pas: 512)

        try await depot.poserAbsent("Chapitre 1.cbz", contenu: Data(repeating: 0x2A, count: 4096))

        let telechargeur = telechargeur(depot)
        let fichier = arbre.racine.appending(path: "Chapitre 1.cbz")

        async let premiere = telechargeur.assurerLaPresence(de: fichier, identifiant: "Chapitre 1.cbz")
        async let seconde = telechargeur.assurerLaPresence(de: fichier, identifiant: "Chapitre 1.cbz")

        let resultats = try await [premiere, seconde]

        #expect(resultats == [true, true])
        #expect(await depot.nombreDeDemandes(pour: "Chapitre 1.cbz") == 1)
    }

    // MARK: Panne

    @Test("Un telechargement qui n avance plus s arrete sur un delai depasse")
    func telechargementQuiNAvancePlus() async throws {
        let arbre = try ArbreDeTest(nom: "icloud")
        let depot = DepotICloudSimule(racine: arbre.racine, pas: 0)

        try await depot.poserAbsent("Chapitre 1.cbz", contenu: Data(repeating: 0x2A, count: 4096))

        let telechargeur = TelechargeurICloud(
            nom: Self.nom,
            depot: depot,
            cadence: Self.cadence,
            sondagesSansProgres: 3
        )

        await #expect(throws: ErreurDeSource.reseau(.delaiDepasse, source: Self.nom)) {
            _ = try await telechargeur.assurerLaPresence(
                de: arbre.racine.appending(path: "Chapitre 1.cbz"),
                identifiant: "Chapitre 1.cbz"
            )
        }
    }

    @Test("Un echec laisse le fichier redemandable")
    func echecPuisNouvelEssai() async throws {
        let arbre = try ArbreDeTest(nom: "icloud")
        let depot = DepotICloudSimule(racine: arbre.racine, pas: 0)

        try await depot.poserAbsent("Chapitre 1.cbz", contenu: Data(repeating: 0x2A, count: 4096))

        let telechargeur = TelechargeurICloud(
            nom: Self.nom,
            depot: depot,
            cadence: Self.cadence,
            sondagesSansProgres: 2
        )
        let fichier = arbre.racine.appending(path: "Chapitre 1.cbz")

        for _ in 0..<2 {
            _ = try? await telechargeur.assurerLaPresence(de: fichier, identifiant: "Chapitre 1.cbz")
        }

        // La seconde tentative a bien atteint le systeme : un telechargement en
        // echec ne doit pas rester coince dans la table des telechargements en
        // cours, sinon le fichier ne se redemande jamais.
        #expect(await depot.nombreDeDemandes(pour: "Chapitre 1.cbz") == 2)
    }

    // MARK: Outils

    private func telechargeur(_ depot: DepotICloudSimule) -> TelechargeurICloud {
        TelechargeurICloud(nom: Self.nom, depot: depot, cadence: Self.cadence)
    }
}

/// Collecte les progressions publiees par un telechargeur.
enum ProgressionsObservees {
    /// Rend les progressions d un telechargement jusqu a la derniere.
    ///
    /// La collecte s arrete sur la progression terminale et non sur la fin du
    /// flux : le flux d un telechargeur ne se termine pas, il continue de
    /// servir les telechargements suivants.
    static func jusquALaFin(
        _ flux: AsyncStream<ProgressionDeTelechargement>,
        identifiant: String
    ) async -> [ProgressionDeTelechargement] {
        var recues: [ProgressionDeTelechargement] = []

        for await progression in flux where progression.identifiant == identifiant {
            recues.append(progression)

            if progression.estTermine {
                break
            }
        }

        return recues
    }
}
