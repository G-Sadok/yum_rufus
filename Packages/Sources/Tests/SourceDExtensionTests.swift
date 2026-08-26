import Core
import Foundation
import Testing
@testable import Sources

/// Couvre l interprete de regles declaratives de bout en bout : une extension
/// installee, un serveur fige, et les entites du protocole en sortie.
///
/// Le premier critere se lit ici sous sa forme observable. Rien de ce que le
/// manifeste contient n est appele, evalue ni compile : la source suit des
/// chemins et des selecteurs, et le contenu d une balise `script` de la page
/// servie n atteint meme pas l arbre, ce que le test des pages verifie.
struct SourceDExtensionTests {
    // MARK: Ce que la source annonce

    @Test("La source annonce ce que ses regles savent servir")
    func capacites() throws {
        let source = try source(serveur: TransportEspion())

        #expect(source.nom == "Catalogue Exemple")
        #expect(source.version == VersionDExtension(majeure: 1, mineure: 4))
        #expect(source.langue == "fr")
        #expect(source.capacites.contains(.recherche))
        #expect(source.capacites.contains(.pagination))
        #expect(source.capacites.contains(.telechargement))
        #expect(source.capacites.contains(.filtres) == false)
    }

    @Test("Une capacite non declaree est refusee au lieu d etre ignoree")
    func capaciteRefusee() async throws {
        let source = try source(serveur: CatalogueDeclaratifDeTest.serveur())
        let avecFiltres = RequeteRecherche(
            texte: "reference",
            filtres: FiltresDeRecherche(genres: ["action"])
        )

        await #expect(throws: ErreurDeSource.self) {
            try await source.rechercher(avecFiltres)
        }
    }

    // MARK: Recherche

    @Test("La recherche lit les champs declares et resout les adresses relatives")
    func recherche() async throws {
        let espion = CatalogueDeclaratifDeTest.serveur()
        let source = try source(serveur: espion)
        let resultats = try await source.rechercher(RequeteRecherche(texte: "reference"))
        let premiere = try #require(resultats.elements.first)

        #expect(premiere.identifiant == "12")
        #expect(premiere.titre == "Serie de reference")
        #expect(premiere.auteurs == ["Une autrice", "Un auteur"])
        #expect(premiere.statut == .enCours)
        #expect(premiere.nombreChapitres == 42)
        #expect(premiere.urlCouverture == "https://api.exemple.net/couvertures/12.jpg")
    }

    /// Le protocole numerote les pages a partir de zero, ce catalogue a partir
    /// de un. Le decalage est applique une fois, par `pageDeDepart`.
    @Test("Le numero de page est decale par le manifeste")
    func decalageDePage() async throws {
        let espion = CatalogueDeclaratifDeTest.serveur()
        let source = try source(serveur: espion)

        _ = try await source.rechercher(RequeteRecherche(texte: "reference", page: 0))

        let adresse = try #require(await espion.adressesDemandees.first)
        let composants = try #require(URLComponents(url: adresse, resolvingAgainstBaseURL: false))

        #expect(composants.queryItems?.first { $0.name == "page" }?.value == "1")
        #expect(composants.queryItems?.first { $0.name == "q" }?.value == "reference")
    }

    @Test("La pagination par total annonce dit qu il reste des pages")
    func paginationParTotal() async throws {
        let source = try source(serveur: CatalogueDeclaratifDeTest.serveur())
        let premiere = try await source.rechercher(RequeteRecherche(texte: "reference", page: 0))
        let troisieme = try await source.rechercher(RequeteRecherche(texte: "reference", page: 2))

        #expect(premiere.ilResteDesPages)
        #expect(troisieme.ilResteDesPages == false)
    }

    @Test("La pagination par liste pleine dit qu il reste des pages")
    func paginationParListePleine() async throws {
        let source = try source(serveur: CatalogueDeclaratifDeTest.serveur())
        let page = try await source.parcourir(.recentes, page: 0)

        #expect(page.elements.map(\.identifiant) == ["a", "b"])
        #expect(page.ilResteDesPages)
    }

    @Test("Une section que l extension ne declare pas est refusee")
    func sectionNonDeclaree() async throws {
        let source = try source(serveur: CatalogueDeclaratifDeTest.serveur())

        await #expect(throws: ErreurDeSource.self) {
            try await source.parcourir(.populaires, page: 0)
        }
    }

    // MARK: Detail et chapitres

    @Test("Le detail se lit dans l element declare")
    func detail() async throws {
        let source = try source(serveur: CatalogueDeclaratifDeTest.serveur())
        let serie = try await source.detailsManga("12")

        #expect(serie.titre == "Serie de reference")
        #expect(serie.resume == "Un resume")
    }

    /// Le catalogue publie du plus recent au plus ancien. Le protocole rend
    /// l ordre de lecture, et le rang est attribue apres le retournement.
    @Test("Les chapitres sont rendus dans l ordre de lecture")
    func chapitresDansLOrdreDeLecture() async throws {
        let source = try source(serveur: CatalogueDeclaratifDeTest.serveur())
        let chapitres = try await source.chapitres(pour: "12")

        #expect(chapitres.map(\.identifiant) == ["c-1", "c-2"])
        #expect(chapitres.map(\.ordre) == [0, 1])
        #expect(chapitres.map(\.numero) == [1, 2])
        #expect(chapitres.first?.titre == "Premier")
        #expect(chapitres.first?.datePublication == Date(timeIntervalSince1970: 1_704_067_200))
    }

    // MARK: Pages

    /// Trois choses a la fois. Les pages sont lues par selecteur dans une page
    /// HTML mal fermee. Leur ordre est celui du document. Et l adresse cachee
    /// dans la balise `script` n apparait nulle part, parce que le contenu
    /// d un script n entre pas dans l arbre.
    @Test("Les pages sont lues dans la page HTML, sans toucher aux scripts")
    func pages() async throws {
        let source = try source(serveur: CatalogueDeclaratifDeTest.serveur())
        let pages = try await source.pages(pour: "c-1")

        #expect(pages.map(\.emplacement.absoluteString) == [
            "https://api.exemple.net/p/1.jpg",
            "https://images.exemple.net/p/2.jpg",
        ])
        #expect(pages.map(\.index) == [0, 1])
        #expect(pages.contains { $0.emplacement.absoluteString.contains("piege") } == false)
    }

    @Test("Une page servie par un domaine declare donne une requete")
    func requeteImageAutorisee() async throws {
        let source = try source(serveur: CatalogueDeclaratifDeTest.serveur())
        let page = try #require(await source.pages(pour: "c-1").last)
        let requete = try await source.requeteImage(pour: page)

        #expect(requete.url?.host() == "images.exemple.net")
    }

    /// Le chemin le plus discret pour faire joindre un tiers par
    /// l application : une page dont l adresse sort de la liste blanche. La
    /// couche qui telecharge l image ne connait ni l extension ni ses domaines,
    /// le refus doit donc venir d ici.
    @Test("Une page hors liste blanche ne donne aucune requete")
    func requeteImageRefusee() async throws {
        let source = try source(serveur: CatalogueDeclaratifDeTest.serveur())
        let horsListe = try PageDistante(
            identifiantChapitre: "c-1",
            index: 0,
            emplacement: #require(URL(string: "https://attaquant.org/pixel.jpg"))
        )

        await #expect(throws: ErreurReseau.domaineNonAutorise(domaine: "attaquant.org")) {
            try await source.requeteImage(pour: horsListe)
        }
    }

    // MARK: Connexion

    @Test("La verification de connexion passe par une regle declaree")
    func verificationDeConnexion() async throws {
        let joignable = try source(serveur: CatalogueDeclaratifDeTest.serveur())
        let muet = try source(serveur: TransportEspion())

        #expect(await joignable.verifierConnexion() == .connecte)
        #expect(await muet.verifierConnexion() == .erreur)
    }

    // MARK: Outils

    /// La source de test, posee sur la barriere reelle.
    private func source(serveur: TransportEspion) throws -> SourceDExtension {
        try SourceDExtension(
            installee: CatalogueDeclaratifDeTest.installee(),
            transportInterne: serveur,
            journal: JournalDExtensionsEnMemoire()
        )
    }
}
