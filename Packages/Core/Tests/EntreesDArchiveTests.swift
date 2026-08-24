import Core
import Foundation
import Testing

/// Couvre le filtrage des entrees parasites d archive de la section 5.3 du
/// cahier de developpement, et l enchainement filtrage puis tri naturel.
struct EntreesDArchiveTests {
    /// Entrees qui ne doivent jamais atteindre le lecteur.
    static let entreesParasites = [
        "__MACOSX/page1.jpg",
        "__MACOSX/._page1.jpg",
        "chapitre1/__MACOSX/page1.jpg",
        "__MACOSX/",
        ".DS_Store",
        "chapitre1/.DS_Store",
        ".ds_store",
        "Thumbs.db",
        "chapitre1/Thumbs.db",
        "thumbs.db",
        "._page1.jpg",
        ".hidden/page1.jpg",
        ".cache.jpg",
        "chapitre1/",
        "",
    ]

    /// Entrees legitimes, images ou metadonnees.
    static let entreesValides = [
        "page1.jpg",
        "chapitre1/page1.jpg",
        "chapitre1/sous dossier/page1.webp",
        "PAGE1.JPG",
        "ComicInfo.xml",
    ]

    @Test("Les entrees parasites sont reconnues", arguments: entreesParasites)
    func entreeParasiteReconnue(_ entree: String) {
        #expect(EntreesDArchive.estParasite(entree), "\(entree) devrait etre filtree")
    }

    @Test("Les entrees legitimes ne sont pas filtrees", arguments: entreesValides)
    func entreeValideConservee(_ entree: String) {
        #expect(EntreesDArchive.estParasite(entree) == false, "\(entree) ne devrait pas etre filtree")
    }

    @Test("__MACOSX, .DS_Store et Thumbs.db disparaissent de la liste des pages")
    func criterePrincipal() {
        let entrees = [
            "__MACOSX/page1.jpg",
            "page2.jpg",
            ".DS_Store",
            "page1.jpg",
            "Thumbs.db",
            "chapitre1/.DS_Store",
        ]

        #expect(EntreesDArchive.pages(parmi: entrees) == ["page1.jpg", "page2.jpg"])
    }

    @Test("Les pages sortent filtrees et triees naturellement")
    func filtrageEtTri() {
        let entrees = [
            "__MACOSX/._page10.jpg",
            "page10.jpg",
            "Thumbs.db",
            "page2.jpg",
            "ComicInfo.xml",
            ".DS_Store",
            "notes.txt",
            "page1.jpg",
        ]

        #expect(EntreesDArchive.pages(parmi: entrees) == ["page1.jpg", "page2.jpg", "page10.jpg"])
    }

    @Test("Les fichiers non image sont ecartes des pages")
    func fichiersNonImage() {
        let entrees = ["page1.jpg", "lisezmoi.txt", "serie.nfo", "ComicInfo.xml", "police.ttf"]

        #expect(EntreesDArchive.pages(parmi: entrees) == ["page1.jpg"])
    }

    @Test("Les formats image de la section 5.2 sont acceptes")
    func formatsImageAcceptes() {
        let entrees = [
            "a.jpg",
            "b.jpeg",
            "c.png",
            "d.apng",
            "e.gif",
            "f.bmp",
            "g.tif",
            "h.tiff",
            "i.webp",
            "j.avif",
            "k.heic",
            "l.heif",
            "m.jp2",
            "n.jxl",
            "o.svg",
        ]

        for entree in entrees {
            #expect(EntreesDArchive.estImage(entree), "\(entree) devrait etre reconnue comme image")
        }

        #expect(EntreesDArchive.pages(parmi: entrees).count == entrees.count)
    }

    @Test("L extension est reconnue quelle que soit la casse")
    func extensionInsensibleALaCasse() {
        #expect(EntreesDArchive.estImage("PAGE1.JPG"))
        #expect(EntreesDArchive.estImage("page1.WebP"))
    }

    @Test("ComicInfo.xml est repere comme metadonnees et non comme page")
    func metadonneesComicInfo() {
        #expect(EntreesDArchive.estMetadonneesComic("ComicInfo.xml"))
        #expect(EntreesDArchive.estMetadonneesComic("chapitre1/comicinfo.xml"))
        #expect(EntreesDArchive.estMetadonneesComic("autre.xml") == false)
        #expect(EntreesDArchive.estImage("ComicInfo.xml") == false)
        #expect(EntreesDArchive.pages(parmi: ["ComicInfo.xml"]).isEmpty)
    }

    @Test("Le ComicInfo.xml le moins profond est retenu")
    func metadonneesLaMoinsProfonde() {
        let entrees = [
            "chapitre1/ComicInfo.xml",
            "ComicInfo.xml",
            "page1.jpg",
            "__MACOSX/ComicInfo.xml",
        ]

        #expect(EntreesDArchive.metadonneesComic(parmi: entrees) == "ComicInfo.xml")
        #expect(EntreesDArchive.metadonneesComic(parmi: ["page1.jpg"]) == nil)
    }

    @Test("Une archive ne contenant que des parasites ne rend aucune page")
    func archiveEntierementParasite() {
        let entrees = ["__MACOSX/", "__MACOSX/._page1.jpg", ".DS_Store", "Thumbs.db"]

        #expect(EntreesDArchive.pages(parmi: entrees).isEmpty)
    }

    @Test("Les separateurs de chemin de Windows sont traites comme des separateurs")
    func separateurWindows() {
        // Certains outils ecrivent la barre inversee dans l en tete ZIP.
        // Sans cette regle, __MACOSX\\page1.jpg passerait le filtre.
        #expect(EntreesDArchive.estParasite("__MACOSX\\page1.jpg"))
        #expect(EntreesDArchive.estParasite("chapitre1\\Thumbs.db"))
    }
}
