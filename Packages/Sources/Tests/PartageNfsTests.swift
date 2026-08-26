import Core
import Foundation
import Testing
@testable import Sources

//
// PartageNfsTests
//
// Le client NFS version trois, verifie contre un serveur qui decode reellement
// ce qu on lui envoie.
//
// L encodage XDR est teste a part, et pas seulement a travers le client. Le
// remplissage sur quatre octets est la faute qui decale tout ce qui suit sans
// rien casser tout de suite : une chaine de cinq octets ecrite sans bourrage
// donne un appel que le serveur lit de travers a partir du champ suivant, et le
// symptome apparait trois champs plus loin, sur une valeur qui n a rien a voir.
//

struct PartageNfsTests {
    static func serveur(
        archive: ArchiveSynthetique = ArchiveSynthetique(nombreDePages: 5, octetsParPage: 128 * 1024)
    ) -> CanalNfsDeTest {
        CanalNfsDeTest(arbre: [
            "": .dossier,
            "Berserk": .dossier,
            "Berserk/Tome 01.cbz": .fichier(.archive(archive)),
            "Vinland Saga": .dossier,
            "Vinland Saga/page01.jpg": .fichier(.memoire(Data(repeating: 9, count: 120))),
        ])
    }

    static func partage(sur canal: CanalNfsDeTest) -> PartageNfs {
        PartageNfs(libelle: "Export NFS", export: "/export", canalNfs: canal, canalMontage: canal)
    }

    // MARK: Montage et parcours

    @Test("Le montage rend la racine, et la racine se liste")
    func montageEtListage() async throws {
        let canal = Self.serveur()
        let partage = Self.partage(sur: canal)

        let racine = try await partage.lister("")

        // La verification sort de la macro : `allSatisfy` y est vu comme
        // pouvant lever, et la forme qui compile a l interieur est justement
        // celle que SwiftFormat reecrit en chemin de cle.
        let toutesDesDossiers = racine.allSatisfy(\.estDossier)

        #expect(racine.map(\.nom) == ["Berserk", "Vinland Saga"])
        #expect(toutesDesDossiers)

        // Le premier appel est le montage, les suivants sont des appels NFS.
        let procedures = await canal.procedures

        #expect(procedures.first == 1)
        #expect(procedures.contains(17))
    }

    @Test("Le dossier lui meme et son parent ne deviennent jamais des series")
    func entreesDeNavigationEcartees() async throws {
        let canal = Self.serveur()
        let partage = Self.partage(sur: canal)

        let entrees = try await partage.lister("Berserk")

        #expect(entrees.map(\.nom) == ["Tome 01.cbz"])
        #expect(entrees.contains { $0.nom == "." } == false)
        #expect(entrees.contains { $0.nom == ".." } == false)
    }

