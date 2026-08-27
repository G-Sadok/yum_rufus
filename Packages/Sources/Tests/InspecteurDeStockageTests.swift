import Core
import Foundation
import Testing
@testable import Sources

//
// Couvre le premier critere : les tailles affichees correspondent aux tailles
// reelles sur disque.
//
// Les tests ecrivent dans un dossier temporaire reel plutot que dans un systeme
// de fichiers simule, pour la meme raison que ceux du depot de chapitres : c est
// exactement ce que le code fera en production, et un simulacre qui repondrait
// des tailles inventees ne prouverait rien sur un critere qui parle du disque.
//
// Le contenu ecrit fait une taille choisie a l octet pres. Une mesure qui
// annonce autre chose que la somme de ce qui a ete ecrit est fausse, et le test
// le dit sans avoir a recopier le calcul de l inspecteur.
//

/// Dossier temporaire efface a la fin de la portee.
struct DossierDeStockageDeTest: ~Copyable {
    let racine: URL
    let telechargements: URL
    let cacheDeChapitres: URL
    let cacheDImages: URL

    init() throws {
        racine = FileManager.default.temporaryDirectory
            .appendingPathComponent("stockage-\(UUID().uuidString)", isDirectory: true)
        telechargements = racine.appendingPathComponent("telechargements", isDirectory: true)
        cacheDeChapitres = racine.appendingPathComponent("conteneurs", isDirectory: true)
        cacheDImages = racine.appendingPathComponent("pages", isDirectory: true)

        for dossier in [telechargements, cacheDeChapitres, cacheDImages] {
            try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        }
    }

    deinit {
        try? FileManager.default.removeItem(at: racine)
    }

    /// Les trois emplacements de la section 15, poses sur ce dossier.
    var emplacements: EmplacementsDuStockage {
        EmplacementsDuStockage(
            telechargements: telechargements,
            cacheDeChapitres: cacheDeChapitres,
            cacheDImages: cacheDImages
        )
    }

    /// Ecrit un fichier de la taille demandee, dossiers intermediaires compris.
    func ecrire(_ octets: Int, dans chemin: String, sous dossier: URL) throws {
        let fichier = dossier.appendingPathComponent(chemin)

        try FileManager.default.createDirectory(
            at: fichier.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(repeating: 0x59, count: octets).write(to: fichier, options: .atomic)
    }
}

struct InspecteurDeStockageTests {
    // MARK: Tailles reelles

    @Test("La taille d une categorie est la somme exacte de ce qui est ecrit")
    func laTailleEstLaSommeDeCeQuiEstEcrit() throws {
        let dossier = try DossierDeStockageDeTest()
        let inspecteur = InspecteurDeStockageSurDisque(emplacements: dossier.emplacements)

        try dossier.ecrire(1200, dans: "a1b2c3", sous: dossier.cacheDImages)
        try dossier.ecrire(800, dans: "d4e5f6", sous: dossier.cacheDImages)

        #expect(inspecteur.octets(de: .cacheDImages) == 2000)
    }

    @Test("La mesure descend dans toute l arborescence, pas seulement au premier niveau")
    func laMesureDescendDansLArborescence() throws {
        let dossier = try DossierDeStockageDeTest()
        let inspecteur = InspecteurDeStockageSurDisque(emplacements: dossier.emplacements)
        let chapitre = UUID()

        try dossier.ecrire(500, dans: "\(chapitre.uuidString)/page-0000", sous: dossier.telechargements)
        try dossier.ecrire(700, dans: "\(chapitre.uuidString)/page-0001", sous: dossier.telechargements)

        #expect(inspecteur.octets(de: .chapitresTelecharges) == 1200)
    }

    @Test("Un dossier absent pese zero et ne fait pas echouer la mesure")
    func leDossierAbsentPeseZero() {
        let racine = FileManager.default.temporaryDirectory
            .appendingPathComponent("absent-\(UUID().uuidString)", isDirectory: true)

        let inspecteur = InspecteurDeStockageSurDisque(
            emplacements: EmplacementsDuStockage(
                telechargements: racine.appendingPathComponent("t"),
                cacheDeChapitres: racine.appendingPathComponent("c"),
                cacheDImages: racine.appendingPathComponent("i")
            )
        )

        #expect(inspecteur.inventaire().octetsTotal == 0)
        #expect(inspecteur.pesages(de: .chapitresTelecharges).isEmpty)
    }

    @Test("L inventaire porte les trois categories, chacune avec sa taille reelle")
    func lInventairePorteLesTroisCategories() throws {
        let dossier = try DossierDeStockageDeTest()
        let inspecteur = InspecteurDeStockageSurDisque(emplacements: dossier.emplacements)

        try dossier.ecrire(100, dans: "\(UUID().uuidString)/page-0000", sous: dossier.telechargements)
        try dossier.ecrire(200, dans: "komga/\(UUID().uuidString)/tome.cbz", sous: dossier.cacheDeChapitres)
        try dossier.ecrire(300, dans: "a1b2", sous: dossier.cacheDImages)

        let inventaire = inspecteur.inventaire()

        #expect(inventaire.octets(de: .chapitresTelecharges) == 100)
        #expect(inventaire.octets(de: .cacheDeChapitres) == 200)
        #expect(inventaire.octets(de: .cacheDImages) == 300)
        #expect(inventaire.octetsTotal == 600)
    }

