import Core
import Foundation
import Testing
@testable import Sources

//
// SourceICloudDriveTests
//
// Ce que la source rend sur un dossier iCloud Drive dont une partie n est pas
// telechargee.
//
// Le dossier de test melange volontairement les deux etats. Un chapitre deja
// present et un chapitre absent, une image posee deja presente et une image
// absente : c est la seule facon de verifier a la fois que l absent est
// rapatrie et que le present ne l est pas. Une suite ou tout serait absent
// laisserait passer une source qui redemanderait tout a chaque ouverture.
//

struct SourceICloudDriveTests {
    private static let nom = "Dossier iCloud de test"
    private static let chapitreAbsent = "Serie A/Chapitre 1.cbz"
    private static let chapitrePresent = "Serie A/Chapitre 2.cbz"

    // MARK: Analyse

    @Test("Un chapitre non telecharge est liste sous son vrai nom")
    func chapitreNonTelechargeListe() async throws {
        try await avecBibliotheque { source, _ in
            let chapitres = try await source.chapitres(pour: "Serie A")

            #expect(chapitres.map(\.titre) == ["Chapitre 1", "Chapitre 2"])
            #expect(chapitres.map(\.identifiant) == [Self.chapitreAbsent, Self.chapitrePresent])
        }
    }

    @Test("Le substitut d un fichier non telecharge ne devient jamais une serie")
    func substitutJamaisPrisPourUneSerie() async throws {
        try await avecBibliotheque { source, _ in
            let series = try await source.analyse().series

            #expect(series.map(\.titre) == ["Serie A", "Serie B"])
        }
    }

    @Test("L analyse ne telecharge rien")
    func analyseSansTelechargement() async throws {
        try await avecBibliotheque { source, depot in
            _ = try await source.analyse()

            #expect(await depot.nombreTotalDeDemandes == 0)
        }
    }

    // MARK: Telechargement a la demande

    @Test("Ouvrir un chapitre non telecharge declenche son telechargement")
    func ouvertureDUnChapitreAbsent() async throws {
        try await avecBibliotheque { source, depot in
            let pages = try await source.pages(pour: Self.chapitreAbsent)

            #expect(pages.map(\.entree) == ["page1.jpg", "page2.jpg", "page10.jpg"])
            #expect(await depot.nombreDeDemandes(pour: Self.chapitreAbsent) == 1)
        }
    }

    @Test("Le telechargement d un chapitre publie une progression jusqu a la fin")
    func progressionDUnChapitre() async throws {
        try await avecBibliotheque(pas: 64) { source, _ in
            let flux = await source.progressions()

            async let recues = ProgressionsObservees.jusquALaFin(flux, identifiant: Self.chapitreAbsent)

            _ = try await source.pages(pour: Self.chapitreAbsent)

            let progressions = await recues

            #expect(progressions.count > 2)
            #expect(progressions.first?.fraction == 0)
            #expect(progressions.last?.estTermine == true)
            #expect(progressions.last?.fraction == 1)
            #expect(estCroissante(progressions.map(\.octetsRecus)))
        }
    }

    @Test("Ouvrir un chapitre deja telecharge ne demande rien au systeme")
    func ouvertureDUnChapitrePresent() async throws {
        try await avecBibliotheque { source, depot in
            let pages = try await source.pages(pour: Self.chapitrePresent)

            #expect(pages.map(\.entree) == ["01.png"])
            #expect(await depot.nombreTotalDeDemandes == 0)
        }
    }

    @Test("Une image posee non telechargee est rapatriee au moment de sa lecture")
    func imagePoseeAbsente() async throws {
        try await avecBibliotheque { source, depot in
            let pages = try await source.pages(pour: "Serie B/Ch 01")

            #expect(pages.map(\.emplacement.lastPathComponent) == ["page1.jpg", "page2.jpg"])
            // Lister le chapitre ne rapatrie rien : une grille qui affiche
            // vingt chapitres declencherait autant de telechargements.
            #expect(await depot.nombreTotalDeDemandes == 0)

            let octets = try await source.donnees(page: pages[0])

            #expect(octets.count == 16)
            #expect(await depot.nombreDeDemandes(pour: "Serie B/Ch 01/page1.jpg") == 1)
        }
    }

    @Test("Deux ouvertures simultanees du meme chapitre ne le telechargent qu une fois")
    func ouverturesSimultanees() async throws {
        try await avecBibliotheque(pas: 64) { source, depot in
            async let premiere = source.pages(pour: Self.chapitreAbsent)
            async let seconde = source.pages(pour: Self.chapitreAbsent)

            let pages = try await [premiere, seconde]

            #expect(pages[0] == pages[1])
            #expect(await depot.nombreDeDemandes(pour: Self.chapitreAbsent) == 1)
        }
    }

    // MARK: Octets d une page

