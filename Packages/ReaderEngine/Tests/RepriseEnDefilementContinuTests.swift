import Core
import Foundation
import Testing
@testable import ReaderEngine

/// Position de reprise du mode Defilement continu, section 7.5.
///
/// La section demande un couple chapitre et index de page, plus un decalage de
/// defilement. Ces tests verifient que le mode continu produit bien les trois,
/// et que rouvrir avec eux retombe a l endroit exact ou la lecture s est
/// arretee, pas en haut de la page.
struct RepriseEnDefilementContinuTests {
    private let chapitre = UUID()
    private let interstice: Double = 12

    @Test("La position de reprise porte la page et la fraction de cette page")
    func positionPorteLaFraction() {
        let pile = DefilementContinu(hauteurs: Array(repeating: 1000, count: 40), interstice: interstice)
        let decalage = pile.debut(dePage: 17) + 250

        let position = pile.positionDeLecture(chapitreId: chapitre, auDecalage: decalage)

        #expect(position.chapitreId == chapitre)
        #expect(position.pageIndex == 17)
        #expect(position.decalageDeDefilement == 0.25)
    }

    @Test("Rouvrir a la position enregistree retombe au decalage exact")
    func repriseAuDecalageExact() {
        let pile = DefilementContinu(hauteurs: [1400, 900, 2600, 1800, 3200], interstice: interstice)

        for decalage in stride(from: 0.0, through: pile.hauteurTotale, by: 23) {
            let position = pile.positionDeLecture(chapitreId: chapitre, auDecalage: decalage)
            let reprise = pile.decalage(pourReprise: position)
            let finDeLaPage = pile.debut(dePage: position.pageIndex) + pile.hauteur(dePage: position.pageIndex)

            // Un decalage tombe dans l interstice revient a la fin de la page
            // qui precede, c est la meme regle que pour la position.
            let attendu = min(decalage, finDeLaPage)

            #expect(abs(reprise - attendu) < 1e-9, "decalage \(decalage) repris a \(reprise)")
        }
    }

    @Test("Une reprise au milieu d une page ne rouvre pas en haut de cette page")
    func repriseNeRemontePasEnHautDeLaPage() {
        let pile = DefilementContinu(hauteurs: Array(repeating: 1000, count: 40), interstice: interstice)
        let position = PositionDeLecture(chapitreId: chapitre, pageIndex: 17, decalageDeDefilement: 0.5)

        let reprise = pile.decalage(pourReprise: position)

        #expect(reprise == pile.debut(dePage: 17) + 500)
        #expect(reprise > pile.debut(dePage: 17))
    }

    @Test("Une position sans decalage rouvre bien en haut de sa page")
    func repriseSansDecalage() {
        let pile = DefilementContinu(hauteurs: Array(repeating: 1000, count: 40), interstice: interstice)
        let position = PositionDeLecture(chapitreId: chapitre, pageIndex: 17)

        #expect(pile.decalage(pourReprise: position) == pile.debut(dePage: 17))
    }

    @Test("La meme position reprise sur une fenetre plus etroite vise le meme endroit du dessin")
    func repriseIndependanteDeLaTailleDeLaFenetre() {
        // Meme chapitre, ajuste a deux largeurs de fenetre : les hauteurs sont
        // toutes multipliees par le meme facteur.
        let surTablette = DefilementContinu(hauteurs: Array(repeating: 2000, count: 12), interstice: 24)
        let surTelephone = DefilementContinu(hauteurs: Array(repeating: 1000, count: 12), interstice: 12)

        let position = surTablette.positionDeLecture(
            chapitreId: chapitre,
            auDecalage: surTablette.debut(dePage: 5) + 700
        )

        let reprise = surTelephone.decalage(pourReprise: position)
        let dansLaPage = reprise - surTelephone.debut(dePage: 5)

        #expect(position.decalageDeDefilement == 0.35)
        #expect(dansLaPage == 350)
    }

    @Test("Une position hors du chapitre est ramenee dedans avant la reprise")
    func repriseHorsDuChapitre() {
        let pile = DefilementContinu(hauteurs: Array(repeating: 1000, count: 4), interstice: interstice)
        let trop = PositionDeLecture(chapitreId: chapitre, pageIndex: 99, decalageDeDefilement: 4)
        let negative = PositionDeLecture(chapitreId: chapitre, pageIndex: -3, decalageDeDefilement: -1)

        #expect(pile.decalage(pourReprise: trop) == pile.debut(dePage: 3) + 1000)
        #expect(pile.decalage(pourReprise: negative) == 0)
    }

    @Test("La cadence de sauvegarde transporte le decalage de defilement jusqu a l enregistreur")
    func cadenceTransporteLeDecalage() async {
        let pile = DefilementContinu(hauteurs: Array(repeating: 1000, count: 40), interstice: interstice)
        let espion = EnregistreurEspion()
        let sauvegarde = SauvegardeDeProgression(enregistreur: espion)

        let decalage = pile.debut(dePage: 12) + 750
        await sauvegarde.deplacerVers(pile.positionDeLecture(chapitreId: chapitre, auDecalage: decalage))
        await sauvegarde.enregistrerMaintenant()

        let recue = await espion.derniere

        #expect(recue?.pageIndex == 12)
        #expect(recue?.decalageDeDefilement == 0.75)
        #expect(pile.decalage(pourReprise: recue ?? PositionDeLecture(chapitreId: chapitre, pageIndex: 0)) == decalage)
    }
}
