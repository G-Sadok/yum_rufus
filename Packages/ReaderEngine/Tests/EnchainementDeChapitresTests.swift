import Core
import Foundation
import Testing
@testable import ReaderEngine

//
// Couvre le chargement du chapitre suivant sans quitter le lecteur, section 7.4.
//
// Le mode webtoon n est pas un mode a part pour l enchainement, mais il pose des
// segments dont les elements sont des tuiles et non des pages. Un ruban qui ne
// saurait franchir la frontiere qu en pages ferait apparaitre le chapitre
// entrant d un bloc, precisement sur les chapitres les plus longs.
//
// Le marquage du chapitre quitte et la fin de la serie sont couverts par
// MarquageEtFinDeSerieTests.
//

struct EnchainementDeChapitresTests {
    private let hauteurDeLaFenetre = MaterielDEnchainement.hauteurDeLaFenetre
    private let intercalaire = MaterielDEnchainement.intercalaire

    @Test("En defilement continu, le chapitre suivant se charge sans quitter le lecteur")
    func enchainementEnContinu() async {
        let suite = MaterielDEnchainement.maillons(2)
        let premier = MaterielDEnchainement.segmentContinu(suite[0])
        let deuxieme = MaterielDEnchainement.segmentContinu(suite[1])

        let enchainement = MaterielDEnchainement.enchainement(
            suite: suite,
            premier: premier,
            chargeur: ChargeurDeTest(segments: [deuxieme]),
            marqueur: MarqueurEspion()
        )

        // Le bord haut arrive a une hauteur de fenetre du bas du chapitre.
        await enchainement.avancerA(2000 - 2 * hauteurDeLaFenetre, hauteurDeLaFenetre: hauteurDeLaFenetre)

        #expect(await MaterielDEnchainement.attendreLeRuban(de: enchainement, chapitres: 2))
        #expect(await enchainement.ruban.contient(deuxieme.chapitreId))
        #expect(await enchainement.ruban.hauteurTotale == 2000 + intercalaire + 2000)
    }

    @Test("En webtoon, le chapitre suivant se charge et ses tuiles entrent dans la fenetre")
    func enchainementEnWebtoon() async {
        let suite = MaterielDEnchainement.maillons(2)
        let premier = MaterielDEnchainement.segmentDeWebtoon(suite[0])
        let deuxieme = MaterielDEnchainement.segmentDeWebtoon(suite[1])

        let enchainement = MaterielDEnchainement.enchainement(
            suite: suite,
            premier: premier,
            chargeur: ChargeurDeTest(segments: [deuxieme]),
            marqueur: MarqueurEspion()
        )

        await enchainement.avancerA(premier.hauteur - hauteurDeLaFenetre, hauteurDeLaFenetre: hauteurDeLaFenetre)

        #expect(await MaterielDEnchainement.attendreLeRuban(de: enchainement, chapitres: 2))

        let ruban = await enchainement.ruban
        let tranches = ruban.tuilesVisibles(
            auDecalage: ruban.fin(duSegment: 0) - 200,
            hauteurDeLaFenetre: hauteurDeLaFenetre
        )

        #expect(tranches.count == 2)
        #expect(tranches.last?.segment == 1)
    }

    @Test("Le chargement ne part pas tant que le bas du chapitre est loin")
    func aucunChargementPremature() async {
        let suite = MaterielDEnchainement.maillons(2)
        let premier = MaterielDEnchainement.segmentContinu(suite[0], hauteurs: [5000, 5000])
        let chargeur = ChargeurDeTest(segments: [MaterielDEnchainement.segmentContinu(suite[1])])

        let enchainement = MaterielDEnchainement.enchainement(
            suite: suite,
            premier: premier,
            chargeur: chargeur,
            marqueur: MarqueurEspion()
        )

        await enchainement.avancerA(0, hauteurDeLaFenetre: hauteurDeLaFenetre)

        #expect(await chargeur.demandes.isEmpty)
        #expect(await enchainement.ruban.nombreDeChapitres == 1)
        #expect(await enchainement.etat == .enLecture(chapitre: premier.chapitreId))
    }

