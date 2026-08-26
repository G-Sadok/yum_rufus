import Core
import Foundation
import Testing
@testable import Sources

//
// PartageWebDavTests
//
// Le troisieme critere pris de bout en bout, transport compris, plus les quatre
// formes de reponse que la strategie de test exige de toute source : une reponse
// figee, une malformee, une vide et une tronquee.
//
// Le serveur de test verifie lui meme la reponse Digest qu on lui presente. Un
// test qui passe ici veut donc dire que le calcul est juste au sens de la norme,
// pas seulement qu un entete a ete pose.
//

struct PartageWebDavTests {
    static let adresse = "https://exemple.test/dav/Mangas"

    /// Un serveur portant une petite bibliotheque a deux niveaux.
    static func serveur(
        algorithme: AlgorithmeDigest = .md5,
        seulementBasique: Bool = false,
        archive: ArchiveSynthetique = ArchiveSynthetique(nombreDePages: 4, octetsParPage: 200 * 1024)
    ) -> ServeurWebDavDeTest {
        ServeurWebDavDeTest(
            algorithme: algorithme,
            seulementBasique: seulementBasique,
            arbre: [
                "/dav/Mangas": .dossier,
                "/dav/Mangas/Berserk": .dossier,
                "/dav/Mangas/Berserk/Tome 01.cbz": .fichier(.archive(archive)),
                "/dav/Mangas/Vinland Saga": .dossier,
                "/dav/Mangas/Vinland Saga/Tome 01.cbz": .fichier(.archive(archive)),
            ]
        )
    }

    static func partage(sur serveur: ServeurWebDavDeTest) throws -> PartageWebDav {
        guard let base = URL(string: adresse) else {
            throw ErreurReseau.serveurIntrouvable
        }

        return try PartageWebDav(
            libelle: "Partage WebDAV",
            base: base,
            transport: serveur,
            identifiants: .compte(compte: "utilisateur", motDePasse: "mot de passe")
        )
    }

    // MARK: Troisieme critere

    @Test("L authentification Digest fonctionne sur WebDAV")
    func authentificationDigest() async throws {
        let serveur = Self.serveur()
        let partage = try Self.partage(sur: serveur)

        let racine = try await partage.lister("")

        // La verification sort de la macro : `allSatisfy` y est vu comme
        // pouvant lever, et la forme qui compile a l interieur est justement
        // celle que SwiftFormat reecrit en chemin de cle.
        let toutesDesDossiers = racine.allSatisfy(\.estDossier)

        #expect(racine.map(\.nom).sorted() == ["Berserk", "Vinland Saga"])
        #expect(toutesDesDossiers)

        // La premiere requete part sans preuve, se fait refuser, et la seconde
        // porte la reponse au defi. Le serveur ne repond 207 que si ce calcul
        // est juste, donc trois requetes pour deux listages veut dire que la
        // negociation a eu lieu une seule fois.
        let journal = await serveur.requetes

        #expect(journal.count == 2)
        #expect(journal[0].entete("Authorization") == nil)
        #expect(journal[1].entete("Authorization")?.hasPrefix("Digest ") == true)

        _ = try await partage.lister("Berserk")

        #expect(await serveur.requetes.count == 3)

        // Le compteur s incremente d une requete a l autre. Un serveur qui
        // detecte un rejeu refuse, et sans cet increment la seconde lecture
        // echouerait sur un vrai serveur sans que rien ici ne s en apercoive.
        #expect(await serveur.compteursAcceptes == ["00000001", "00000002"])
    }

    @Test("L authentification Digest fonctionne aussi en SHA-256")
    func authentificationDigestSha256() async throws {
        let serveur = Self.serveur(algorithme: .sha256)
        let partage = try Self.partage(sur: serveur)

        let racine = try await partage.lister("")

        #expect(racine.isEmpty == false)
    }

    @Test("Un serveur qui n annonce que Basic est servi en Basic")
    func authentificationBasique() async throws {
        let serveur = Self.serveur(seulementBasique: true)
        let partage = try Self.partage(sur: serveur)

        let racine = try await partage.lister("")

        #expect(racine.isEmpty == false)

        let journal = await serveur.requetes

        #expect(journal.last?.entete("Authorization")?.hasPrefix("Basic ") == true)
    }

