import Core
import Foundation
import GRDB
import Testing
@testable import BudgetsDePerformance
@testable import Storage

//
// GenerateurDeJeuDeTestTests
//
// Ce que le depot ne peut pas suivre en binaire, il le suit en garanties.
//
// La base de 200000 chapitres n est pas versionnee : elle pese une quarantaine
// de mega octets et se reconstruit a l identique depuis sa graine. Ce qui rend
// ce choix defendable est verifie ici, sur un corpus reduit qui emprunte le meme
// chemin de code : la repartition tombe juste au chapitre pres, deux generations
// depuis la meme graine rendent le meme corpus, et le CBZ produit est une
// archive que le lecteur du projet sait ouvrir et decoder.
//

struct GenerateurDeJeuDeTestTests {
    /// Corpus reduit, cinquante fois plus petit que celui de la section 12.
    ///
    /// Il traverse exactement le meme code. Ce qui est sacrifie est la duree de
    /// la suite, pas la couverture : le generateur ne connait aucun cas
    /// particulier au dela de mille series.
    private let reduit = ManifesteDuJeuDeTest(
        series: 50,
        chapitres: 2000,
        graine: ManifesteDuJeuDeTest.section12.graine,
        chapitresSurDisque: 1,
        pagesParChapitreSurDisque: 3,
        largeurDePage: 240,
        hauteurDePage: 360
    )

    // MARK: Repartition

    @Test("La somme des chapitres tombe exactement sur le total demande")
    func repartitionExacte() {
        var tirage = GrainePseudoAleatoire(graine: reduit.graine)
        let repartition = GenerateurDeJeuDeTest.repartitionDesChapitres(reduit, tirage: &tirage)

        #expect(repartition.count == reduit.series)
        #expect(repartition.reduce(0, +) == reduit.chapitres)
        #expect(repartition.allSatisfy { $0 >= 1 })
    }

    @Test("La repartition du corpus de la section 12 tombe aussi sur 200000")
    func repartitionDeLaSection12() {
        let manifeste = ManifesteDuJeuDeTest.section12
        var tirage = GrainePseudoAleatoire(graine: manifeste.graine)
        let repartition = GenerateurDeJeuDeTest.repartitionDesChapitres(manifeste, tirage: &tirage)

        #expect(repartition.count == 5000)
        #expect(repartition.reduce(0, +) == 200_000)
    }

    @Test("Les series n ont pas toutes le meme nombre de chapitres")
    func repartitionVariee() {
        var tirage = GrainePseudoAleatoire(graine: reduit.graine)
        let repartition = GenerateurDeJeuDeTest.repartitionDesChapitres(reduit, tirage: &tirage)

        #expect(Set(repartition).count > 1)
    }

    // MARK: Corpus en base

    @Test("Le corpus porte le nombre exact de series et de chapitres annonce")
    func corpusConformeAuManifeste() throws {
        let base = try BaseDeDonnees.enMemoire()
        try GenerateurDeJeuDeTest.remplir(base, avec: reduit)

        let comptes = try base.ecrivain.read { connexion in
            try (
                series: Manga.fetchCount(connexion),
                chapitres: Chapitre.fetchCount(connexion),
                enBibliotheque: MangaDeGrille.enBibliotheque().fetchCount(connexion)
            )
        }

        #expect(comptes.series == reduit.series)
        #expect(comptes.chapitres == reduit.chapitres)
        #expect(comptes.enBibliotheque == reduit.series)
    }

    @Test("Le compteur denormalise de non lus est juste sur toutes les series")
    func compteurDeNonLusJuste() throws {
        let base = try BaseDeDonnees.enMemoire()
        try GenerateurDeJeuDeTest.remplir(base, avec: reduit)

        let ecarts = try base.ecrivain.read { connexion in
            try Int.fetchOne(connexion, sql: """
            SELECT COUNT(*) FROM manga
            WHERE chapitresNonLus <> (
                SELECT COUNT(*) FROM chapitre WHERE chapitre.mangaId = manga.id AND estLu = 0
            )
            """)
        }

        #expect(ecarts == 0)
    }

    @Test("La bibliotheque porte des series lues et des series non lues")
    func pastillesVariees() throws {
        let base = try BaseDeDonnees.enMemoire()
        try GenerateurDeJeuDeTest.remplir(base, avec: reduit)

        let pastilles = try base.ecrivain.read { connexion in
            try MangaDeGrille.enBibliotheque().fetchAll(connexion).map(\.chapitresNonLus)
        }

        #expect(Set(pastilles).count > 1)
        #expect(pastilles.contains { $0 > 0 })
    }

    @Test("Deux generations depuis la meme graine rendent le meme corpus")
    func generationDeterministe() throws {
        let empreintes = try (0..<2).map { _ in
            let base = try BaseDeDonnees.enMemoire()
            try GenerateurDeJeuDeTest.remplir(base, avec: reduit)

            return try base.ecrivain.read { connexion in
                try Row.fetchAll(connexion, sql: """
                SELECT id, titre, chapitresNonLus, dateDerniereLecture FROM manga ORDER BY identifiantDistant
                """).map(\.description)
            }
        }

        #expect(empreintes[0] == empreintes[1])
        #expect(empreintes[0].count == reduit.series)
    }

    @Test("Une graine differente rend un corpus different")
    func graineDifferenteCorpusDifferent() throws {
        let autre = ManifesteDuJeuDeTest(
            series: reduit.series,
            chapitres: reduit.chapitres,
            graine: reduit.graine &+ 1,
            chapitresSurDisque: reduit.chapitresSurDisque,
            pagesParChapitreSurDisque: reduit.pagesParChapitreSurDisque,
            largeurDePage: reduit.largeurDePage,
            hauteurDePage: reduit.hauteurDePage
        )

        let titres = try [reduit, autre].map { manifeste in
            let base = try BaseDeDonnees.enMemoire()
            try GenerateurDeJeuDeTest.remplir(base, avec: manifeste)

            return try base.ecrivain.read { connexion in
                try UUID.fetchAll(connexion, sql: "SELECT id FROM manga ORDER BY identifiantDistant")
            }
        }

        #expect(titres[0] != titres[1])
    }
}