    @Test("Les octets d une page passent par la coordination de fichiers")
    func octetsCoordonnes() async throws {
        let espion = CoordinationEspionne()

        try await avecBibliotheque(coordination: espion) { source, _ in
            let pages = try await source.pages(pour: Self.chapitreAbsent)
            let octets = try await source.donnees(page: pages[0])

            #expect(octets.isEmpty == false)
            #expect(espion.lectures >= 2)
        }
    }

    @Test("Aucune page ne s obtient par une requete")
    func pageNonAdressable() async throws {
        try await avecBibliotheque { source, _ in
            let pages = try await source.pages(pour: Self.chapitrePresent)

            await #expect(throws: ErreurDeSource.pageNonAdressableParRequete(entree: "01.png")) {
                _ = try await source.requeteImage(pour: pages[0])
            }
        }
    }

    // MARK: Refus

    @Test("Un chapitre inconnu est refuse")
    func chapitreInconnu() async throws {
        try await avecBibliotheque { source, _ in
            await #expect(throws: ErreurDeSource.chapitreIntrouvable(identifiant: "Serie A/Chapitre 9.cbz")) {
                _ = try await source.pages(pour: "Serie A/Chapitre 9.cbz")
            }
        }
    }

    @Test("La source declare la recherche et la pagination, et rien d autre")
    func capacitesDeclarees() async throws {
        try await avecBibliotheque { source, _ in
            #expect(source.capacites == [.recherche, .pagination])
        }
    }

    // MARK: Outils

    /// Monte un dossier iCloud de test, moitie present et moitie absent.
    private func avecBibliotheque(
        pas: Int64 = 4096,
        coordination: (any CoordinationDeFichiers)? = nil,
        _ corps: (SourceICloudDrive, DepotICloudSimule) async throws -> Void
    ) async throws {
        let arbre = try ArbreDeTest(nom: "icloud")
        let espaceApplicatif = try ArbreDeTest(nom: "espace-applicatif")
        let depot = DepotICloudSimule(racine: arbre.racine, pas: pas)

        try await depot.poserAbsent(
            Self.chapitreAbsent,
            contenu: ConstructeurDeZipDeTest.octets([
                EntreeDeZipDeTest(nom: "page2.jpg", contenu: Data(repeating: 0x2A, count: 24)),
                EntreeDeZipDeTest(nom: "page10.jpg", contenu: Data(repeating: 0x2A, count: 24)),
                EntreeDeZipDeTest(nom: "page1.jpg", contenu: Data(repeating: 0x2A, count: 24)),
            ])
        )
        try await depot.poserLocal(
            Self.chapitrePresent,
            contenu: ConstructeurDeZipDeTest.octets([
                EntreeDeZipDeTest(nom: "01.png", contenu: Data(repeating: 0x2A, count: 24)),
            ])
        )
        try await depot.poserAbsent("Serie B/Ch 01/page1.jpg", contenu: Data(repeating: 0xFF, count: 16))
        try await depot.poserLocal("Serie B/Ch 01/page2.jpg", contenu: Data(repeating: 0xFF, count: 16))

        let source = try SourceICloudDrive.enregistrant(
            dossier: arbre.racine,
            nom: Self.nom,
            magasin: MagasinDeSignetsFichier(fichier: espaceApplicatif.racine.appending(path: "signets.json")),
            depot: depot,
            coordination: coordination ?? CoordinationParLeSysteme(),
            cadenceDeSondage: .milliseconds(1)
        )

        try await corps(source, depot)
        await source.liberer()
    }

    /// Vrai quand la suite ne recule jamais.
    private func estCroissante(_ valeurs: [Int64]) -> Bool {
        zip(valeurs, valeurs.dropFirst()).allSatisfy { precedente, suivante in precedente <= suivante }
    }
}

/// Coordination qui compte les acces avant de les confier au systeme.
///
/// Meme raison que `TemoinDAcces` pour le `@unchecked Sendable` : le compteur
/// est protege par un verrou, et il est incremente depuis des taches que le
/// coordinateur du systeme ordonnance lui meme.
final class CoordinationEspionne: CoordinationDeFichiers, @unchecked Sendable {
    private let verrou = NSLock()
    private let coordination = CoordinationParLeSysteme()
    private var nombreDeLectures = 0
    private var nombreDEcritures = 0

    /// Nombre de lectures coordonnees demandees.
    var lectures: Int {
        verrou.withLock { nombreDeLectures }
    }

    /// Nombre d ecritures coordonnees demandees.
    var ecritures: Int {
        verrou.withLock { nombreDEcritures }
    }

    func lire<Resultat: Sendable>(
        _ fichier: URL,
        _ operation: @escaping @Sendable (URL) throws -> Resultat
    ) async throws -> Resultat {
        verrou.withLock { nombreDeLectures += 1 }

        return try await coordination.lire(fichier, operation)
    }

    func ecrire<Resultat: Sendable>(
        _ fichier: URL,
        _ operation: @escaping @Sendable (URL) throws -> Resultat
    ) async throws -> Resultat {
        verrou.withLock { nombreDEcritures += 1 }

        return try await coordination.ecrire(fichier, operation)
    }
}