    @Test("Un export inconnu est refuse au montage")
    func exportInconnu() async throws {
        let canal = Self.serveur()
        let partage = PartageNfs(
            libelle: "Export NFS",
            export: "/inexistant",
            canalNfs: canal,
            canalMontage: canal
        )

        await #expect(throws: ErreurReseau.accesRefuse) {
            _ = try await partage.lister("")
        }
    }

    @Test("Le repertoire de ports rend le port du service de montage")
    func portDuMontage() async throws {
        let canal = Self.serveur()
        let port = try await PartageNfs.portDuService(100_005, version: 3, client: ClientRpc(canal: canal))

        #expect(port == 20048)
    }

    // MARK: Attributs et lecture

    @Test("Les attributs d un fichier donnent son type et sa taille")
    func attributsDUnFichier() async throws {
        let archive = ArchiveSynthetique(nombreDePages: 5, octetsParPage: 128 * 1024)
        let canal = Self.serveur(archive: archive)
        let partage = Self.partage(sur: canal)

        let attributs = try await partage.attributs(de: "Berserk/Tome 01.cbz")

        #expect(attributs.estDossier == false)
        #expect(attributs.taille == archive.taille)
        #expect(attributs.dateModification != nil)
    }

    @Test("Un chemin qui ne designe rien est nomme introuvable")
    func cheminIntrouvable() async throws {
        let partage = Self.partage(sur: Self.serveur())

        await #expect(throws: ErreurReseau.ressourceIntrouvable) {
            _ = try await partage.attributs(de: "Berserk/Absent.cbz")
        }
    }

    @Test("Une lecture rend exactement la plage demandee")
    func lectureDUnePlage() async throws {
        let partage = Self.partage(sur: Self.serveur())
        let octets = try await partage.lire("Vinland Saga/page01.jpg", a: 20, longueur: 30)

        #expect(octets == Data(repeating: 9, count: 30))
    }

    @Test("Un CBZ pose sur un export NFS se lit en flux, sans copie complete")
    func lectureEnFlux() async throws {
        let archive = ArchiveSynthetique(nombreDePages: 8, octetsParPage: 256 * 1024)
        let canal = Self.serveur(archive: archive)
        let partage = Self.partage(sur: canal)

        let conteneur = ConteneurDePartage(
            partage: partage,
            chemin: "Berserk/Tome 01.cbz",
            taille: archive.taille,
            nom: "Tome 01",
            reglages: ReglagesDeFlux(essais: 1, attendre: { _ in })
        )

        let pages = try await conteneur.pages()

        #expect(pages.count == 8)

        let octets = try await conteneur.donnees(page: pages[6])

        #expect(octets == archive.contenuDUnePage)

        // Le serveur borne chaque lecture a huit kilo octets. Ce qui a ete servi
        // reste tres en dessous des deux mega octets du conteneur, ce qui prouve
        // que le tampon a bien reclame la suite des reponses courtes sans jamais
        // rapatrier l archive.
        let servis = await canal.octetsServis

        #expect(servis < archive.taille / 2)
    }

    @Test("Un descripteur deja resolu n est pas recherche une seconde fois")
    func descripteursRetenus() async throws {
        let canal = Self.serveur()
        let partage = Self.partage(sur: canal)

        _ = try await partage.attributs(de: "Berserk/Tome 01.cbz")

        let apresLaPremiere = await canal.procedures.filter { $0 == 3 }.count

        _ = try await partage.attributs(de: "Berserk/Tome 01.cbz")
        _ = try await partage.lire("Berserk/Tome 01.cbz", a: 0, longueur: 16)

        #expect(await canal.procedures.filter { $0 == 3 }.count == apresLaPremiere)
    }

    // MARK: Encodage XDR

    @Test("Une suite d octets est alignee sur quatre, avec son bourrage")
    func alignementSurQuatre() {
        var ecriture = EcritureXdr()
        ecriture.variable(Data([1, 2, 3, 4, 5]))

        // Quatre octets de longueur, cinq de contenu, trois de bourrage.
        #expect(ecriture.octets.count == 12)
        #expect(Array(ecriture.octets.suffix(3)) == [0, 0, 0])

        var lecture = LectureXdr(ecriture.octets)

        #expect(lecture.variable() == Data([1, 2, 3, 4, 5]))
        #expect(lecture.reste == 0)
    }

    @Test("Les entiers sont ecrits en gros boutien")
    func grosBoutien() {
        var ecriture = EcritureXdr()
        ecriture.entier32(0x0102_0304)
        ecriture.entier64(0x0102_0304_0506_0708)

        #expect(Array(ecriture.octets.prefix(4)) == [1, 2, 3, 4])
        #expect(Array(ecriture.octets.suffix(8)) == [1, 2, 3, 4, 5, 6, 7, 8])

        var lecture = LectureXdr(ecriture.octets)

        #expect(lecture.entier32() == 0x0102_0304)
        #expect(lecture.entier64() == 0x0102_0304_0506_0708)
    }

    @Test("Une trame tronquee rend nul plutot que de lire hors bornes")
    func trameTronquee() {
        var lecture = LectureXdr(Data([0, 0, 1]))

        #expect(lecture.entier32() == nil)
        #expect(lecture.entier64() == nil)
        #expect(lecture.fixe(8) == nil)
    }

    @Test("Une reponse qui ne repond pas a l appel est refusee")
    func reponseMalAppariee() {
        var ecriture = EcritureXdr()
        ecriture.entier32(99)
        ecriture.entier32(1)
        ecriture.entier32(0)

        #expect(throws: ErreurRpc.reponseMalAppariee) {
            _ = try ClientRpc.lireLaReponse(ecriture.octets, identifiant: 1)
        }
    }

    @Test("Un appel refuse par le serveur devient un refus d identifiants")
    func appelRefuse() {
        var ecriture = EcritureXdr()
        ecriture.entier32(1)
        ecriture.entier32(1)
        ecriture.entier32(1)
        ecriture.entier32(2)

        #expect(throws: ErreurRpc.appelRefuse(code: 2)) {
            _ = try ClientRpc.lireLaReponse(ecriture.octets, identifiant: 1)
        }
        #expect(ErreurRpc.appelRefuse(code: 2).reseau == .authentificationRefusee)
    }

    @Test("Le marqueur de fragment porte le bit de dernier fragment")
    func marqueurDeFragment() {
        let marquee = ClientRpc.marquer(Data([1, 2, 3, 4]))

        #expect(marquee.count == 8)
        #expect(Array(marquee.prefix(4)) == [0x80, 0, 0, 4])
    }
}
