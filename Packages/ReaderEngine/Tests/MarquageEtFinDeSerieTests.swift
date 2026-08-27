import Core
import Foundation
import Testing
@testable import ReaderEngine

//
// Couvre le marquage du chapitre quitte et la fin de la serie, section 7.4.
//
// Le marquage doit avoir lieu une fois et une seule. Deux ecritures ne changent
// pas l etat affiche, mais elles passent par une transaction chacune pendant un
// defilement, et le budget de la section 12 ne les supporte pas.
//
// La fin de la serie n est annoncee que sur le dernier chapitre connu. Une fin
// annoncee sur une suite inconnue, celle d un lecteur ouvert sans sa liste de
// chapitres, ferait sortir l utilisateur d une serie qui continue.
//

struct MarquageEtFinDeSerieTests {
    private let hauteurDeLaFenetre = MaterielDEnchainement.hauteurDeLaFenetre
    private let intercalaire = MaterielDEnchainement.intercalaire

    // MARK: Marquage du chapitre quitte

    @Test("Le chapitre precedent est marque lu au passage du suivant")
    func marquageAuPassage() async {
        let suite = MaterielDEnchainement.maillons(2)
        let premier = MaterielDEnchainement.segmentContinu(suite[0])
        let deuxieme = MaterielDEnchainement.segmentContinu(suite[1])

        let marqueur = MarqueurEspion()
        let enchainement = MaterielDEnchainement.enchainement(
            suite: suite,
            premier: premier,
            chargeur: ChargeurDeTest(segments: [deuxieme]),
            marqueur: marqueur
        )

        await enchainement.avancerA(2000 - hauteurDeLaFenetre, hauteurDeLaFenetre: hauteurDeLaFenetre)
        #expect(await MaterielDEnchainement.attendreLeRuban(de: enchainement, chapitres: 2))

        // Tant que le doigt est dans l intercalaire, rien n est marque.
        await enchainement.avancerA(2000 + intercalaire / 2, hauteurDeLaFenetre: hauteurDeLaFenetre)
        #expect(await marqueur.marques.isEmpty)

        await enchainement.avancerA(2000 + intercalaire, hauteurDeLaFenetre: hauteurDeLaFenetre)

        #expect(await marqueur.marques == [premier.chapitreId])
        #expect(await enchainement.chapitreCourant == deuxieme.chapitreId)
    }

    @Test("Un chapitre n est marque qu une fois, et un retour en arriere ne le demarque pas")
    func marquageUnique() async {
        let suite = MaterielDEnchainement.maillons(2)
        let premier = MaterielDEnchainement.segmentContinu(suite[0])
        let deuxieme = MaterielDEnchainement.segmentContinu(suite[1])

        let marqueur = MarqueurEspion()
        let enchainement = MaterielDEnchainement.enchainement(
            suite: suite,
            premier: premier,
            chargeur: ChargeurDeTest(segments: [deuxieme]),
            marqueur: marqueur
        )

        await enchainement.avancerA(2000 - hauteurDeLaFenetre, hauteurDeLaFenetre: hauteurDeLaFenetre)
        #expect(await MaterielDEnchainement.attendreLeRuban(de: enchainement, chapitres: 2))

        await enchainement.avancerA(2000 + intercalaire + 10, hauteurDeLaFenetre: hauteurDeLaFenetre)
        await enchainement.avancerA(500, hauteurDeLaFenetre: hauteurDeLaFenetre)
        await enchainement.avancerA(2000 + intercalaire + 10, hauteurDeLaFenetre: hauteurDeLaFenetre)

        #expect(await marqueur.marques == [premier.chapitreId])
        #expect(await enchainement.chapitresMarquesLus == [premier.chapitreId])
    }

    @Test("Un defilement qui traverse deux chapitres les marque tous les deux")
    func marquageDeDeuxChapitresTraverses() async {
        let suite = MaterielDEnchainement.maillons(3)
        let premier = MaterielDEnchainement.segmentContinu(suite[0], hauteurs: [400])
        let deuxieme = MaterielDEnchainement.segmentContinu(suite[1], hauteurs: [400])
        let troisieme = MaterielDEnchainement.segmentContinu(suite[2], hauteurs: [4000])

        let marqueur = MarqueurEspion()
        let enchainement = MaterielDEnchainement.enchainement(
            suite: suite,
            premier: premier,
            chargeur: ChargeurDeTest(segments: [deuxieme, troisieme]),
            marqueur: marqueur
        )

        await enchainement.avancerA(0, hauteurDeLaFenetre: hauteurDeLaFenetre)
        #expect(await MaterielDEnchainement.attendreLeRuban(de: enchainement, chapitres: 2))

        await enchainement.avancerA(0, hauteurDeLaFenetre: hauteurDeLaFenetre)
        #expect(await MaterielDEnchainement.attendreLeRuban(de: enchainement, chapitres: 3))

        // Un elan qui saute du premier au troisieme chapitre en une annonce.
        let ruban = await enchainement.ruban
        await enchainement.avancerA(ruban.debut(duSegment: 2) + 10, hauteurDeLaFenetre: hauteurDeLaFenetre)

        #expect(await marqueur.marques == [premier.chapitreId, deuxieme.chapitreId])
    }

