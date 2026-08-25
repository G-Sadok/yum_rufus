import Archive
import Core
import CryptoKit
import Foundation
import Testing

/// Couvre les deux criteres de l index persistant : une seconde ouverture qui
/// ne rescanne pas, et un index qui se declare perime des que le fichier source
/// change.
struct CacheDIndexTests {
    // MARK: Critere 1, la seconde ouverture ne rescanne pas

    @Test("La seconde ouverture d une archive TAR ne relit aucun bloc d en tete")
    func secondeOuvertureNeRescannePas() throws {
        let dossier = try DossierDeCacheDeTest()
        let cache = CacheDIndexSurDisque(dossier: dossier.url)
        let archive = ConstructeurDeTar.archiveDeVingtQuatrePages()

        let premiere = SourceEspionne(archive.octets, nom: "tome.cbt")
        let documentInitial = try DocumentTar(source: premiere, cache: cache)
        #expect(documentInitial.indexVenaitDuCache == false)

        // Le balayage touche tous les blocs d en tete. C est ce cout que le
        // cache doit supprimer.
        for numero in 1...24 {
            let enTete = try #require(archive.enTetes[PagesDeTest.nom(numero)])
            #expect(premiere.aTouche(enTete), "l en tete de \(numero) doit etre lu au balayage")
        }

        let seconde = SourceEspionne(archive.octets, nom: "tome.cbt")
        let documentRelu = try DocumentTar(source: seconde, cache: cache)

        #expect(documentRelu.indexVenaitDuCache)
        #expect(documentRelu.nombrePages == 24)

        // Seule l empreinte est lue, soit trois zones de quatre kilo octets.
        #expect(seconde.octetsLus <= 3 * 4096)

        // Les en tetes situes hors des zones echantillonnees ne sont pas touches.
        for numero in [3, 5, 8, 10, 16, 19, 21] {
            let enTete = try #require(archive.enTetes[PagesDeTest.nom(numero)])
            #expect(seconde.aTouche(enTete) == false, "en tete de \(numero) relu sans besoin")
        }
    }

    @Test("Les pages restent lisibles quand l index vient du cache")
    func pagesLisiblesDepuisLeCache() throws {
        let dossier = try DossierDeCacheDeTest()
        let cache = CacheDIndexSurDisque(dossier: dossier.url)
        let archive = ConstructeurDeTar.archiveDeVingtQuatrePages()

        _ = try DocumentTar(source: source(archive), cache: cache)
        let document = try DocumentTar(source: source(archive), cache: cache)

        #expect(document.indexVenaitDuCache)
        for numero in 1...24 {
            #expect(try document.donneesPage(a: numero - 1) == PagesDeTest.contenu(numero))
        }
    }

    @Test("L index survit a la disparition de l instance de cache qui l a ecrit")
    func indexPersisteSurDisque() throws {
        let dossier = try DossierDeCacheDeTest()
        let archive = ConstructeurDeTar.archiveDeVingtQuatrePages()

        _ = try DocumentTar(
            source: source(archive),
            cache: CacheDIndexSurDisque(dossier: dossier.url)
        )

        // Une instance neuve, qui n a rien en memoire, retrouve l index parce
        // qu il est sur disque et non dans le processus.
        let document = try DocumentTar(
            source: source(archive),
            cache: CacheDIndexSurDisque(dossier: dossier.url)
        )

        #expect(document.indexVenaitDuCache)
    }

    @Test("Un fichier sur disque relit son index a la seconde ouverture")
    func fichierSurDisqueRelitSonIndex() throws {
        let dossier = try DossierDeCacheDeTest()
        let cache = CacheDIndexSurDisque(dossier: dossier.url)
        let archive = ConstructeurDeTar.archiveDeVingtQuatrePages()
        let emplacement = dossier.url.appendingPathComponent("tome.cbt")
        try archive.octets.write(to: emplacement)

        #expect(try DocumentTar(contenuDe: emplacement, cache: cache).indexVenaitDuCache == false)
        #expect(try DocumentTar(contenuDe: emplacement, cache: cache).indexVenaitDuCache)
    }