    @Test("La taille d une categorie est celle de ses postes reunis")
    func laCategorieEstLaSommeDeSesPostes() throws {
        let dossier = try DossierDeStockageDeTest()
        let inspecteur = InspecteurDeStockageSurDisque(emplacements: dossier.emplacements)

        try dossier.ecrire(400, dans: "\(UUID().uuidString)/page-0000", sous: dossier.telechargements)
        try dossier.ecrire(600, dans: "\(UUID().uuidString)/page-0000", sous: dossier.telechargements)

        let pesages = inspecteur.pesages(de: .chapitresTelecharges)

        #expect(pesages.count == 2)
        #expect(pesages.reduce(0) { $0 + $1.octets } == inspecteur.octets(de: .chapitresTelecharges))
    }

    // MARK: Profondeur des elements

    @Test("Un chapitre telecharge est un poste, pas une page")
    func leChapitreEstLePoste() throws {
        let dossier = try DossierDeStockageDeTest()
        let inspecteur = InspecteurDeStockageSurDisque(emplacements: dossier.emplacements)
        let chapitre = UUID()

        try dossier.ecrire(50, dans: "\(chapitre.uuidString)/page-0000", sous: dossier.telechargements)
        try dossier.ecrire(50, dans: "\(chapitre.uuidString)/page-0001", sous: dossier.telechargements)

        let pesages = inspecteur.pesages(de: .chapitresTelecharges)

        #expect(pesages == [PesageSurDisque(nom: chapitre.uuidString, octets: 100)])
    }

    @Test("Le cache de chapitres se liste par source et non par famille de source")
    func leCacheDeChapitresSeListeParSource() throws {
        let dossier = try DossierDeStockageDeTest()
        let inspecteur = InspecteurDeStockageSurDisque(emplacements: dossier.emplacements)
        let premiere = UUID()
        let seconde = UUID()

        try dossier.ecrire(10, dans: "Komga/\(premiere.uuidString)/tome.cbz", sous: dossier.cacheDeChapitres)
        try dossier.ecrire(20, dans: "Opds/\(seconde.uuidString)/tome.cbz", sous: dossier.cacheDeChapitres)

        let noms = Set(inspecteur.pesages(de: .cacheDeChapitres).map(\.nom))

        // Deux serveurs de familles differentes restent deux lignes. Les
        // reunir sous leur famille ferait vider le cache d un serveur que
        // l utilisateur ne visait pas.
        #expect(noms == [premiere.uuidString, seconde.uuidString])
    }

    // MARK: Suppression selective

    @Test("Supprimer un poste laisse les autres intacts")
    func laSuppressionEstSelective() throws {
        let dossier = try DossierDeStockageDeTest()
        let inspecteur = InspecteurDeStockageSurDisque(emplacements: dossier.emplacements)
        let garde = UUID()
        let parte = UUID()

        try dossier.ecrire(400, dans: "\(garde.uuidString)/page-0000", sous: dossier.telechargements)
        try dossier.ecrire(600, dans: "\(parte.uuidString)/page-0000", sous: dossier.telechargements)

        try inspecteur.supprimer([parte.uuidString], de: .chapitresTelecharges)

        #expect(inspecteur.octets(de: .chapitresTelecharges) == 400)
        #expect(inspecteur.pesages(de: .chapitresTelecharges).map(\.nom) == [garde.uuidString])
    }

    @Test("Un nom que la mesure n a pas vu ne peut rien supprimer")
    func leNomInconnuEstRefuse() throws {
        let dossier = try DossierDeStockageDeTest()
        let inspecteur = InspecteurDeStockageSurDisque(emplacements: dossier.emplacements)

        try dossier.ecrire(100, dans: "a1b2", sous: dossier.cacheDImages)

        #expect(throws: ErreurDeStockage.elementInconnu(nom: "../../etc")) {
            try inspecteur.supprimer(["../../etc"], de: .cacheDImages)
        }

        #expect(inspecteur.octets(de: .cacheDImages) == 100)
    }

    @Test("Vider une categorie entiere la ramene a zero octet")
    func viderUneCategorie() throws {
        let dossier = try DossierDeStockageDeTest()
        let inspecteur = InspecteurDeStockageSurDisque(emplacements: dossier.emplacements)

        try dossier.ecrire(100, dans: "a1b2", sous: dossier.cacheDImages)
        try dossier.ecrire(200, dans: "c3d4", sous: dossier.cacheDImages)

        let noms = inspecteur.pesages(de: .cacheDImages).map(\.nom)
        try inspecteur.supprimer(noms, de: .cacheDImages)

        #expect(inspecteur.octets(de: .cacheDImages) == 0)
    }

    @Test("Supprimer un chapitre absent n est pas une erreur")
    func leChapitreAbsentNEstPasUneErreur() throws {
        let dossier = try DossierDeStockageDeTest()
        let inspecteur = InspecteurDeStockageSurDisque(emplacements: dossier.emplacements)

        #expect(try inspecteur.supprimerLeChapitre(UUID()) == false)
    }
}
