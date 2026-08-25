import Core
import Foundation
import Testing

/// Regle de marquage automatique et bornes de la position de lecture.
///
/// Le seuil de quatre vingt quinze pour cent est un critere d acceptation de la
/// fonctionnalite. Il est verifie ici sur les deux cotes de la frontiere, pas
/// seulement sur un cas confortable au milieu.
struct ProgressionDeChapitreTests {
    @Test("La derniere page d un chapitre vaut une part entiere")
    func laDernierePageVautUn() {
        #expect(ProgressionDeChapitre.part(pageAtteinte: 19, nombreDePages: 20) == 1)
        #expect(ProgressionDeChapitre.part(pageAtteinte: 0, nombreDePages: 1) == 1)
    }

    @Test("Un chapitre au dessus du seuil est marque lu")
    func auDessusDuSeuil() {
        // Vingt pages, derniere page atteinte : cent pour cent.
        #expect(ProgressionDeChapitre.depasseLeSeuil(pageAtteinte: 19, nombreDePages: 20))

        // Cent pages, page quatre vingt seize atteinte : quatre vingt seize
        // pour cent.
        #expect(ProgressionDeChapitre.depasseLeSeuil(pageAtteinte: 95, nombreDePages: 100))
    }

    @Test("Un chapitre pile au seuil n est pas marque lu")
    func pileAuSeuil() {
        // Cent pages, page quatre vingt quinze atteinte : exactement quatre
        // vingt quinze pour cent. Le seuil est strict, donc non lu.
        let part = ProgressionDeChapitre.part(pageAtteinte: 94, nombreDePages: 100)

        #expect(part == 0.95)
        #expect(ProgressionDeChapitre.depasseLeSeuil(pageAtteinte: 94, nombreDePages: 100) == false)
    }

    @Test("Un chapitre en dessous du seuil reste en cours")
    func endessousDuSeuil() {
        #expect(ProgressionDeChapitre.depasseLeSeuil(pageAtteinte: 18, nombreDePages: 20) == false)
        #expect(ProgressionDeChapitre.depasseLeSeuil(pageAtteinte: 0, nombreDePages: 20) == false)
    }

    @Test("Un nombre de pages inconnu ne marque jamais lu")
    func nombreDePagesInconnu() {
        #expect(ProgressionDeChapitre.part(pageAtteinte: 12, nombreDePages: 0) == 0)
        #expect(ProgressionDeChapitre.depasseLeSeuil(pageAtteinte: 12, nombreDePages: 0) == false)
    }

    @Test("Une page atteinte negative ne compte pas")
    func pageAtteinteNegative() {
        #expect(ProgressionDeChapitre.part(pageAtteinte: -3, nombreDePages: 20) == 0)
    }

    @Test("La position est ramenee dans les bornes du chapitre")
    func normalisationDeLaPosition() {
        let chapitre = UUID()
        let horsBornes = PositionDeLecture(
            chapitreId: chapitre,
            pageIndex: 42,
            decalageDeDefilement: 1.7
        )

        let ramenee = horsBornes.normalisee(nombreDePages: 20)

        #expect(ramenee.pageIndex == 19)
        #expect(ramenee.decalageDeDefilement == 1)
        #expect(ramenee.chapitreId == chapitre)
    }

    @Test("Une position negative revient au debut du chapitre")
    func normalisationDUnePositionNegative() {
        let position = PositionDeLecture(
            chapitreId: UUID(),
            pageIndex: -2,
            decalageDeDefilement: -0.4
        )

        let ramenee = position.normalisee(nombreDePages: 20)

        #expect(ramenee.pageIndex == 0)
        #expect(ramenee.decalageDeDefilement == 0)
    }

    @Test("Un nombre de pages encore inconnu preserve l index")
    func normalisationSansNombreDePages() {
        let position = PositionDeLecture(chapitreId: UUID(), pageIndex: 12)

        #expect(position.normalisee(nombreDePages: 0).pageIndex == 12)
    }
}