    // MARK: Critere 2, l index est invalide si le fichier source change

    @Test("Un ajout de page perime l index")
    func changementDeTaille() throws {
        let dossier = try DossierDeCacheDeTest()
        let cache = CacheDIndexSurDisque(dossier: dossier.url)

        let avant = ConstructeurDeTar.archiveDeVingtQuatrePages()
        #expect(try DocumentTar(source: source(avant), cache: cache).nombrePages == 24)

        let apres = ConstructeurDeTar.archive((1...25).map { numero in
            EntreeTarDeTest(PagesDeTest.nom(numero), contenu: PagesDeTest.contenu(numero))
        })
        let document = try DocumentTar(source: source(apres), cache: cache)

        #expect(document.indexVenaitDuCache == false)
        #expect(document.nombrePages == 25)
    }

    @Test("Un contenu different a taille egale perime l index")
    func changementDeContenuATailleEgale() throws {
        let dossier = try DossierDeCacheDeTest()
        let cache = CacheDIndexSurDisque(dossier: dossier.url)

        let avant = ConstructeurDeTar.archiveDeVingtQuatrePages()
        _ = try DocumentTar(source: source(avant), cache: cache)

        // Meme nombre de pages, memes noms, memes tailles : seuls les octets de
        // la premiere page changent. La taille du fichier est identique.
        let apres = ConstructeurDeTar.archive((1...24).map { numero in
            EntreeTarDeTest(
                PagesDeTest.nom(numero),
                contenu: PagesDeTest.contenu(numero == 1 ? 99 : numero)
            )
        })
        #expect(apres.octets.count == avant.octets.count)

        let document = try DocumentTar(source: source(apres), cache: cache)

        #expect(document.indexVenaitDuCache == false)
        #expect(try document.donneesPage(a: 0) == PagesDeTest.contenu(99))
    }

    @Test("Un fichier sur disque remplace par un autre perime l index")
    func remplacementDuFichierSurDisque() throws {
        let dossier = try DossierDeCacheDeTest()
        let cache = CacheDIndexSurDisque(dossier: dossier.url)
        let emplacement = dossier.url.appendingPathComponent("tome.cbt")

        try ConstructeurDeTar.archiveDeVingtQuatrePages().octets.write(to: emplacement)
        _ = try DocumentTar(contenuDe: emplacement, cache: cache)

        let remplacante = ConstructeurDeTar.archive((1...12).map { numero in
            EntreeTarDeTest(PagesDeTest.nom(numero), contenu: PagesDeTest.contenu(numero))
        })
        try remplacante.octets.write(to: emplacement)

        let document = try DocumentTar(contenuDe: emplacement, cache: cache)

        #expect(document.indexVenaitDuCache == false)
        #expect(document.nombrePages == 12)
    }

    @Test("Une date de modification differente suffit a changer l empreinte")
    func changementDeDateDeModification() throws {
        let archive = ConstructeurDeTar.archiveDeVingtQuatrePages()
        let octets = OctetsEnMemoire(archive.octets, nom: "tome.cbt")
        let origine = Date(timeIntervalSince1970: 1_700_000_000)

        let avant = try EmpreinteDeConteneur.calculer(pour: octets, dateDeModification: origine)
        let apres = try EmpreinteDeConteneur.calculer(
            pour: octets,
            dateDeModification: origine.addingTimeInterval(1)
        )

        #expect(avant != apres)
    }

