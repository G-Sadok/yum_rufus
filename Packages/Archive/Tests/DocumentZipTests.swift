import Archive
import Core
import Foundation
import Testing

/// Couvre l ouverture d un CBZ, l ordre des pages et l acces direct a la page N,
/// soit les deux premiers criteres de la fonctionnalite de lecture ZIP.
struct DocumentZipTests {
    // MARK: Enumeration

    @Test("Un CBZ s ouvre et rend ses pages dans l ordre naturel")
    func enumerationOrdonnee() throws {
        let archive = ConstructeurDeZip.archive([
            EntreeDeTest("page10.jpg", contenu: PagesDeTest.contenu(10, taille: 32)),
            EntreeDeTest("page2.jpg", contenu: PagesDeTest.contenu(2, taille: 32)),
            EntreeDeTest("page1.jpg", contenu: PagesDeTest.contenu(1, taille: 32)),
            EntreeDeTest("cover.jpg", contenu: PagesDeTest.contenu(99, taille: 32)),
        ])

        let document = try DocumentZip(source: OctetsEnMemoire(archive.octets, nom: "tome.cbz"))

        #expect(document.nombrePages == 4)
        #expect(try document.toutesLesPages().map(\.nom) == [
            "cover.jpg",
            "page1.jpg",
            "page2.jpg",
            "page10.jpg",
        ])
    }

    @Test("Les entrees parasites et non image ne sont pas des pages")
    func parasitesEcartes() throws {
        let archive = ConstructeurDeZip.archive([
            EntreeDeTest("page1.jpg", contenu: PagesDeTest.contenu(1, taille: 32)),
            EntreeDeTest("__MACOSX/page2.jpg", contenu: PagesDeTest.contenu(2, taille: 32)),
            EntreeDeTest(".DS_Store", contenu: PagesDeTest.contenu(3, taille: 32)),
            EntreeDeTest("Thumbs.db", contenu: PagesDeTest.contenu(4, taille: 32)),
            EntreeDeTest("notes.txt", contenu: PagesDeTest.contenu(5, taille: 32)),
            EntreeDeTest("ComicInfo.xml", contenu: Data("<ComicInfo/>".utf8)),
        ])

        let document = try DocumentZip(source: OctetsEnMemoire(archive.octets, nom: "tome.cbz"))

        #expect(document.nombrePages == 1)
        #expect(try document.referencePage(0).nom == "page1.jpg")
    }

    @Test("Une page rend exactement le contenu range dans l archive")
    func contenuFidele() throws {
        let archive = PagesDeTest.archiveDeVingtQuatrePages()
        let document = try DocumentZip(source: OctetsEnMemoire(archive.octets, nom: "tome.cbz"))

        for numero in 1...24 {
            let reference = try document.referencePage(numero - 1)
            #expect(reference.nom == PagesDeTest.nom(numero))
            #expect(reference.tailleOctets == PagesDeTest.taille)
            #expect(try document.donneesPage(reference) == PagesDeTest.contenu(numero))
        }
    }

    @Test("Une page compressee en deflate est rendue telle qu elle a ete rangee")
    func contenuCompresse() throws {
        let archive = ConstructeurDeZip.archive([
            EntreeDeTest("page1.jpg", contenu: PagesDeTest.contenuRepetitif(7), compresser: true),
            EntreeDeTest("page2.jpg", contenu: PagesDeTest.contenu(2)),
            EntreeDeTest("page3.jpg", contenu: PagesDeTest.contenuRepetitif(9), compresser: true),
        ])

        let document = try DocumentZip(source: OctetsEnMemoire(archive.octets, nom: "tome.cbz"))

        #expect(try document.donneesPage(a: 0) == PagesDeTest.contenuRepetitif(7))
        #expect(try document.donneesPage(a: 1) == PagesDeTest.contenu(2))
        #expect(try document.donneesPage(a: 2) == PagesDeTest.contenuRepetitif(9))
    }

    // MARK: Acces direct

    @Test("Lire la page N ne touche aucune autre page")
    func accesDirectALaPage() throws {
        let archive = PagesDeTest.archiveDeVingtQuatrePages()
        let espion = SourceEspionne(archive.octets, nom: "tome.cbz")
        let document = try DocumentZip(source: espion)

        // Ce qui a ete lu pour ouvrir l archive ne regarde pas ce test.
        espion.oublier()

        let numero = 3
        let reference = try document.referencePage(numero - 1)
        #expect(try document.donneesPage(reference) == PagesDeTest.contenu(numero))

        let attendue = try #require(archive.plages[PagesDeTest.nom(numero)])
        #expect(espion.aTouche(attendue), "les octets de la page demandee doivent etre lus")

        for autre in 1...24 where autre != numero {
            let plage = try #require(archive.plages[PagesDeTest.nom(autre)])
            #expect(espion.aTouche(plage) == false, "\(PagesDeTest.nom(autre)) ne devait pas etre lue")
        }
    }

    @Test("Lire la page N ne coute que la page N")
    func coutDeLAccesDirect() throws {
        let archive = PagesDeTest.archiveDeVingtQuatrePages()
        let espion = SourceEspionne(archive.octets, nom: "tome.cbz")
        let document = try DocumentZip(source: espion)

        espion.oublier()
        _ = try document.donneesPage(a: 23)

        // La page, son en tete local, et rien de plus. Une implementation qui
        // deroulerait l archive depuis le debut lirait vingt quatre fois cela.
        #expect(espion.octetsLus < PagesDeTest.taille * 2)
    }

    @Test("L ouverture ne lit pas les pages")
    func ouvertureSansLectureDesPages() throws {
        let archive = PagesDeTest.archiveDeVingtQuatrePages()
        let espion = SourceEspionne(archive.octets, nom: "tome.cbz")
        _ = try DocumentZip(source: espion)

        #expect(espion.octetsLus < archive.octets.count)

        // La fin du fichier est lue pour trouver l index central, ce qui couvre
        // les dernieres pages. Les premieres, elles, ne doivent jamais l etre.
        for numero in 1...14 {
            let plage = try #require(archive.plages[PagesDeTest.nom(numero)])
            #expect(espion.aTouche(plage) == false, "\(PagesDeTest.nom(numero)) lue a l ouverture")
        }
    }

    // MARK: Metadonnees

    @Test("Le ComicInfo.xml est rendu tel quel")
    func metadonneesRendues() throws {
        let contenu = Data("<ComicInfo><Series>Tsuzuki</Series></ComicInfo>".utf8)
        let archive = ConstructeurDeZip.archive([
            EntreeDeTest("page1.jpg", contenu: PagesDeTest.contenu(1, taille: 32)),
            EntreeDeTest("ComicInfo.xml", contenu: contenu),
        ])

        let document = try DocumentZip(source: OctetsEnMemoire(archive.octets, nom: "tome.cbz"))

        #expect(try document.donneesDeMetadonnees() == contenu)
    }

    @Test("Une archive sans ComicInfo.xml ne rend pas de metadonnees")
    func metadonneesAbsentes() throws {
        let archive = ConstructeurDeZip.archive([
            EntreeDeTest("page1.jpg", contenu: PagesDeTest.contenu(1, taille: 32)),
        ])

        let document = try DocumentZip(source: OctetsEnMemoire(archive.octets, nom: "tome.cbz"))

        #expect(try document.donneesDeMetadonnees() == nil)
    }

    @Test("Le commentaire de l archive est expose")
    func commentaireExpose() throws {
        let archive = ConstructeurDeZip.archive(
            [EntreeDeTest("page1.jpg", contenu: PagesDeTest.contenu(1, taille: 32))],
            commentaire: "{\"appID\":\"test\"}"
        )

        let document = try DocumentZip(source: OctetsEnMemoire(archive.octets, nom: "tome.cbz"))

        #expect(document.commentaireDeConteneur == "{\"appID\":\"test\"}")
    }

    // MARK: Bornes

    @Test("Une position hors du document est refusee", arguments: [-1, 4, 99])
    func positionHorsBornes(_ position: Int) throws {
        let archive = ConstructeurDeZip.archive((1...4).map { numero in
            EntreeDeTest(PagesDeTest.nom(numero), contenu: PagesDeTest.contenu(numero, taille: 32))
        })
        let document = try DocumentZip(source: OctetsEnMemoire(archive.octets, nom: "tome.cbz"))

        #expect(throws: ErreurDeDocument.indexHorsBornes(demande: position, nombrePages: 4)) {
            try document.referencePage(position)
        }
    }

    @Test("Une reference etrangere au document est refusee")
    func referenceEtrangere() throws {
        let archive = ConstructeurDeZip.archive([
            EntreeDeTest("page1.jpg", contenu: PagesDeTest.contenu(1, taille: 32)),
        ])
        let document = try DocumentZip(source: OctetsEnMemoire(archive.octets, nom: "tome.cbz"))
        let etrangere = ReferencePage(index: 0, nom: "page1.png", tailleOctets: 32)

        #expect(throws: ErreurDeDocument.entreeIntrouvable(nom: "page1.png")) {
            try document.donneesPage(etrangere)
        }
    }
}
