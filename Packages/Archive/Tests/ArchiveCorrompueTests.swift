import Archive
import Core
import Foundation
import Testing

/// Couvre le troisieme critere de la fonctionnalite : une archive cassee produit
/// une erreur typee et jamais un plantage.
///
/// Chaque test casse l archive d une facon precise et nomme l erreur attendue.
/// Un test qui se contenterait de verifier qu une erreur est levee laisserait
/// passer une confusion entre une archive tronquee et une page endommagee, et
/// c est cette distinction qui decide du message montre a l utilisateur.
struct ArchiveCorrompueTests {
    private static let nom = "tome.cbz"

    private func document(_ octets: Data) throws -> DocumentZip {
        try DocumentZip(source: OctetsEnMemoire(octets, nom: Self.nom))
    }

    // MARK: Conteneur inexploitable

    @Test("Un fichier vide n est pas une archive")
    func fichierVide() {
        #expect(throws: ErreurDeDocument.conteneurIllisible(chemin: Self.nom)) {
            try document(Data())
        }
    }

    @Test("Un fichier qui n est pas un ZIP est refuse")
    func fichierQuelconque() {
        let octets = Data((0..<5000).map { UInt8(truncatingIfNeeded: $0 &* 7) })

        #expect(throws: ErreurDeDocument.conteneurIllisible(chemin: Self.nom)) {
            try document(octets)
        }
    }

    @Test("Un fichier trop court pour porter un enregistrement de fin est refuse")
    func fichierMinuscule() {
        #expect(throws: ErreurDeDocument.conteneurIllisible(chemin: Self.nom)) {
            try document(Data([0x50, 0x4B, 0x03, 0x04]))
        }
    }

    @Test("Une archive tronquee leve une erreur de document", arguments: [1, 10, 40, 60, 75, 90, 99])
    func archiveTronquee(_ pourcentage: Int) throws {
        let archive = ConstructeurDeZip.archive((1...6).map { numero in
            EntreeDeTest(PagesDeTest.nom(numero), contenu: PagesDeTest.contenu(numero, taille: 512))
        })
        let longueur = archive.octets.count * pourcentage / 100
        let tronquee = archive.octets.prefix(longueur)

        // Le resultat attendu n est pas un cas precis : selon l endroit de la
        // coupe, l archive devient illisible ou tronquee. Ce que ce test tient,
        // c est qu aucune coupe ne fait sortir autre chose qu une erreur de
        // document, et surtout pas un plantage.
        do {
            let ouvert = try document(Data(tronquee))
            for index in 0..<ouvert.nombrePages {
                _ = try ouvert.donneesPage(a: index)
            }
            Issue.record("La coupe a \(pourcentage) pour cent aurait du echouer")
        } catch is ErreurDeDocument {
            // Comportement attendu.
        }
    }

    @Test("Une archive sans image n est pas un chapitre")
    func archiveSansImage() {
        let archive = ConstructeurDeZip.archive([
            EntreeDeTest("ComicInfo.xml", contenu: Data("<ComicInfo/>".utf8)),
            EntreeDeTest("notes.txt", contenu: Data("rien".utf8)),
        ])

        #expect(throws: ErreurDeDocument.aucunePage(chemin: Self.nom)) {
            try document(archive.octets)
        }
    }

    @Test("Une archive sans aucune entree n est pas un chapitre")
    func archiveSansEntree() {
        let archive = ConstructeurDeZip.archive([])

        #expect(throws: ErreurDeDocument.aucunePage(chemin: Self.nom)) {
            try document(archive.octets)
        }
    }

    // MARK: Page endommagee

    @Test("Une somme de controle fausse signale une page endommagee")
    func sommeDeControleFausse() throws {
        var entree = EntreeDeTest("page1.jpg", contenu: PagesDeTest.contenu(1, taille: 512))
        entree.crcForce = 0xDEAD_BEEF
        let archive = ConstructeurDeZip.archive([entree])
        let ouvert = try document(archive.octets)

        #expect(throws: ErreurDeDocument.entreeCorrompue(nom: "page1.jpg")) {
            try ouvert.donneesPage(a: 0)
        }
    }

    @Test("Une taille decompressee mensongere signale une page endommagee")
    func tailleMensongere() throws {
        var entree = EntreeDeTest("page1.jpg", contenu: PagesDeTest.contenu(1, taille: 512))
        entree.tailleDecompresseeForcee = 4096
        let archive = ConstructeurDeZip.archive([entree])
        let ouvert = try document(archive.octets)

        #expect(throws: ErreurDeDocument.entreeCorrompue(nom: "page1.jpg")) {
            try ouvert.donneesPage(a: 0)
        }
    }

    @Test("Un flux deflate invalide signale une page endommagee")
    func fluxDeflateInvalide() throws {
        var entree = EntreeDeTest("page1.jpg", contenu: PagesDeTest.contenu(1, taille: 512), compresser: true)
        entree.octetsForces = Data(repeating: 0xFF, count: 64)
        let archive = ConstructeurDeZip.archive([entree])
        let ouvert = try document(archive.octets)

        #expect(throws: ErreurDeDocument.entreeCorrompue(nom: "page1.jpg")) {
            try ouvert.donneesPage(a: 0)
        }
    }

    @Test("Un en tete local efface signale une page endommagee")
    func enTeteLocalEfface() throws {
        let archive = ConstructeurDeZip.archive([
            EntreeDeTest("page1.jpg", contenu: PagesDeTest.contenu(1, taille: 512)),
        ])
        var octets = archive.octets
        octets.replaceSubrange(0..<4, with: [0, 0, 0, 0])
        let ouvert = try document(octets)

        #expect(throws: ErreurDeDocument.entreeCorrompue(nom: "page1.jpg")) {
            try ouvert.donneesPage(a: 0)
        }
    }

    @Test("Une entree qui deborde du fichier signale une archive tronquee")
    func entreeQuiDeborde() throws {
        var entree = EntreeDeTest("page1.jpg", contenu: PagesDeTest.contenu(1, taille: 512))
        entree.tailleCompresseeForcee = 100_000
        let archive = ConstructeurDeZip.archive([entree])
        let ouvert = try document(archive.octets)

        #expect(throws: ErreurDeDocument.conteneurTronque(chemin: Self.nom)) {
            try ouvert.donneesPage(a: 0)
        }
    }

    // MARK: Ce qui n est pas pris en charge

    @Test("Une methode de compression inconnue est nommee")
    func methodeInconnue() throws {
        var entree = EntreeDeTest("page1.jpg", contenu: PagesDeTest.contenu(1, taille: 512))
        entree.methodeForcee = 93
        let archive = ConstructeurDeZip.archive([entree])
        let ouvert = try document(archive.octets)

        #expect(throws: ErreurDeDocument.compressionNonPriseEnCharge(nom: "page1.jpg", methode: 93)) {
            try ouvert.donneesPage(a: 0)
        }
    }

    @Test("Une entree chiffree est refusee sans etre tentee")
    func entreeChiffree() throws {
        var entree = EntreeDeTest("page1.jpg", contenu: PagesDeTest.contenu(1, taille: 512))
        entree.drapeauxForces = 0x0801
        let archive = ConstructeurDeZip.archive([entree])
        let ouvert = try document(archive.octets)

        #expect(throws: ErreurDeDocument.conteneurChiffre(chemin: Self.nom)) {
            try ouvert.donneesPage(a: 0)
        }
    }

    // MARK: Message rendu

    @Test("Chaque erreur porte un message qui nomme la cause")
    func messagesUtilisateur() {
        let erreurs: [ErreurDeDocument] = [
            .fichierIntrouvable(chemin: "/series/tome.cbz"),
            .conteneurIllisible(chemin: "/series/tome.cbz"),
            .conteneurTronque(chemin: "/series/tome.cbz"),
            .aucunePage(chemin: "/series/tome.cbz"),
            .indexHorsBornes(demande: 9, nombrePages: 4),
            .entreeIntrouvable(nom: "page1.jpg"),
            .entreeCorrompue(nom: "page1.jpg"),
            .compressionNonPriseEnCharge(nom: "page1.jpg", methode: 93),
            .conteneurChiffre(chemin: "/series/tome.cbz"),
        ]

        for erreur in erreurs {
            #expect(erreur.messageUtilisateur.isEmpty == false)

            // Un chemin complet dans un message d erreur revele le nom de
            // l utilisateur et celui de ses series. Seul le nom du fichier sort.
            #expect(erreur.messageUtilisateur.contains("/series/") == false)
        }
    }
}
