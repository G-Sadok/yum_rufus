import Core
import Foundation
import ImagePipeline
import Testing
@testable import ReaderEngine

//
// Couvre la geometrie de plusieurs chapitres poses dans un meme defilement,
// section 7.4.
//
// Deux erreurs sont mesurees ici, parce qu elles ne se voient pas a l ecran
// avant plusieurs chapitres. Une position enregistree sous le nom du premier
// chapitre alors que l utilisateur en lit le troisieme, et une fenetre qui
// s arrete a la frontiere du chapitre au lieu de la franchir, ce qui ferait
// apparaitre le chapitre entrant d un bloc au lieu de le faire monter.
//

struct RubanDeChapitresTests {
    private let hauteurDeLaFenetre: Double = 800
    private let intercalaire: Double = 96

    private func segment(numero: Double, hauteurs: [Double]) -> SegmentDeChapitre {
        SegmentDeChapitre(
            chapitreId: UUID(),
            numero: numero,
            pile: DefilementContinu(hauteurs: hauteurs)
        )
    }

    /// Chapitre de webtoon, bandes longues decoupees en tuiles de 2048.
    private func segmentDeWebtoon(numero: Double, bandes: Int, hauteurEnPixels: Int = 20000) -> SegmentDeChapitre {
        let tuilage = TuilageDImageLongue.parDefaut
        let taille = TailleEnPixels(largeur: 800, hauteur: hauteurEnPixels)
        let hauteurs = [Double](repeating: Double(hauteurEnPixels) * 0.1, count: bandes)
        let decoupes = [[DecoupeDeTuile]](repeating: tuilage.decoupes(de: taille), count: bandes)

        return SegmentDeChapitre(
            chapitreId: UUID(),
            numero: numero,
            tuiles: PileDeTuiles(pile: DefilementContinu(hauteurs: hauteurs), decoupes: decoupes)
        )
    }

    @Test("Les chapitres s empilent separes par un seul intercalaire")
    func empilement() {
        let premier = segment(numero: 1, hauteurs: [1000, 1000])
        let deuxieme = segment(numero: 2, hauteurs: [500])

        let ruban = RubanDeChapitres(intercalaire: intercalaire, segments: [premier, deuxieme])

        #expect(ruban.debut(duSegment: 0) == 0)
        #expect(ruban.fin(duSegment: 0) == 2000)
        #expect(ruban.debut(duSegment: 1) == 2000 + intercalaire)
        #expect(ruban.hauteurTotale == 2000 + intercalaire + 500)
    }

    @Test("Le ruban vide ne rend aucun emplacement")
    func rubanVide() {
        let ruban = RubanDeChapitres(intercalaire: intercalaire)

        #expect(ruban.estVide)
        #expect(ruban.emplacement(auDecalage: 0) == nil)
        #expect(ruban.positionDeLecture(auDecalage: 0) == nil)
        #expect(ruban.segmentCourant(auDecalage: 0) == nil)
    }

    @Test("Un chapitre deja pose n est pas repose une seconde fois")
    func aucunDoublon() {
        let premier = segment(numero: 1, hauteurs: [1000])
        let ruban = RubanDeChapitres(intercalaire: intercalaire, segments: [premier])

        let augmente = ruban.ajoutant(premier)

        #expect(augmente.nombreDeChapitres == 1)
        #expect(augmente.hauteurTotale == 1000)
    }

    @Test("Un decalage tombe dans l intercalaire annonce le chapitre entrant")
    func emplacementDansLIntercalaire() {
        let premier = segment(numero: 1, hauteurs: [1000])
        let deuxieme = segment(numero: 2, hauteurs: [1000])
        let ruban = RubanDeChapitres(intercalaire: intercalaire, segments: [premier, deuxieme])

        #expect(ruban.emplacement(auDecalage: 1000 + intercalaire / 2) == .intercalaire(avantLeSegment: 1))
        #expect(ruban.emplacement(auDecalage: 1000) == .chapitre(segment: 0, decalage: 1000))
        #expect(ruban.emplacement(auDecalage: 1000 + intercalaire) == .chapitre(segment: 1, decalage: 0))
    }

    @Test("L intercalaire appartient au chapitre qui vient de finir")
    func intercalaireAuChapitrePrecedent() {
        let premier = segment(numero: 1, hauteurs: [1000])
        let deuxieme = segment(numero: 2, hauteurs: [1000])
        let ruban = RubanDeChapitres(intercalaire: intercalaire, segments: [premier, deuxieme])

        #expect(ruban.segmentCourant(auDecalage: 1000 + intercalaire / 2) == 0)
        #expect(ruban.segmentCourant(auDecalage: 1000 + intercalaire) == 1)
    }

    @Test("La position enregistree nomme le chapitre reellement lu")
    func positionNommeLeBonChapitre() {
        let premier = segment(numero: 1, hauteurs: [1000, 1000])
        let deuxieme = segment(numero: 2, hauteurs: [1000, 1000])
        let ruban = RubanDeChapitres(intercalaire: intercalaire, segments: [premier, deuxieme])

        let dansLePremier = ruban.positionDeLecture(auDecalage: 500)
        let dansLeSecond = ruban.positionDeLecture(auDecalage: 2000 + intercalaire + 1500)

        #expect(dansLePremier?.chapitreId == premier.chapitreId)
        #expect(dansLePremier?.pageIndex == 0)
        #expect(dansLePremier?.decalageDeDefilement == 0.5)

        #expect(dansLeSecond?.chapitreId == deuxieme.chapitreId)
        #expect(dansLeSecond?.pageIndex == 1)
        #expect(dansLeSecond?.decalageDeDefilement == 0.5)
    }

