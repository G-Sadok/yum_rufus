import Foundation
import Testing
@testable import Core

//
// Couvre les regles de domaine des signets de page : le saut vers la page
// marquee, l ordre de la liste, et la part signets de la sauvegarde.
//
// Le saut est teste ici et non seulement au dessus de la base, parce que c est
// ici qu il est decide. Un ecran qui ouvrirait la mauvaise page le ferait en
// recomposant sa propre position, ce que ce type existe pour interdire.
//

struct SignetsDePageTests {
    /// Signet d affichage complet, pose sur la page demandee.
    private func signet(
        page: Int,
        nombreDePages: Int = 20,
        serie: String = "Serie",
        chapitre: Double = 1,
        note: String? = nil
    ) -> SignetAffiche {
        SignetAffiche(
            chapitreId: UUID(),
            serieId: UUID(),
            titreDeLaSerie: serie,
            numeroDeChapitre: chapitre,
            pageIndex: page,
            nombreDePages: nombreDePages,
            note: note,
            dateCreation: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    // MARK: Saut vers la page marquee

    @Test("Le saut ouvre le chapitre du signet a la page marquee")
    func sautVersLaPageMarquee() {
        let marque = signet(page: 11)
        let position = marque.position

        #expect(position.chapitreId == marque.chapitreId)
        #expect(position.pageIndex == 11)

        // Un signet designe une page entiere, pas un point dans cette page.
        #expect(position.decalageDeDefilement == 0)
    }

    @Test("Un signet pose sur une page disparue ouvre la derniere page existante")
    func sautBornuParLeChapitre() {
        let marque = signet(page: 40, nombreDePages: 5)

        #expect(marque.position.pageIndex == 4)
    }

    @Test("Un chapitre dont le nombre de pages est inconnu garde l index du signet")
    func sautSansNombreDePages() {
        let marque = signet(page: 30, nombreDePages: 0)

        #expect(marque.position.pageIndex == 30)
    }

    // MARK: Ordre de la liste

    @Test("La liste se range par serie, puis par chapitre, puis par page")
    func ordreDeLaListe() {
        let liste = OrdreDesSignets.trier([
            signet(page: 4, serie: "Berserk", chapitre: 2),
            signet(page: 1, serie: "Akira", chapitre: 10),
            signet(page: 0, serie: "Berserk", chapitre: 2),
            signet(page: 7, serie: "Akira", chapitre: 2),
        ])

        let lu = liste.map { ($0.titreDeLaSerie, $0.numeroDeChapitre, $0.pageIndex) }

        #expect(lu[0] == ("Akira", 2, 7))
        #expect(lu[1] == ("Akira", 10, 1))
        #expect(lu[2] == ("Berserk", 2, 0))
        #expect(lu[3] == ("Berserk", 2, 4))
    }

    @Test("Deux series au numero identique se rangent naturellement, pas alphabetiquement")
    func ordreNaturelDesSeries() {
        let liste = OrdreDesSignets.trier([
            signet(page: 0, serie: "Serie 10"),
            signet(page: 0, serie: "Serie 2"),
        ])

        #expect(liste.map(\.titreDeLaSerie) == ["Serie 2", "Serie 10"])
    }

    @Test("L ordre est total, deux signets par ailleurs egaux ne permutent pas")
    func ordreTotal() {
        let premier = signet(page: 3)
        let second = signet(page: 3)
        let attendu = OrdreDesSignets.trier([premier, second]).map(\.id)

        #expect(OrdreDesSignets.trier([second, premier]).map(\.id) == attendu)
    }

    // MARK: Note

    @Test("Une note d espaces vaut aucune note")
    func noteVide() {
        #expect(OrdreDesSignets.noteNettoyee("   \n ") == nil)
        #expect(OrdreDesSignets.noteNettoyee("") == nil)
        #expect(OrdreDesSignets.noteNettoyee(nil) == nil)
    }

    @Test("Une note garde son texte et perd ses espaces de bordure")
    func noteNettoyee() {
        #expect(OrdreDesSignets.noteNettoyee("  La revelation de Griffith  ") == "La revelation de Griffith")
    }

    @Test("Une page negative ne peut pas porter de signet")
    func pageNegativeRefusee() {
        #expect(throws: ErreurDeSignet.pageInvalide(index: -1)) {
            try OrdreDesSignets.verifierLaPage(-1)
        }

        #expect(throws: Never.self) {
            try OrdreDesSignets.verifierLaPage(0)
        }
    }

    // MARK: Sauvegarde

    /// Signet persiste, tel que la table le porte.
    private func persiste(page: Int, note: String? = nil, vignette: String? = nil) -> Signet {
        Signet(
            chapitreId: UUID(),
            pageIndex: page,
            note: note,
            dateCreation: Date(timeIntervalSince1970: 1_700_000_000),
            vignetteLocale: vignette
        )
    }

    @Test("Un signet exporte puis restaure garde sa page, sa note et sa vignette")
    func allerRetourDeSauvegarde() throws {
        let signet = persiste(page: 12, note: "Le duel", vignette: "abc.jpg")
        let sauvegarde = SauvegardeDesSignets([signet])

        let relue = try SauvegardeDesSignets(donnees: sauvegarde.donnees())
        let restaure = try #require(relue.restaures().first)

        #expect(restaure == signet)
    }

    @Test("La part signets porte sa version")
    func versionDeLaPart() throws {
        let donnees = try SauvegardeDesSignets([persiste(page: 0)]).donnees()
        let relue = try SauvegardeDesSignets(donnees: donnees)

        #expect(relue.version == SauvegardeDesSignets.versionCourante)
    }

    @Test("Une part signets d une autre version se refuse au lieu de se lire de travers")
    func versionInconnueRefusee() throws {
        let future = SauvegardeDesSignets(version: 99, signets: [])
        let donnees = try future.donnees()

        #expect(throws: ErreurDeSauvegarde.formatInconnu(version: 99)) {
            try SauvegardeDesSignets(donnees: donnees)
        }
    }

    @Test("Un fichier qui ne decrit pas des signets se refuse")
    func fichierIllisible() {
        #expect(throws: ErreurDeSauvegarde.fichierIllisible) {
            try SauvegardeDesSignets(donnees: Data([0xAA, 0xBB]))
        }
    }

    @Test("Deux exports d une base inchangee produisent le meme fichier")
    func exportStable() throws {
        let signets = [persiste(page: 3), persiste(page: 1), persiste(page: 8)]

        let premier = try SauvegardeDesSignets(signets).donnees()
        let second = try SauvegardeDesSignets(signets.reversed()).donnees()

        #expect(premier == second)
    }

    @Test("Une note d espaces ne franchit pas la sauvegarde")
    func noteVideNonExportee() {
        let sauvegarde = SauvegardeDesSignets([persiste(page: 2, note: "   ")])

        #expect(sauvegarde.signets.first?.note == nil)
    }
}