    @Test("Un mot de passe faux se solde par un refus nomme, sans boucler")
    func motDePasseFaux() async throws {
        let serveur = Self.serveur()

        guard let base = URL(string: Self.adresse) else {
            throw ErreurReseau.serveurIntrouvable
        }

        let partage = try PartageWebDav(
            libelle: "Partage WebDAV",
            base: base,
            transport: serveur,
            identifiants: .compte(compte: "utilisateur", motDePasse: "mauvais")
        )

        await #expect(throws: ErreurReseau.authentificationRefusee) {
            _ = try await partage.lister("")
        }

        // Deux requetes, pas davantage. Rejouer en boucle un mot de passe faux
        // ferait bloquer le compte de l utilisateur par le serveur.
        #expect(await serveur.requetes.count == 2)
    }

    @Test("Une adresse en clair est refusee sans confirmation explicite")
    func adresseEnClairRefusee() throws {
        guard let base = URL(string: "http://exemple.test/dav") else {
            throw ErreurReseau.serveurIntrouvable
        }

        #expect(throws: ErreurReseau.transportNonChiffre) {
            _ = try PartageWebDav(libelle: "Partage", base: base, transport: Self.serveur())
        }
    }

    // MARK: Lecture

    @Test("Les attributs d un fichier donnent sa taille reelle")
    func attributsDUnFichier() async throws {
        let archive = ArchiveSynthetique(nombreDePages: 4, octetsParPage: 200 * 1024)
        let serveur = Self.serveur(archive: archive)
        let partage = try Self.partage(sur: serveur)

        let attributs = try await partage.attributs(de: "Berserk/Tome 01.cbz")

        #expect(attributs.estDossier == false)
        #expect(attributs.taille == archive.taille)
        #expect(attributs.nom == "Tome 01.cbz")
    }

    @Test("Un CBZ pose sur un partage WebDAV se lit par plages")
    func lectureParPlages() async throws {
        let archive = ArchiveSynthetique(nombreDePages: 6, octetsParPage: 400 * 1024)
        let serveur = Self.serveur(archive: archive)
        let partage = try Self.partage(sur: serveur)

        let conteneur = ConteneurDePartage(
            partage: partage,
            chemin: "Berserk/Tome 01.cbz",
            taille: archive.taille,
            nom: "Tome 01",
            reglages: ReglagesDeFlux(essais: 1, attendre: { _ in })
        )

        let pages = try await conteneur.pages()

        #expect(pages.count == 6)

        let octets = try await conteneur.donnees(page: pages[4])

        #expect(octets == archive.contenuDUnePage)

        // Le serveur n a servi que l index et une page, jamais les deux mega
        // octets et demi du conteneur.
        let servis = await serveur.octetsServis

        #expect(servis < archive.taille / 2)
    }

    // MARK: Formes de reponse

    @Test("Une reponse multi statuts se lit champ par champ")
    func analyseDUneReponseValide() throws {
        let document = """
        <?xml version="1.0" encoding="utf-8"?>
        <d:multistatus xmlns:d="DAV:">
          <d:response>
            <d:href>/dav/Mangas/</d:href>
            <d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype></d:prop>
            <d:status>HTTP/1.1 200 OK</d:status></d:propstat>
          </d:response>
          <d:response>
            <d:href>/dav/Mangas/Tome%2001.cbz</d:href>
            <d:propstat><d:prop><d:resourcetype/><d:getcontentlength>4096</d:getcontentlength>
            <d:getlastmodified>Tue, 15 Nov 1994 12:45:26 GMT</d:getlastmodified></d:prop>
            <d:status>HTTP/1.1 200 OK</d:status></d:propstat>
          </d:response>
        </d:multistatus>
        """
        let entrees = try #require(AnalyseWebDav.analyser(Data(document.utf8)))

        #expect(entrees.count == 2)
        #expect(entrees[0].chemin == "/dav/Mangas")
        #expect(entrees[0].estDossier)

        #expect(entrees[1].chemin == "/dav/Mangas/Tome 01.cbz")
        #expect(entrees[1].estDossier == false)
        #expect(entrees[1].taille == 4096)
        #expect(entrees[1].dateModification != nil)
    }

    @Test("Un bloc de proprietes en echec ne devient pas une taille nulle")
    func blocEnEchecIgnore() throws {
        let document = """
        <?xml version="1.0" encoding="utf-8"?>
        <D:multistatus xmlns:D="DAV:">
          <D:response>
            <D:href>/dav/fichier.cbz</D:href>
            <D:propstat><D:prop><D:getcontentlength>900</D:getcontentlength></D:prop>
            <D:status>HTTP/1.1 200 OK</D:status></D:propstat>
            <D:propstat><D:prop><D:getcontentlength>0</D:getcontentlength></D:prop>
            <D:status>HTTP/1.1 404 Not Found</D:status></D:propstat>
          </D:response>
        </D:multistatus>
        """
        let entrees = try #require(AnalyseWebDav.analyser(Data(document.utf8)))

        #expect(entrees.count == 1)
        #expect(entrees[0].taille == 900)
    }

    @Test("Un document malforme ne rend aucune entree")
    func documentMalforme() {
        #expect(AnalyseWebDav.analyser(Data("ceci n est pas du XML".utf8)) == nil)
        #expect(AnalyseWebDav.analyser(Data("<html><body>Page de connexion</body></html>".utf8)) == nil)
    }

    @Test("Un document vide ne rend aucune entree")
    func documentVide() {
        #expect(AnalyseWebDav.analyser(Data()) == nil)
    }

    @Test("Un document tronque garde les entrees deja fermees")
    func documentTronque() throws {
        let complet = """
        <?xml version="1.0" encoding="utf-8"?>
        <D:multistatus xmlns:D="DAV:">
          <D:response><D:href>/dav/a.cbz</D:href><D:propstat><D:prop><D:resourcetype/>
          <D:getcontentlength>10</D:getcontentlength></D:prop>
          <D:status>HTTP/1.1 200 OK</D:status></D:propstat></D:response>
          <D:response><D:href>/dav/b.cbz</D:href><D:propstat><D:prop><D:resourcetype/>
          <D:getcontentlength>20</D:getcontentlength></D:prop>
          <D:status>HTTP/1.1 200 OK</D:status></D:propstat></D:response>
        </D:multistatus>
        """
        let coupe = String(complet.prefix(complet.count - 120))
        let entrees = try #require(AnalyseWebDav.analyser(Data(coupe.utf8)))

        #expect(entrees.isEmpty == false)
        #expect(entrees[0].chemin == "/dav/a.cbz")
        #expect(entrees[0].taille == 10)
    }

    @Test("Une reponse vide du serveur est nommee comme telle")
    func reponseVideDuServeur() async throws {
        let transport = TransportFige([
            RegleDeTransport(methode: .propfind, chemin: "/dav/Mangas", reponse: ReponseHttp(code: 207)),
        ])

        guard let base = URL(string: Self.adresse) else {
            throw ErreurReseau.serveurIntrouvable
        }

        let client = try ClientWebDav(base: base, transport: transport)

        await #expect(throws: ErreurReseau.reponseVide) {
            _ = try await client.lister("")
        }
    }

    @Test("Une reponse qui n est pas du WebDAV est nommee illisible")
    func reponseIllisibleDuServeur() async throws {
        let transport = TransportFige([
            RegleDeTransport(
                methode: .propfind,
                chemin: "/dav/Mangas",
                reponse: ReponseHttp(code: 207, corps: Data("<html>connexion</html>".utf8))
            ),
        ])

        guard let base = URL(string: Self.adresse) else {
            throw ErreurReseau.serveurIntrouvable
        }

        let client = try ClientWebDav(base: base, transport: transport)

        await #expect(throws: ErreurReseau.reponseIllisible) {
            _ = try await client.lister("")
        }
    }

    // MARK: Adresses

    @Test("L adresse de requete du calcul Digest est le chemin, pas l adresse complete")
    func adresseDeRequeteDigest() throws {
        let adresse = try #require(URL(string: "https://exemple.test/dav/Mangas/Tome%2001.cbz?vue=brute"))

        #expect(ClientWebDav.uri(de: adresse) == "/dav/Mangas/Tome%2001.cbz?vue=brute")
    }
}