    @Test("Deux archives differentes n ont pas la meme empreinte")
    func empreintesDistinctes() throws {
        let premiere = ConstructeurDeTar.archiveDeVingtQuatrePages()
        let seconde = ConstructeurDeTar.archive((1...24).map { numero in
            EntreeTarDeTest(
                PagesDeTest.nom(numero),
                contenu: PagesDeTest.contenu(numero == 24 ? 77 : numero)
            )
        })

        let avant = try EmpreinteDeConteneur.calculer(
            pour: OctetsEnMemoire(premiere.octets, nom: "tome.cbt")
        )
        let apres = try EmpreinteDeConteneur.calculer(
            pour: OctetsEnMemoire(seconde.octets, nom: "tome.cbt")
        )

        #expect(avant != apres)
    }

    // MARK: Resistance du cache

    @Test("Un fichier de cache abime est ignore, pas relu de travers")
    func fichierDeCacheAbime() throws {
        let dossier = try DossierDeCacheDeTest()
        let cache = CacheDIndexSurDisque(dossier: dossier.url)
        let archive = ConstructeurDeTar.archiveDeVingtQuatrePages()

        _ = try DocumentTar(source: source(archive), cache: cache)
        try Data("ceci n est pas du JSON".utf8).write(to: dossier.fichier(pour: "tome.cbt"))

        let document = try DocumentTar(source: source(archive), cache: cache)

        #expect(document.indexVenaitDuCache == false)
        #expect(document.nombrePages == 24)
    }

    @Test("Un index ecrit par une autre version du format est ignore")
    func versionDeFormatDifferente() throws {
        let dossier = try DossierDeCacheDeTest()
        let cache = CacheDIndexSurDisque(dossier: dossier.url)
        let archive = ConstructeurDeTar.archiveDeVingtQuatrePages()

        let document = try DocumentTar(source: source(archive), cache: cache)
        #expect(document.indexVenaitDuCache == false)

        let fichier = dossier.fichier(pour: "tome.cbt")
        let donnees = try Data(contentsOf: fichier)
        let ecrit = try #require(String(data: donnees, encoding: .utf8))
        let perime = ecrit.replacingOccurrences(
            of: "\"version\":\(IndexTar.versionDeFormat)",
            with: "\"version\":\(IndexTar.versionDeFormat + 1)"
        )
        #expect(perime != ecrit, "le fichier de cache doit porter la version du format")
        try Data(perime.utf8).write(to: fichier)

        #expect(try DocumentTar(source: source(archive), cache: cache).indexVenaitDuCache == false)
    }

    @Test("Un cache impossible a ecrire ne bloque pas l ouverture")
    func cacheInutilisable() throws {
        // Un chemin qui traverse un fichier ordinaire ne peut recevoir ni
        // dossier ni fichier. L ouverture doit balayer et reussir quand meme.
        let dossier = try DossierDeCacheDeTest()
        let obstacle = dossier.url.appendingPathComponent("obstacle")
        try Data("fichier".utf8).write(to: obstacle)

        let cache = CacheDIndexSurDisque(dossier: obstacle.appendingPathComponent("index"))
        let archive = ConstructeurDeTar.archiveDeVingtQuatrePages()

        let document = try DocumentTar(source: source(archive), cache: cache)

        #expect(document.indexVenaitDuCache == false)
        #expect(document.nombrePages == 24)
    }

    // MARK: Outils

    private func source(_ archive: ArchiveTarDeTest) -> OctetsEnMemoire {
        OctetsEnMemoire(archive.octets, nom: "tome.cbt")
    }
}

/// Dossier de cache jetable, supprime a la fin du test.
private final class DossierDeCacheDeTest {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("tsuzuki-index-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }

    /// Emplacement ou le cache range l index d une identite donnee.
    ///
    /// La regle de nommage est reproduite ici plutot qu exposee par le paquet :
    /// un test qui inspecte le disque doit dire ou il regarde, et le paquet n a
    /// pas a ouvrir son rangement interne pour cela.
    func fichier(pour identite: String) -> URL {
        let condense = SHA256.hash(data: Data(identite.utf8))
        let nom = condense.map { String(format: "%02x", $0) }.joined()

        return url.appendingPathComponent(nom + ".json")
    }
}