    @Test("Un marquage refuse reste du et repart au geste suivant")
    func marquageRejoueApresUnEchec() async {
        let suite = MaterielDEnchainement.maillons(2)
        let premier = MaterielDEnchainement.segmentContinu(suite[0])
        let deuxieme = MaterielDEnchainement.segmentContinu(suite[1])

        let marqueur = MarqueurEspion(refuse: true)
        let enchainement = MaterielDEnchainement.enchainement(
            suite: suite,
            premier: premier,
            chargeur: ChargeurDeTest(segments: [deuxieme]),
            marqueur: marqueur
        )

        await enchainement.avancerA(2000 - hauteurDeLaFenetre, hauteurDeLaFenetre: hauteurDeLaFenetre)
        #expect(await MaterielDEnchainement.attendreLeRuban(de: enchainement, chapitres: 2))

        await enchainement.avancerA(2000 + intercalaire + 10, hauteurDeLaFenetre: hauteurDeLaFenetre)

        #expect(await marqueur.marques.isEmpty)
        #expect(await enchainement.marquageEnAttente)
        #expect(await enchainement.derniereErreurDeMarquage != nil)

        await marqueur.accepterDeNouveau()
        await enchainement.avancerA(2000 + intercalaire + 20, hauteurDeLaFenetre: hauteurDeLaFenetre)

        #expect(await marqueur.marques == [premier.chapitreId])
        #expect(await enchainement.marquageEnAttente == false)
    }

    @Test("La fermeture du lecteur ecrit les marquages encore dus")
    func marquageALaFermeture() async {
        let suite = MaterielDEnchainement.maillons(2)
        let premier = MaterielDEnchainement.segmentContinu(suite[0])
        let deuxieme = MaterielDEnchainement.segmentContinu(suite[1])

        let marqueur = MarqueurEspion(refuse: true)
        let enchainement = MaterielDEnchainement.enchainement(
            suite: suite,
            premier: premier,
            chargeur: ChargeurDeTest(segments: [deuxieme]),
            marqueur: marqueur
        )

        await enchainement.avancerA(2000 - hauteurDeLaFenetre, hauteurDeLaFenetre: hauteurDeLaFenetre)
        #expect(await MaterielDEnchainement.attendreLeRuban(de: enchainement, chapitres: 2))
        await enchainement.avancerA(2000 + intercalaire + 10, hauteurDeLaFenetre: hauteurDeLaFenetre)

        await marqueur.accepterDeNouveau()
        await enchainement.arreter()

        #expect(await marqueur.marques == [premier.chapitreId])
    }

    // MARK: Fin de serie

    @Test("Le bas du dernier chapitre annonce la fin de la serie")
    func finDeLaSerie() async {
        let suite = MaterielDEnchainement.maillons(1)
        let seul = MaterielDEnchainement.segmentContinu(suite[0])

        let marqueur = MarqueurEspion()
        let enchainement = MaterielDEnchainement.enchainement(
            suite: suite,
            premier: seul,
            chargeur: ChargeurDeTest(),
            marqueur: marqueur
        )

        await enchainement.avancerA(2000 - hauteurDeLaFenetre - 1, hauteurDeLaFenetre: hauteurDeLaFenetre)
        #expect(await enchainement.etat == .enLecture(chapitre: seul.chapitreId))

        await enchainement.avancerA(2000 - hauteurDeLaFenetre, hauteurDeLaFenetre: hauteurDeLaFenetre)

        #expect(await enchainement.etat == .finDeLaSerie)
        #expect(await marqueur.marques == [seul.chapitreId])
    }

    @Test("La fin de la serie arrive apres un enchainement, sur le dernier chapitre")
    func finDeLaSerieApresEnchainement() async {
        let suite = MaterielDEnchainement.maillons(2)
        let premier = MaterielDEnchainement.segmentContinu(suite[0])
        let deuxieme = MaterielDEnchainement.segmentContinu(suite[1])

        let marqueur = MarqueurEspion()
        let enchainement = MaterielDEnchainement.enchainement(
            suite: suite,
            premier: premier,
            chargeur: ChargeurDeTest(segments: [deuxieme]),
            marqueur: marqueur
        )

        await enchainement.avancerA(2000 - hauteurDeLaFenetre, hauteurDeLaFenetre: hauteurDeLaFenetre)
        #expect(await MaterielDEnchainement.attendreLeRuban(de: enchainement, chapitres: 2))

        let ruban = await enchainement.ruban
        await enchainement.avancerA(ruban.hauteurTotale - hauteurDeLaFenetre, hauteurDeLaFenetre: hauteurDeLaFenetre)

        #expect(await enchainement.etat == .finDeLaSerie)
        #expect(await marqueur.marques == [premier.chapitreId, deuxieme.chapitreId])
    }

    @Test("Un chapitre etranger a la suite ne declenche aucune fin de serie")
    func aucuneFinSurUneSuiteInconnue() async {
        let orphelin = MaterielDEnchainement.segmentContinu(
            MaillonDeChapitre(id: UUID(), numero: 1, ordreDansSerie: 0)
        )

        let marqueur = MarqueurEspion()
        let enchainement = EnchainementDeChapitres(
            suite: .vide,
            premier: orphelin,
            chargeur: ChargeurDeTest(),
            marqueur: marqueur,
            intercalaire: intercalaire
        )

        await enchainement.avancerA(2000, hauteurDeLaFenetre: hauteurDeLaFenetre)

        #expect(await enchainement.etat == .enLecture(chapitre: orphelin.chapitreId))
        #expect(await marqueur.marques.isEmpty)
    }
}
