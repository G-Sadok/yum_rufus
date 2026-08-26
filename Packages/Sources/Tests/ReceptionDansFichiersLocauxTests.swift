import Core
import Foundation
import Testing
@testable import Sources

//
// ReceptionDansFichiersLocauxTests
//
// Le troisieme critere de la section 4.4 : ce qui est depose arrive dans la
// source Fichiers locaux.
//
// Le test ne se contente pas de verifier qu un fichier existe sur le disque. Il
// relit la source apres la fermeture de la feuille et y cherche la serie
// deposee, parce que c est ce que l utilisateur constate : un fichier pose dans
// le dossier mais absent de la bibliotheque ne serait pas un depot reussi.
//
// L analyse est demandee une premiere fois avant le depot, a dessein. Sans cela,
// la source relirait le dossier a la premiere demande de toute facon, et le
// test passerait meme si la reception ne relancait jamais l analyse.
//

struct ReceptionDansFichiersLocauxTests {
    private static let codeAffiche = "731905"

    @Test("Un fichier depose apparait dans la source apres la fermeture")
    func fichierDeposeApparaitDansLaSource() async throws {
        let arbre = try ArbreDeTest()
        try BibliothequeDeTest.poser(dans: arbre)

        let environnement = try EnvironnementDeSource(arbre: arbre)
        let source = try environnement.sourcePremierLancement()

        // L analyse est mise en cache ici, avant le depot.
        let avant = try await source.analyse()

        #expect(avant.series.map(\.titre).contains("Tome neuf") == false)

        let ecoute = EcouteSimulee()
        let session = try SessionDeTransfertWifi(
            reception: ReceptionDansFichiersLocaux(source: source),
            ecoute: ecoute,
            code: code()
        )

        try await session.ouvrir()

        let biscuit = try #require(
            try await ecoute.envoyer(RequeteDeTest.presenterLeCode(Self.codeAffiche)).biscuitPose
        )
        let archive = ConstructeurDeZipDeTest.octets([EntreeDeZipDeTest(nom: "page1.jpg", contenu: Data([0xFF]))])
        let depot = try await ecoute.envoyer(
            RequeteDeTest.deposer([(nom: "Tome neuf.cbz", contenu: archive)], biscuit: biscuit)
        )

        #expect(depot.code == 201)
        #expect(depot.corpsContient("Tome neuf.cbz"))

        await session.fermer()

        let apres = try await source.analyse()

        #expect(apres.series.map(\.titre).contains("Tome neuf"))

        let pose = try Data(contentsOf: arbre.racine.appending(path: "Tome neuf.cbz"))

        #expect(pose == archive)
    }

    @Test("Un nom compose ne sort pas du dossier de la source")
    func nomComposeNeSortPasDuDossier() async throws {
        let arbre = try ArbreDeTest()
        let environnement = try EnvironnementDeSource(arbre: arbre)
        let reception = try ReceptionDansFichiersLocaux(source: environnement.sourcePremierLancement())

        let range = try await reception.recevoir(
            nomPropose: "../../Ailleurs/Evade.cbz",
            octets: Data("archive".utf8)
        )

        #expect(range == "Evade.cbz")
        #expect(FileManager.default.fileExists(atPath: arbre.racine.appending(path: "Evade.cbz").path))

        let parent = arbre.racine.deletingLastPathComponent().appending(path: "Evade.cbz")

        #expect(FileManager.default.fileExists(atPath: parent.path) == false)
    }

    @Test("Un doublon ne remplace jamais le fichier deja range")
    func doublonNeRemplacePas() async throws {
        let arbre = try ArbreDeTest()
        let environnement = try EnvironnementDeSource(arbre: arbre)
        let reception = try ReceptionDansFichiersLocaux(source: environnement.sourcePremierLancement())

        let premier = try await reception.recevoir(nomPropose: "Tome 1.cbz", octets: Data("premier".utf8))
        let second = try await reception.recevoir(nomPropose: "Tome 1.cbz", octets: Data("second".utf8))

        #expect(premier == "Tome 1.cbz")
        #expect(second == "Tome 1 (2).cbz")

        let garde = try Data(contentsOf: arbre.racine.appending(path: "Tome 1.cbz"))

        #expect(garde == Data("premier".utf8))
    }

    @Test("Les noms qui ne peuvent pas etre ranges sont refuses")
    func nomsRefuses() throws {
        for nom in ["", "   ", "..", ".cache.cbz", "Tome 1", "dossier/", "Tome:1.cbz"] {
            #expect(throws: ErreurDeTransfert.nomDeFichierRefuse) {
                _ = try ReceptionDansFichiersLocaux.nomAcceptable(nom)
            }
        }
    }

    @Test("Un format qui n est pas un chapitre est refuse en nommant le format")
    func formatRefuse() throws {
        #expect(throws: ErreurDeTransfert.formatNonRecevable(format: "exe")) {
            _ = try ReceptionDansFichiersLocaux.nomAcceptable("Outil.exe")
        }
        #expect(throws: ErreurDeTransfert.formatNonRecevable(format: "txt")) {
            _ = try ReceptionDansFichiersLocaux.nomAcceptable("notes.txt")
        }
    }

    @Test("Les conteneurs connus et les images sont recevables")
    func formatsRecevables() throws {
        for nom in ["Tome 1.cbz", "Tome 1.CBR", "Tome 1.cb7", "Tome 1.pdf", "Tome 1.epub", "page1.jpg", "page1.webp"] {
            #expect(throws: Never.self) {
                _ = try ReceptionDansFichiersLocaux.nomAcceptable(nom)
            }
        }
    }

    @Test("Une reception qui n a rien recu ne relit pas la source")
    func receptionVideNeRelitRien() async throws {
        let arbre = try ArbreDeTest()
        try BibliothequeDeTest.poser(dans: arbre)

        let environnement = try EnvironnementDeSource(arbre: arbre)
        let source = try environnement.sourcePremierLancement()
        let reception = ReceptionDansFichiersLocaux(source: source)

        _ = try await source.analyse()
        try arbre.archive("Ajoute hors reception.cbz", pages: ["page1.jpg"])

        await reception.conclure()

        let apres = try await source.analyse()

        #expect(apres.series.map(\.titre).contains("Ajoute hors reception") == false)
    }

    private func code() throws -> CodeDeTransfert {
        try #require(CodeDeTransfert(Self.codeAffiche))
    }
}