    @Test("Le chapitre entrant est annonce pendant son chargement")
    func etatDeChargement() async {
        let suite = MaterielDEnchainement.maillons(2)
        let premier = MaterielDEnchainement.segmentContinu(suite[0])
        let deuxieme = MaterielDEnchainement.segmentContinu(suite[1])

        let chargeur = ChargeurDeTest(segments: [deuxieme], ouvert: false)
        let enchainement = MaterielDEnchainement.enchainement(
            suite: suite,
            premier: premier,
            chargeur: chargeur,
            marqueur: MarqueurEspion()
        )

        await enchainement.avancerA(2000 - hauteurDeLaFenetre, hauteurDeLaFenetre: hauteurDeLaFenetre)

        #expect(await enchainement.etat == .chargement(chapitreEntrant: deuxieme.chapitreId))

        await chargeur.ouvrir()

        #expect(await MaterielDEnchainement.attendreLeRuban(de: enchainement, chapitres: 2))
        #expect(await enchainement.etat == .enLecture(chapitre: premier.chapitreId))
    }

    @Test("Un chargement en cours n est pas relance a chaque geste")
    func aucuneDemandeEnDouble() async {
        let suite = MaterielDEnchainement.maillons(2)
        let premier = MaterielDEnchainement.segmentContinu(suite[0])
        let chargeur = ChargeurDeTest(
            segments: [MaterielDEnchainement.segmentContinu(suite[1])],
            ouvert: false
        )

        let enchainement = MaterielDEnchainement.enchainement(
            suite: suite,
            premier: premier,
            chargeur: chargeur,
            marqueur: MarqueurEspion()
        )

        await enchainement.avancerA(2000 - hauteurDeLaFenetre, hauteurDeLaFenetre: hauteurDeLaFenetre)

        // La demande est attendue avant les gestes suivants : sans cela, le test
        // comparerait un compte que la tache detachee n a pas encore ecrit.
        #expect(await MaterielDEnchainement.attendreLesDemandes(de: chargeur, nombre: 1))

        for pas in 1..<5 {
            await enchainement.avancerA(
                2000 - hauteurDeLaFenetre + Double(pas),
                hauteurDeLaFenetre: hauteurDeLaFenetre
            )
        }

        #expect(await chargeur.demandes.count == 1)
    }

    @Test("Un chapitre injoignable est annonce, puis retente au geste suivant")
    func chapitreIndisponiblePuisCharge() async {
        let suite = MaterielDEnchainement.maillons(2)
        let premier = MaterielDEnchainement.segmentContinu(suite[0])
        let deuxieme = MaterielDEnchainement.segmentContinu(suite[1])

        let chargeur = ChargeurDeTest(segments: [deuxieme], refuse: true)
        let enchainement = MaterielDEnchainement.enchainement(
            suite: suite,
            premier: premier,
            chargeur: chargeur,
            marqueur: MarqueurEspion()
        )

        await enchainement.avancerA(2000 - hauteurDeLaFenetre, hauteurDeLaFenetre: hauteurDeLaFenetre)

        let annonce = await Attente.jusqua {
            await enchainement.etat == .chapitreIndisponible(chapitre: deuxieme.chapitreId)
        }

        #expect(annonce)
        #expect(await enchainement.ruban.nombreDeChapitres == 1)

        await chargeur.accepter()
        await enchainement.avancerA(2000 - hauteurDeLaFenetre + 1, hauteurDeLaFenetre: hauteurDeLaFenetre)

        #expect(await MaterielDEnchainement.attendreLeRuban(de: enchainement, chapitres: 2))
        #expect(await enchainement.derniereErreurDeChargement == nil)
    }

    @Test("La position enregistree suit le chapitre lu apres l enchainement")
    func positionApresEnchainement() async {
        let suite = MaterielDEnchainement.maillons(2)
        let premier = MaterielDEnchainement.segmentContinu(suite[0])
        let deuxieme = MaterielDEnchainement.segmentContinu(suite[1])

        let enchainement = MaterielDEnchainement.enchainement(
            suite: suite,
            premier: premier,
            chargeur: ChargeurDeTest(segments: [deuxieme]),
            marqueur: MarqueurEspion()
        )

        await enchainement.avancerA(2000 - hauteurDeLaFenetre, hauteurDeLaFenetre: hauteurDeLaFenetre)
        #expect(await MaterielDEnchainement.attendreLeRuban(de: enchainement, chapitres: 2))

        let position = await enchainement.positionDeLecture(auDecalage: 2000 + intercalaire + 1500)

        #expect(position?.chapitreId == deuxieme.chapitreId)
        #expect(position?.pageIndex == 1)
        #expect(position?.decalageDeDefilement == 0.5)
    }
}
