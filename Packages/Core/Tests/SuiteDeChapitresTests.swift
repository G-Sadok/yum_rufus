import Foundation
import Testing
@testable import Core

//
// Couvre l ordre narratif suivi par l enchainement, section 7.4.
//
// Le piege est toujours le meme : suivre le numero ou l ordre de la liste
// affichee plutot que le rang. Une source qui numerote mal, un chapitre bonus
// en 10.5, ou une fiche triee en ordre decroissant suffisent alors a faire
// enchainer le lecteur vers le chapitre precedent.
//

struct SuiteDeChapitresTests {
    private func maillon(numero: Double, rang: Int) -> MaillonDeChapitre {
        MaillonDeChapitre(id: UUID(), numero: numero, ordreDansSerie: rang, nombreDePages: 20)
    }

    @Test("La suite se lit dans l ordre des rangs, quel que soit l ordre recu")
    func ordreParRang() {
        let premier = maillon(numero: 1, rang: 0)
        let deuxieme = maillon(numero: 2, rang: 1)
        let troisieme = maillon(numero: 3, rang: 2)

        let suite = SuiteDeChapitres([troisieme, premier, deuxieme])

        #expect(suite.maillons.map(\.id) == [premier.id, deuxieme.id, troisieme.id])
    }

    @Test("Le chapitre suivant est celui du rang suivant, pas celui du numero suivant")
    func suivantIgnoreLeNumero() {
        // Une source qui numerote a l envers, cas courant des catalogues qui
        // exposent le dernier chapitre en premier.
        let ouverture = MaillonDeChapitre(id: UUID(), numero: 30, ordreDansSerie: 0)
        let suite = MaillonDeChapitre(id: UUID(), numero: 12, ordreDansSerie: 1)
        let fin = MaillonDeChapitre(id: UUID(), numero: 7, ordreDansSerie: 2)

        let chapitres = SuiteDeChapitres([ouverture, suite, fin])

        #expect(chapitres.suivant(de: ouverture.id)?.id == suite.id)
        #expect(chapitres.suivant(de: suite.id)?.id == fin.id)
        #expect(chapitres.suivant(de: fin.id) == nil)
    }

    @Test("Un chapitre bonus garde sa place quand deux chapitres partagent un rang")
    func bonusEntreDeuxChapitres() {
        let dix = MaillonDeChapitre(id: UUID(), numero: 10, ordreDansSerie: 9)
        let bonus = MaillonDeChapitre(id: UUID(), numero: 10.5, ordreDansSerie: 9)
        let onze = MaillonDeChapitre(id: UUID(), numero: 11, ordreDansSerie: 10)

        let suite = SuiteDeChapitres([onze, bonus, dix])

        #expect(suite.maillons.map(\.id) == [dix.id, bonus.id, onze.id])
        #expect(suite.suivant(de: dix.id)?.id == bonus.id)
        #expect(suite.suivant(de: bonus.id)?.id == onze.id)
    }

    @Test("Le chapitre precedent remonte d un rang, et s arrete au premier")
    func precedent() {
        let premier = maillon(numero: 1, rang: 0)
        let deuxieme = maillon(numero: 2, rang: 1)
        let suite = SuiteDeChapitres([premier, deuxieme])

        #expect(suite.precedent(de: deuxieme.id)?.id == premier.id)
        #expect(suite.precedent(de: premier.id) == nil)
    }

    @Test("Seul le dernier chapitre connu est le dernier de la serie")
    func dernierDeLaSerie() {
        let premier = maillon(numero: 1, rang: 0)
        let dernier = maillon(numero: 2, rang: 1)
        let suite = SuiteDeChapitres([premier, dernier])

        #expect(suite.estLeDernier(dernier.id))
        #expect(suite.estLeDernier(premier.id) == false)
    }

    @Test("Un chapitre etranger a la suite n en est pas le dernier")
    func chapitreEtranger() {
        let suite = SuiteDeChapitres([maillon(numero: 1, rang: 0)])
        let etranger = UUID()

        #expect(suite.estLeDernier(etranger) == false)
        #expect(suite.suivant(de: etranger) == nil)
        #expect(suite.rang(de: etranger) == nil)
    }

    @Test("Un identifiant recu deux fois n apparait qu une fois")
    func doublonEcarte() {
        let identifiant = UUID()
        let premier = MaillonDeChapitre(id: identifiant, numero: 1, ordreDansSerie: 0)
        let doublon = MaillonDeChapitre(id: identifiant, numero: 1, ordreDansSerie: 5)

        let suite = SuiteDeChapitres([premier, doublon])

        #expect(suite.nombreDeChapitres == 1)
        #expect(suite.estLeDernier(identifiant))
    }

    @Test("La suite se construit depuis les lignes de la fiche de serie")
    func depuisLaFiche() {
        let deuxieme = ChapitreDeFiche(
            id: UUID(),
            numero: 2,
            nombrePages: 18,
            ordreDansSerie: 1
        )
        let premier = ChapitreDeFiche(
            id: UUID(),
            numero: 1,
            nombrePages: 24,
            ordreDansSerie: 0
        )

        let suite = SuiteDeChapitres(chapitres: [deuxieme, premier])

        #expect(suite.maillons.map(\.id) == [premier.id, deuxieme.id])
        #expect(suite.maillon(de: premier.id)?.nombreDePages == 24)
    }

    @Test("Seuls les modes verticaux enchainent les chapitres tout seuls")
    func modesQuiEnchainent() {
        #expect(MiseEnPage.continuVertical.enchaineAutomatiquement)
        #expect(MiseEnPage.pageUnique.enchaineAutomatiquement == false)
        #expect(MiseEnPage.doublePage.enchaineAutomatiquement == false)
    }
}
