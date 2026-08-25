import Core
import CoreFoundation
import Foundation
import Testing
@testable import ImagePipeline

/// Couvre la seconde regle de la section 6.1 : la pleine resolution n existe
/// que pendant un geste de zoom, et disparait a la fin du geste.
struct ReserveDeZoomTests {
    private let pageDeReference = TailleEnPixels(largeur: 3000, hauteur: 4500)

    @Test("Hors geste, la reserve ne retient rien")
    func reserveVideAuDepart() async {
        let reserve = ReserveDeZoom()

        #expect(await reserve.estActif == false)
        #expect(await reserve.octetsRetenus == 0)
        #expect(await reserve.pageEnCours == nil)
    }

    @Test("Le geste de zoom rend la page entiere, sans sous echantillonnage")
    func zoomRendLaPleineResolution() async throws {
        let reserve = ReserveDeZoom()
        let page = try await reserve.commencer(sur: PageDeTest.standard, nom: "zoom.jpg")

        #expect(page.niveau == .pleineResolution)
        #expect(page.tailleDecodee == pageDeReference)
        #expect(page.estSousEchantillonnee == false)
        #expect(page.octetsEnMemoire > 50_000_000)
        #expect(await reserve.estActif)
    }

    @Test("La fin du geste vide la reserve")
    func finDuGesteVideLaReserve() async throws {
        let reserve = ReserveDeZoom()
        try await reserve.commencer(sur: PageDeTest.standard, nom: "zoom.jpg")
        await reserve.terminer()

        #expect(await reserve.estActif == false)
        #expect(await reserve.octetsRetenus == 0)
        #expect(await reserve.pageEnCours == nil)
    }

    @Test("La reserve relache reellement sa reference sur l image")
    func referenceRelachee() async throws {
        let reserve = ReserveDeZoom()
        let page = try await reserve.commencer(sur: PageDeTest.standard, nom: "zoom.jpg")

        // Le compte absolu ne veut rien dire, sa variation si. Elle prouve que
        // la reserve a bien lache l image, la ou une mesure d empreinte
        // dependrait du bon vouloir de l allocateur.
        let pendant = CFGetRetainCount(page.image)
        await reserve.terminer()
        let apres = CFGetRetainCount(page.image)

        #expect(apres < pendant)
    }

    @Test("Terminer deux fois ne fait rien de plus")
    func terminerEstIdempotent() async throws {
        let reserve = ReserveDeZoom()
        try await reserve.commencer(sur: PageDeTest.standard, nom: "zoom.jpg")
        await reserve.terminer()
        await reserve.terminer()

        #expect(await reserve.octetsRetenus == 0)
    }

    @Test("Un second geste remplace le premier, il ne s y ajoute pas")
    func unSeulGesteALaFois() async throws {
        let reserve = ReserveDeZoom()
        let premiere = try await reserve.commencer(sur: PageDeTest.standard, nom: "une.jpg")
        let seconde = try await reserve.commencer(sur: PageDeTest.standard, nom: "deux.jpg")

        #expect(await reserve.octetsRetenus == seconde.octetsEnMemoire)
        #expect(CFGetRetainCount(premiere.image) < CFGetRetainCount(seconde.image))
    }

    @Test("Un fichier illisible laisse la reserve vide plutot que pleine")
    func echecLaisseLaReserveVide() async throws {
        let reserve = ReserveDeZoom()
        try await reserve.commencer(sur: PageDeTest.standard, nom: "zoom.jpg")

        await #expect(throws: ErreurDeDecodage.formatInconnu(nom: "casse.jpg")) {
            try await reserve.commencer(sur: Data("pas une image".utf8), nom: "casse.jpg")
        }

        #expect(await reserve.estActif == false)
        #expect(await reserve.octetsRetenus == 0)
    }
}
