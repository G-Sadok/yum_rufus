import Core
import Foundation
import Testing
@testable import Sources

/// Couvre le troisieme critere de la fonctionnalite : les capacites declarees
/// correspondent aux fonctions reellement offertes.
///
/// Chacune des six capacites est traitee, dans les deux sens. Une capacite
/// declaree doit repondre. Une capacite non declaree doit refuser par une
/// erreur nommee, jamais par un resultat vide ou approximatif : c est ce refus
/// qui rend la declaration verifiable.
struct CapacitesDeSourceTests {
    private static let nom = EnvironnementDeSource.nomDeLaSource

    // MARK: Declaration

    @Test("La source declare la recherche et la pagination, et rien d autre")
    func capacitesDeclarees() async throws {
        try await avecBibliotheque { source in
            #expect(source.capacites == [.recherche, .pagination])
            #expect(source.declare(.recherche))
            #expect(source.declare(.pagination))
            #expect(source.declare(.filtres) == false)
            #expect(source.declare(.telechargement) == false)
            #expect(source.declare(.progressionDistante) == false)
            #expect(source.declare(.plusieursLangues) == false)
        }
    }

    @Test("Les capacites non declarees n ont aucune fonction correspondante")
    func capacitesNonDeclareesSansSurface() async throws {
        // Le telechargement et la progression distante n ont aucune methode
        // dans le protocole de la section 4.1. Un dossier local n a rien a
        // telecharger, tout est deja sur le disque, et il ne tient aucune
        // progression cote serveur. Ne pas les declarer est donc la seule
        // reponse exacte, et ce test fige ce choix.
        let sansSurface: SourceCapacites = [.telechargement, .progressionDistante]

        try await avecBibliotheque { source in
            #expect(source.capacites.isDisjoint(with: sansSurface))
        }
    }

    // MARK: Recherche, declaree

    @Test("La recherche declaree filtre reellement sur le titre")
    func rechercheFiltre() async throws {
        try await avecBibliotheque { source in
            let resultats = try await source.rechercher(RequeteRecherche(texte: "serie b"))

            #expect(resultats.elements.map(\.titre) == ["Serie B"])
        }
    }

    @Test("La recherche ignore la casse et les accents")
    func rechercheSansCasseNiAccent() async throws {
        let arbre = try ArbreDeTest()
        try arbre.image("Pokémon/page1.jpg")

        let environnement = try EnvironnementDeSource(arbre: arbre)
        let source = try environnement.sourcePremierLancement()
        let resultats = try await source.rechercher(RequeteRecherche(texte: "pokemon"))

        #expect(resultats.elements.map(\.titre) == ["Pokémon"])

        withExtendedLifetime(environnement) {}
    }

    @Test("Une recherche vide rend tout le catalogue")
    func rechercheVide() async throws {
        try await avecBibliotheque { source in
            let resultats = try await source.rechercher(RequeteRecherche(texte: ""))

            #expect(resultats.elements.count == 4)
        }
    }

    // MARK: Pagination, declaree

    @Test("La pagination declaree rend des tranches et dit s il en reste")
    func paginationParTranches() async throws {
        try await avecBibliotheque(tailleDePage: 2) { source in
            let premiere = try await source.parcourir(.tout, page: 0)
            let seconde = try await source.parcourir(.tout, page: 1)
            let troisieme = try await source.parcourir(.tout, page: 2)

            #expect(premiere.elements.map(\.titre) == ["Serie A", "Serie B"])
            #expect(premiere.ilResteDesPages)
            #expect(seconde.elements.map(\.titre) == ["Serie C", "Tome unique"])
            #expect(seconde.ilResteDesPages == false)
            #expect(troisieme.elements.isEmpty)
        }
    }

    @Test("La derniere page pleine ne promet pas de page suivante")
    func derniereTranchePleine() async throws {
        try await avecBibliotheque(tailleDePage: 4) { source in
            let page = try await source.parcourir(.tout, page: 0)

            #expect(page.elements.count == 4)
            #expect(page.ilResteDesPages == false)
        }
    }