    @Test("La position prise dans l intercalaire reste sur le chapitre fini")
    func positionDansLIntercalaire() {
        let premier = segment(numero: 1, hauteurs: [1000])
        let deuxieme = segment(numero: 2, hauteurs: [1000])
        let ruban = RubanDeChapitres(intercalaire: intercalaire, segments: [premier, deuxieme])

        let position = ruban.positionDeLecture(auDecalage: 1000 + intercalaire / 2)

        #expect(position?.chapitreId == premier.chapitreId)
        #expect(position?.pageIndex == 0)
        #expect(position?.decalageDeDefilement == 1)
    }

    @Test("Une position se retrouve a son decalage, chapitre par chapitre")
    func reprise() {
        let premier = segment(numero: 1, hauteurs: [1000, 1000])
        let deuxieme = segment(numero: 2, hauteurs: [1000])
        let ruban = RubanDeChapitres(intercalaire: intercalaire, segments: [premier, deuxieme])

        let position = PositionDeLecture(
            chapitreId: deuxieme.chapitreId,
            pageIndex: 0,
            decalageDeDefilement: 0.25
        )

        #expect(ruban.decalage(pourReprise: position) == 2000 + intercalaire + 250)
    }

    @Test("Une position portant un chapitre absent du ruban ne rend aucun decalage")
    func repriseHorsDuRuban() {
        let ruban = RubanDeChapitres(intercalaire: intercalaire, segments: [segment(numero: 1, hauteurs: [1000])])
        let position = PositionDeLecture(chapitreId: UUID(), pageIndex: 0)

        #expect(ruban.decalage(pourReprise: position) == nil)
    }

    @Test("En defilement continu, la fenetre franchit la frontiere de chapitre")
    func fenetreQuiFranchitEnContinu() {
        let premier = segment(numero: 1, hauteurs: [1000, 1000])
        let deuxieme = segment(numero: 2, hauteurs: [1000, 1000])
        let ruban = RubanDeChapitres(intercalaire: intercalaire, segments: [premier, deuxieme])

        // Le bord haut est a 400 points de la fin du premier chapitre, la
        // fenetre en fait 800 : elle montre la fin du premier et le debut du
        // second.
        let tranches = ruban.pagesVisibles(auDecalage: 1600, hauteurDeLaFenetre: hauteurDeLaFenetre)

        #expect(tranches.count == 2)
        #expect(tranches.first == TrancheVisible(segment: 0, elements: 1..<2))
        #expect(tranches.last == TrancheVisible(segment: 1, elements: 0..<1))
    }

    @Test("En webtoon, la fenetre franchit la frontiere en tuiles")
    func fenetreQuiFranchitEnWebtoon() {
        let premier = segmentDeWebtoon(numero: 1, bandes: 2)
        let deuxieme = segmentDeWebtoon(numero: 2, bandes: 2)
        let ruban = RubanDeChapitres(intercalaire: intercalaire, segments: [premier, deuxieme])

        let decalage = ruban.fin(duSegment: 0) - 200
        let tranches = ruban.tuilesVisibles(auDecalage: decalage, hauteurDeLaFenetre: hauteurDeLaFenetre)

        #expect(tranches.count == 2)
        #expect(tranches.first?.segment == 0)
        #expect(tranches.last?.segment == 1)
        #expect(tranches.last?.elements.lowerBound == 0)

        // La derniere tuile du premier chapitre est bien la derniere de sa pile.
        let tuilesDuPremier = premier.tuiles?.nombreDeTuiles ?? 0
        #expect(tranches.first?.elements.upperBound == tuilesDuPremier)
    }

    @Test("Un chapitre lu en defilement continu ne rend aucune tuile")
    func aucuneTuileEnContinu() {
        let ruban = RubanDeChapitres(
            intercalaire: intercalaire,
            segments: [segment(numero: 1, hauteurs: [1000])]
        )

        #expect(ruban.tuilesVisibles(auDecalage: 0, hauteurDeLaFenetre: hauteurDeLaFenetre).isEmpty)
        #expect(ruban.pagesVisibles(auDecalage: 0, hauteurDeLaFenetre: hauteurDeLaFenetre).count == 1)
    }

    @Test("Le reste a parcourir tombe a zero au bas du ruban, et pas avant")
    func resteAParcourir() {
        let premier = segment(numero: 1, hauteurs: [1000])
        let deuxieme = segment(numero: 2, hauteurs: [1000])
        let ruban = RubanDeChapitres(intercalaire: intercalaire, segments: [premier, deuxieme])

        let bas = ruban.hauteurTotale - hauteurDeLaFenetre

        #expect(ruban.resteAParcourir(auDecalage: bas, hauteurDeLaFenetre: hauteurDeLaFenetre) == 0)
        #expect(ruban.resteAParcourir(auDecalage: bas - 100, hauteurDeLaFenetre: hauteurDeLaFenetre) == 100)
        #expect(ruban.resteAParcourir(auDecalage: 0, hauteurDeLaFenetre: hauteurDeLaFenetre) > 0)
    }

    @Test("Un chapitre pose apres coup allonge le ruban sans deplacer les autres")
    func ajoutApresCoup() {
        let premier = segment(numero: 1, hauteurs: [1000])
        var ruban = RubanDeChapitres(intercalaire: intercalaire, segments: [premier])
        let position = ruban.positionDeLecture(auDecalage: 500)

        ruban.ajouter(segment(numero: 2, hauteurs: [700]))

        #expect(ruban.nombreDeChapitres == 2)
        #expect(ruban.debut(duSegment: 0) == 0)
        #expect(ruban.hauteurTotale == 1000 + intercalaire + 700)
        #expect(ruban.positionDeLecture(auDecalage: 500) == position)
    }
}
