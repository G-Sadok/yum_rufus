import Core
import Foundation
import Testing
@testable import ReaderEngine

/// Cadence de sauvegarde de la position, section 7.5.
///
/// Les tests emploient une cadence courte plutot que les deux secondes reelles :
/// une suite qui dort six secondes pour verifier trois echeances n est plus
/// lancee par personne. La valeur de la section 7.5 est verifiee separement,
/// sur la constante que l application utilise.
struct SauvegardeDeProgressionTests {
    static let cadenceDeTest: Duration = .milliseconds(20)

    @Test("La cadence par defaut est celle de la section 7.5")
    func cadenceDeDeuxSecondes() {
        #expect(SauvegardeDeProgression.cadenceParDefaut == .seconds(2))
    }

    @Test("La position part toute seule a l echeance suivante")
    func lEcheanceEcritSansQuOnLuiDemande() async {
        let espion = EnregistreurEspion()
        let sauvegarde = SauvegardeDeProgression(
            enregistreur: espion,
            cadence: Self.cadenceDeTest
        )
        let position = PositionDeLecture(chapitreId: UUID(), pageIndex: 7, decalageDeDefilement: 0.3)

        await sauvegarde.demarrer()
        await sauvegarde.deplacerVers(position)

        let ecrite = await Attente.jusqua { await espion.derniere == position }
        #expect(ecrite, "La position n a pas ete ecrite dans le delai imparti")

        await sauvegarde.arreter()
    }

    @Test("Annoncer une position n ecrit rien avant l echeance")
    func annoncerNEcritPas() async {
        let espion = EnregistreurEspion()
        let sauvegarde = SauvegardeDeProgression(
            enregistreur: espion,
            cadence: .seconds(30)
        )

        await sauvegarde.demarrer()
        await sauvegarde.deplacerVers(PositionDeLecture(chapitreId: UUID(), pageIndex: 3))

        #expect(await espion.nombreDEcritures == 0)

        await sauvegarde.arreter()
    }

    @Test("Le passage en arriere plan ecrit sans attendre l echeance")
    func lArrierePlanEcritImmediatement() async {
        let espion = EnregistreurEspion()

        // Cadence assez longue pour qu aucune echeance ne tombe pendant le
        // test : ce qui est ecrit ici ne peut venir que du passage en arriere
        // plan.
        let sauvegarde = SauvegardeDeProgression(
            enregistreur: espion,
            cadence: .seconds(30)
        )
        let position = PositionDeLecture(chapitreId: UUID(), pageIndex: 12, decalageDeDefilement: 0.8)

        await sauvegarde.demarrer()
        await sauvegarde.deplacerVers(position)
        await sauvegarde.enregistrerMaintenant()

        #expect(await espion.derniere == position)
        #expect(await espion.nombreDEcritures == 1)

        await sauvegarde.arreter()
    }

    @Test("Une position immobile n est pas reecrite a chaque echeance")
    func laPositionImmobileNEstEcriteQuUneFois() async {
        let espion = EnregistreurEspion()
        let sauvegarde = SauvegardeDeProgression(
            enregistreur: espion,
            cadence: Self.cadenceDeTest
        )

        await sauvegarde.demarrer()
        await sauvegarde.deplacerVers(PositionDeLecture(chapitreId: UUID(), pageIndex: 1))

        let premiere = await Attente.jusqua { await espion.nombreDEcritures == 1 }
        #expect(premiere)

        // Plusieurs echeances passent sans que rien ne bouge.
        try? await Task.sleep(for: Self.cadenceDeTest * 5)

        #expect(await espion.nombreDEcritures == 1)

        await sauvegarde.arreter()
    }

    @Test("Chaque deplacement finit par etre enregistre")
    func chaqueDeplacementEstEnregistre() async {
        let espion = EnregistreurEspion()
        let sauvegarde = SauvegardeDeProgression(
            enregistreur: espion,
            cadence: Self.cadenceDeTest
        )
        let chapitre = UUID()

        await sauvegarde.demarrer()

        for page in 0..<3 {
            await sauvegarde.deplacerVers(PositionDeLecture(chapitreId: chapitre, pageIndex: page))
            _ = await Attente.jusqua { await espion.derniere?.pageIndex == page }
        }

        await sauvegarde.arreter()

        let recues = await espion.recues
        #expect(recues.map(\.pageIndex) == [0, 1, 2])
    }

    @Test("Une ecriture qui echoue est reprise a l echeance suivante")
    func uneEcritureRateeEstRejouee() async {
        let espion = EnregistreurEspion(refuse: true)
        let sauvegarde = SauvegardeDeProgression(
            enregistreur: espion,
            cadence: Self.cadenceDeTest
        )
        let position = PositionDeLecture(chapitreId: UUID(), pageIndex: 5, decalageDeDefilement: 0.1)

        await sauvegarde.demarrer()
        await sauvegarde.deplacerVers(position)

        let echec = await Attente.jusqua { await sauvegarde.derniereErreur != nil }
        #expect(echec, "L echec d ecriture n a pas ete consigne")
        #expect(await espion.nombreDEcritures == 0)

        await espion.accepterDeNouveau()

        let reprise = await Attente.jusqua { await espion.derniere == position }
        #expect(reprise, "La position sale n a pas ete rejouee")
        #expect(await sauvegarde.derniereErreur == nil)

        await sauvegarde.arreter()
    }

    @Test("La fermeture du lecteur enregistre la derniere position")
    func laFermetureEnregistreLaDernierePosition() async {
        let espion = EnregistreurEspion()
        let sauvegarde = SauvegardeDeProgression(
            enregistreur: espion,
            cadence: .seconds(30)
        )
        let position = PositionDeLecture(chapitreId: UUID(), pageIndex: 2)

        await sauvegarde.demarrer()
        await sauvegarde.deplacerVers(position)
        await sauvegarde.arreter()

        #expect(await espion.derniere == position)
    }
}
