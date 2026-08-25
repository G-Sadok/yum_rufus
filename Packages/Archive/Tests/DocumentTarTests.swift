import Archive
import Core
import Foundation
import Testing

/// Couvre la lecture d un CBT : enumeration, noms longs, acces direct et
/// conteneurs abimes. Le cache d index a son propre fichier de tests.
struct DocumentTarTests {
    // MARK: Enumeration

    @Test("Un CBT s ouvre et rend ses pages dans l ordre naturel")
    func enumerationOrdonnee() throws {
        let archive = ConstructeurDeTar.archive([
            EntreeTarDeTest("page10.jpg", contenu: PagesDeTest.contenu(10, taille: 32)),
            EntreeTarDeTest("page2.jpg", contenu: PagesDeTest.contenu(2, taille: 32)),
            EntreeTarDeTest("page1.jpg", contenu: PagesDeTest.contenu(1, taille: 32)),
            EntreeTarDeTest("cover.jpg", contenu: PagesDeTest.contenu(99, taille: 32)),
        ])

        let document = try ouvrir(archive)

        #expect(document.nombrePages == 4)
        #expect(try document.toutesLesPages().map(\.nom) == [
            "cover.jpg",
            "page1.jpg",
            "page2.jpg",
            "page10.jpg",
        ])
    }

    @Test("Les entrees parasites, les dossiers et les non images ne sont pas des pages")
    func parasitesEcartes() throws {
        var dossier = EntreeTarDeTest("chapitre/", contenu: Data())
        dossier.typeflag = UInt8(ascii: "5")

        let archive = ConstructeurDeTar.archive([
            dossier,
            EntreeTarDeTest("page1.jpg", contenu: PagesDeTest.contenu(1, taille: 32)),
            EntreeTarDeTest("__MACOSX/page2.jpg", contenu: PagesDeTest.contenu(2, taille: 32)),
            EntreeTarDeTest(".DS_Store", contenu: PagesDeTest.contenu(3, taille: 32)),
            EntreeTarDeTest("Thumbs.db", contenu: PagesDeTest.contenu(4, taille: 32)),
            EntreeTarDeTest("notes.txt", contenu: PagesDeTest.contenu(5, taille: 32)),
            EntreeTarDeTest("ComicInfo.xml", contenu: Data("<ComicInfo/>".utf8)),
        ])

        let document = try ouvrir(archive)

        #expect(document.nombrePages == 1)
        #expect(try document.referencePage(0).nom == "page1.jpg")
    }

    @Test("Une page rend exactement le contenu range dans l archive")
    func contenuFidele() throws {
        let archive = ConstructeurDeTar.archiveDeVingtQuatrePages()
        let document = try ouvrir(archive)

        for numero in 1...24 {
            let reference = try document.referencePage(numero - 1)
            #expect(reference.nom == PagesDeTest.nom(numero))
            #expect(reference.tailleOctets == PagesDeTest.taille)
            #expect(try document.donneesPage(reference) == PagesDeTest.contenu(numero))
        }
    }

    @Test("Une page dont la taille n est pas un multiple de 512 est rendue sans remplissage")
    func tailleNonAlignee() throws {
        let contenu = PagesDeTest.contenu(1, taille: 700)
        let archive = ConstructeurDeTar.archive([
            EntreeTarDeTest("page1.jpg", contenu: contenu),
            EntreeTarDeTest("page2.jpg", contenu: PagesDeTest.contenu(2, taille: 300)),
        ])

        let document = try ouvrir(archive)

        #expect(try document.donneesPage(a: 0) == contenu)
        #expect(try document.donneesPage(a: 1) == PagesDeTest.contenu(2, taille: 300))
    }

    // MARK: Noms longs

    @Test("Un nom long annonce par un bloc GNU remplace le nom tronque")
    func nomLongGNU() throws {
        let nom = String(repeating: "serie-tres-longue/", count: 8) + "page1.jpg"
        var entree = EntreeTarDeTest(nom, contenu: PagesDeTest.contenu(1, taille: 32))
        entree.annonceDuNomLong = .gnu

        let document = try ouvrir(ConstructeurDeTar.archive([entree]))

        #expect(document.nombrePages == 1)
        #expect(try document.referencePage(0).nom == nom)
        #expect(try document.donneesPage(a: 0) == PagesDeTest.contenu(1, taille: 32))
    }

    @Test("Un nom long annonce par un en tete etendu PAX remplace le nom tronque")
    func nomLongPAX() throws {
        let nom = String(repeating: "dossier-profond/", count: 9) + "page1.jpg"
        var entree = EntreeTarDeTest(nom, contenu: PagesDeTest.contenu(1, taille: 32))
        entree.annonceDuNomLong = .pax

        let document = try ouvrir(ConstructeurDeTar.archive([entree]))

        #expect(document.nombrePages == 1)
        #expect(try document.referencePage(0).nom == nom)
        #expect(try document.donneesPage(a: 0) == PagesDeTest.contenu(1, taille: 32))
    }

    @Test("Le prefixe ustar est recolle devant le nom")
    func prefixeUstar() throws {
        let nom = String(repeating: "niveau/", count: 12) + "page1.jpg"
        var entree = EntreeTarDeTest(nom, contenu: PagesDeTest.contenu(1, taille: 32))
        entree.annonceDuNomLong = .prefixeUstar

        let document = try ouvrir(ConstructeurDeTar.archive([entree]))

        #expect(try document.referencePage(0).nom == nom)
    }

    // MARK: Acces direct

    @Test("Lire la page N ne touche aucune autre page")
    func accesDirectALaPage() throws {
        let archive = ConstructeurDeTar.archiveDeVingtQuatrePages()
        let espion = SourceEspionne(archive.octets, nom: "tome.cbt")
        let document = try DocumentTar(source: espion, cache: nil)

        espion.oublier()

        let numero = 7
        let reference = try document.referencePage(numero - 1)
        #expect(try document.donneesPage(reference) == PagesDeTest.contenu(numero))

        let attendue = try #require(archive.plages[PagesDeTest.nom(numero)])
        #expect(espion.aTouche(attendue), "les octets de la page demandee doivent etre lus")

        for autre in 1...24 where autre != numero {
            let plage = try #require(archive.plages[PagesDeTest.nom(autre)])
            #expect(espion.aTouche(plage) == false, "\(PagesDeTest.nom(autre)) ne devait pas etre lue")
        }
    }

    @Test("Le balayage ne lit pas les pages")
    func balayageSansLectureDesPages() throws {
        let archive = ConstructeurDeTar.archiveDeVingtQuatrePages()
        let espion = SourceEspionne(archive.octets, nom: "tome.cbt")
        _ = try DocumentTar(source: espion, cache: nil)

        // Vingt cinq blocs d en tete et trois zones d empreinte, soit environ
        // vingt cinq kilo octets sur une archive qui en fait deux cents. Un
        // balayage qui lirait les pages ferait exploser ce budget.
        #expect(espion.octetsLus < archive.octets.count / 4)

        // Les pages choisies sont hors des trois zones echantillonnees par
        // l empreinte, tete, milieu et queue. Aucune ne doit etre touchee.
        for numero in [3, 5, 8, 10, 16, 19, 21] {
            let plage = try #require(archive.plages[PagesDeTest.nom(numero)])
            #expect(espion.aTouche(plage) == false, "\(PagesDeTest.nom(numero)) lue au balayage")
        }
    }

    // MARK: Metadonnees

    @Test("Le ComicInfo.xml est rendu tel quel")
    func metadonneesRendues() throws {
        let contenu = Data("<ComicInfo><Series>Tsuzuki</Series></ComicInfo>".utf8)
        let archive = ConstructeurDeTar.archive([
            EntreeTarDeTest("page1.jpg", contenu: PagesDeTest.contenu(1, taille: 32)),
            EntreeTarDeTest("ComicInfo.xml", contenu: contenu),
        ])

        #expect(try ouvrir(archive).donneesDeMetadonnees() == contenu)
    }

    @Test("Une archive sans ComicInfo.xml ne rend pas de metadonnees")
    func metadonneesAbsentes() throws {
        let archive = ConstructeurDeTar.archive([
            EntreeTarDeTest("page1.jpg", contenu: PagesDeTest.contenu(1, taille: 32)),
        ])

        #expect(try ouvrir(archive).donneesDeMetadonnees() == nil)
    }

    // MARK: Bornes

    @Test("Une position hors du document est refusee", arguments: [-1, 4, 99])
    func positionHorsBornes(_ position: Int) throws {
        let archive = ConstructeurDeTar.archive((1...4).map { numero in
            EntreeTarDeTest(
                PagesDeTest.nom(numero),
                contenu: PagesDeTest.contenu(numero, taille: 32)
            )
        })
        let document = try ouvrir(archive)

        #expect(throws: ErreurDeDocument.indexHorsBornes(demande: position, nombrePages: 4)) {
            try document.referencePage(position)
        }
    }

    @Test("Une reference etrangere au document est refusee")
    func referenceEtrangere() throws {
        let archive = ConstructeurDeTar.archive([
            EntreeTarDeTest("page1.jpg", contenu: PagesDeTest.contenu(1, taille: 32)),
        ])
        let document = try ouvrir(archive)
        let etrangere = ReferencePage(index: 0, nom: "page1.png", tailleOctets: 32)

        #expect(throws: ErreurDeDocument.entreeIntrouvable(nom: "page1.png")) {
            try document.donneesPage(etrangere)
        }
    }

    // MARK: Conteneurs abimes

    @Test("Un en tete dont la somme de controle est fausse rend le conteneur illisible")
    func sommeDeControleFausse() throws {
        var entree = EntreeTarDeTest("page1.jpg", contenu: PagesDeTest.contenu(1, taille: 32))
        entree.sommeForcee = 1

        #expect(throws: ErreurDeDocument.conteneurIllisible(chemin: "tome.cbt")) {
            try ouvrir(ConstructeurDeTar.archive([entree]))
        }
    }

    @Test("Une entree qui annonce plus d octets que le fichier n en porte est tronquee")
    func tailleQuiDeborde() throws {
        var entree = EntreeTarDeTest("page1.jpg", contenu: PagesDeTest.contenu(1, taille: 32))
        entree.tailleForcee = 1_000_000

        #expect(throws: ErreurDeDocument.conteneurTronque(chemin: "tome.cbt")) {
            try ouvrir(ConstructeurDeTar.archive([entree]))
        }
    }

    @Test("Un fichier qui n est pas un TAR est refuse")
    func fichierQuiNEstPasUnTar() throws {
        let octets = PagesDeTest.contenu(1, taille: 4096)

        #expect(throws: ErreurDeDocument.conteneurIllisible(chemin: "tome.cbt")) {
            try DocumentTar(source: OctetsEnMemoire(octets, nom: "tome.cbt"), cache: nil)
        }
    }

    @Test("Un fichier de zeros est refuse plutot que pris pour une archive vide")
    func fichierDeZeros() throws {
        let octets = Data(count: 10240)

        #expect(throws: ErreurDeDocument.conteneurIllisible(chemin: "tome.cbt")) {
            try DocumentTar(source: OctetsEnMemoire(octets, nom: "tome.cbt"), cache: nil)
        }
    }

    @Test("Un fichier plus court qu un bloc est refuse")
    func fichierTropCourt() throws {
        #expect(throws: ErreurDeDocument.conteneurIllisible(chemin: "tome.cbt")) {
            try DocumentTar(source: OctetsEnMemoire(Data(count: 10), nom: "tome.cbt"), cache: nil)
        }
    }

    @Test("Une archive sans image ne s ouvre pas")
    func aucunePage() throws {
        let archive = ConstructeurDeTar.archive([
            EntreeTarDeTest("notes.txt", contenu: Data("rien".utf8)),
        ])

        #expect(throws: ErreurDeDocument.aucunePage(chemin: "tome.cbt")) {
            try ouvrir(archive)
        }
    }

    @Test("Une archive close par un seul bloc nul se lit quand meme")
    func finSurUnSeulBloc() throws {
        let archive = ConstructeurDeTar.archive(
            [EntreeTarDeTest("page1.jpg", contenu: PagesDeTest.contenu(1, taille: 32))],
            blocsDeFin: 1
        )

        #expect(try ouvrir(archive).nombrePages == 1)
    }

    // MARK: Outils

    /// Ouvre l archive sans cache, pour n eprouver que la lecture du format.
    private func ouvrir(_ archive: ArchiveTarDeTest) throws -> DocumentTar {
        try DocumentTar(
            source: OctetsEnMemoire(archive.octets, nom: "tome.cbt"),
            cache: nil
        )
    }
}
