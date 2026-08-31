import Foundation
import Testing
@testable import BudgetsDePerformance

//
// ManifesteDuDepotTests
//
// Le manifeste suivi par le depot et la constante du code ne doivent jamais
// diverger.
//
// Ce sont deux ecritures du meme corpus : le script de generation lit le
// fichier, les tests lisent la constante. Le jour ou l un descend a mille
// series pour aller plus vite, l autre continue d annoncer cinq mille et le
// depot promet un corpus qu il ne produit plus.
//

struct ManifesteDuDepotTests {
    @Test("Le manifeste suivi par le depot est celui que le code declare")
    func manifesteAccordeAuCode() throws {
        let emplacement = EmplacementDuJeuDeTest.parDefaut(racineDuDepot: Self.racineDuDepot)
        let suivi = try emplacement.lireLeManifeste()

        #expect(suivi == ManifesteDuJeuDeTest.section12)
    }

    @Test("Le corpus annonce est bien celui de la section 12")
    func corpusDeLaSection12() throws {
        let emplacement = EmplacementDuJeuDeTest.parDefaut(racineDuDepot: Self.racineDuDepot)
        let suivi = try emplacement.lireLeManifeste()

        #expect(suivi.series == 5000)
        #expect(suivi.chapitres == 200_000)
        #expect(suivi.chapitresSurDisque >= 1)
        #expect(suivi.pagesParChapitreSurDisque > 1)
    }

    @Test("Les pages posees sur le disque ont la taille d un scan de manga")
    func pagesALaTailleDUnScan() throws {
        let emplacement = EmplacementDuJeuDeTest.parDefaut(racineDuDepot: Self.racineDuDepot)
        let suivi = try emplacement.lireLeManifeste()

        // Une page decodee en pleine resolution doit peser assez pour que le
        // budget memoire ait un sens. Le cahier chiffre une page de manga a
        // environ 54 Mo une fois decompressee, la borne basse retenue ici est
        // volontairement prudente.
        let octets = suivi.largeurDePage * suivi.hauteurDePage * 4

        #expect(octets > 20_000_000)
    }

    /// Racine du depot, deduite de l emplacement de ce fichier.
    ///
    /// Le chemin est fige a la compilation. Le deduire du dossier courant
    /// echouerait selon l endroit d ou la suite est lancee, et le deduire du
    /// bundle de test pointerait sur le dossier de construction.
    private static var racineDuDepot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