    // MARK: Filtres, non declares

    @Test("Une requete filtree est refusee, pas ignoree")
    func filtresRefuses() async throws {
        try await avecBibliotheque { source in
            let requete = RequeteRecherche(
                texte: "serie",
                filtres: FiltresDeRecherche(genres: ["action"])
            )

            await #expect(throws: ErreurDeSource.capaciteIndisponible(capacite: .filtres, source: Self.nom)) {
                _ = try await source.rechercher(requete)
            }
        }
    }

    @Test("Un filtre de statut est refuse lui aussi")
    func filtreDeStatutRefuse() async throws {
        try await avecBibliotheque { source in
            let requete = RequeteRecherche(
                texte: "serie",
                filtres: FiltresDeRecherche(statut: .enCours)
            )

            await #expect(throws: ErreurDeSource.capaciteIndisponible(capacite: .filtres, source: Self.nom)) {
                _ = try await source.rechercher(requete)
            }
        }
    }

    // MARK: Plusieurs langues, non declarees

    @Test("Une requete qui demande une langue est refusee")
    func langueRefusee() async throws {
        try await avecBibliotheque { source in
            let requete = RequeteRecherche(texte: "serie", langue: "fr")

            await #expect(
                throws: ErreurDeSource.capaciteIndisponible(capacite: .plusieursLangues, source: Self.nom)
            ) {
                _ = try await source.rechercher(requete)
            }
        }
    }

    @Test("Aucun chapitre local n annonce de langue")
    func aucuneLangueAnnoncee() async throws {
        try await avecBibliotheque { source in
            let chapitres = try await source.chapitres(pour: "Serie A")

            #expect(chapitres.allSatisfy { $0.langue == nil })
        }
    }

    // MARK: Sections de catalogue

    @Test("La section populaires est refusee, faute de mesure de popularite")
    func sectionPopulairesRefusee() async throws {
        try await avecBibliotheque { source in
            await #expect(
                throws: ErreurDeSource.sectionNonPriseEnCharge(section: .populaires, source: Self.nom)
            ) {
                _ = try await source.parcourir(.populaires, page: 0)
            }
        }
    }

    @Test("La section recentes classe par date de modification")
    func sectionRecentes() async throws {
        let arbre = try ArbreDeTest()
        try arbre.image("Ancienne/page1.jpg")
        try arbre.image("Recente/page1.jpg")

        let ancienne = arbre.racine.appending(path: "Ancienne")
        let vieilleDate = Date(timeIntervalSince1970: 0)

        try FileManager.default.setAttributes(
            [.modificationDate: vieilleDate],
            ofItemAtPath: ancienne.appending(path: "page1.jpg").path
        )
        try FileManager.default.setAttributes(
            [.modificationDate: vieilleDate],
            ofItemAtPath: ancienne.path
        )

        let environnement = try EnvironnementDeSource(arbre: arbre)
        let source = try environnement.sourcePremierLancement()
        let recentes = try await source.parcourir(.recentes, page: 0)

        #expect(recentes.elements.map(\.titre) == ["Recente", "Ancienne"])

        withExtendedLifetime(environnement) {}
    }

    // MARK: Outils

    /// Pose la bibliotheque de reference, fabrique la source, et garde l arbre
    /// en vie jusqu a la fin du corps.
    ///
    /// La duree de vie compte : l arbre efface son dossier temporaire quand il
    /// est libere. Rendre la source seule laisserait le compilateur liberer
    /// l arbre avant la premiere lecture, et les tests echoueraient au hasard
    /// des optimisations.
    private func avecBibliotheque(
        tailleDePage: Int = SourceFichiersLocaux.tailleDePageParDefaut,
        _ corps: (SourceFichiersLocaux) async throws -> Void
    ) async throws {
        let arbre = try ArbreDeTest()
        try BibliothequeDeTest.poser(dans: arbre)

        let environnement = try EnvironnementDeSource(arbre: arbre)

        try await corps(environnement.sourcePremierLancement(tailleDePage: tailleDePage))

        withExtendedLifetime(environnement) {}
    }
}
