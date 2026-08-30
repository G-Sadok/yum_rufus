import Core
import Foundation
import GRDB
import Testing
@testable import Storage

//
// Persistance de la veille de F060.
//
// Deux choses doivent survivre a la fermeture de l application, et chacune tient
// un critere.
//
// L etat des quotas, sans quoi le plafond quotidien repartirait de zero a chaque
// lancement et la verification en arriere plan cesserait de respecter quoi que
// ce soit.
//
// Ce que la veille a deja annonce, sans quoi la meme nouveaute repartirait a
// chaque execution jusqu a ce que l utilisateur ouvre la serie.
//

struct VeillePersistePersistenceTests {
    private var reference: Date {
        Date(timeIntervalSince1970: 1_700_000_000)
    }

    /// Base migree, avec une serie de trois chapitres dans la bibliotheque.
    private func basePeuplee() throws -> (BaseDeDonnees, JeuDeDonneesDeTest.Contenu) {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 3)

        return (base, jeu)
    }

    // MARK: Etat des quotas

    @Test("L etat des quotas survit a la fermeture")
    func etatPersiste() async throws {
        let (base, _) = try basePeuplee()
        let magasin = MagasinDeVeilleDeChapitres(base: base)

        var etat = try await magasin.etatDeVeille()

        #expect(etat == .neuf)

        etat.compterUneExecution(le: reference)
        etat.compterUnEchec()
        try await magasin.enregistrer(etat)

        // Un second magasin, comme apres un relancement de l application.
        let relu = try await MagasinDeVeilleDeChapitres(base: base).etatDeVeille()

        #expect(relu.derniereTentative == reference)
        #expect(relu.echecsConsecutifs == 1)
        #expect(relu.executions(le: reference) == 1)
    }

    // MARK: Series surveillees

    @Test("Seules les series de la bibliotheque sont surveillees")
    func seulesLesSeriesDeLaBibliotheque() async throws {
        let (base, jeu) = try basePeuplee()

        let horsBibliotheque = Manga(
            sourceId: jeu.source.id,
            identifiantDistant: "serie-consultee",
            titre: "Serie seulement consultee",
            estDansBibliotheque: false
        )

        try await base.ecrivain.write { connexion in
            try horsBibliotheque.insert(connexion)
        }

        let series = try await MagasinDeVeilleDeChapitres(base: base).seriesSurveillees()

        #expect(series.count == 1)
        #expect(series.first?.id == jeu.manga.id)
        #expect(series.first?.source == SourceID(jeu.source.id))
    }

    @Test("Les chapitres deja importes comptent comme connus")
    func chapitresDeLaBaseConnus() async throws {
        let (base, jeu) = try basePeuplee()
        let series = try await MagasinDeVeilleDeChapitres(base: base).seriesSurveillees()
        let surveillee = try #require(series.first)

        #expect(surveillee.chapitresConnus == Set(jeu.chapitres.map(\.identifiantDistant)))
        #expect(surveillee.estUnePremiereVisite)
    }

    @Test("Un chapitre annonce et non importe reste connu au tour suivant")
    func chapitreAnnonceRetenu() async throws {
        let (base, jeu) = try basePeuplee()
        let magasin = MagasinDeVeilleDeChapitres(base: base)

        let deja = Set(jeu.chapitres.map(\.identifiantDistant))

        try await magasin.enregistrerLaVerification(
            de: jeu.manga.id,
            chapitresConnus: deja.union(["chapitre-neuf"]),
            le: reference
        )

        let surveillee = try #require(try await magasin.seriesSurveillees().first)

        #expect(surveillee.chapitresConnus.contains("chapitre-neuf"))
        #expect(surveillee.derniereVerification == reference)
        #expect(surveillee.estUnePremiereVisite == false)

        // Rien de nouveau au tour suivant, alors que la source annonce toujours
        // le meme chapitre supplementaire.
        let annonces = (deja.sorted() + ["chapitre-neuf"]).enumerated().map { rang, identifiant in
            ChapitreDistant(
                identifiant: identifiant,
                identifiantManga: jeu.manga.identifiantDistant,
                numero: Double(rang),
                ordre: rang
            )
        }

        #expect(NouveautesDeSerie.nouveautes(de: surveillee, annonces: annonces).isEmpty)
    }

    @Test("Les identifiants deja en base ne sont pas recopies dans la colonne de veille")
    func aucuneDuplicationDesChapitresImportes() async throws {
        let (base, jeu) = try basePeuplee()
        let magasin = MagasinDeVeilleDeChapitres(base: base)

        try await magasin.enregistrerLaVerification(
            de: jeu.manga.id,
            chapitresConnus: Set(jeu.chapitres.map(\.identifiantDistant)),
            le: reference
        )

        let retenus = try await base.ecrivain.read { connexion in
            try VeilleDeSeriePersistee.fetchOne(connexion, key: jeu.manga.id)?.identifiants
        }

        #expect(retenus?.isEmpty == true)
    }

    // MARK: Migration

    @Test("La migration de la veille est enregistree et purement additive")
    func migrationEnregistree() async throws {
        let base = try BaseDeDonnees.enMemoire()

        let appliquees = try await base.ecrivain.read { connexion in
            try String.fetchAll(connexion, sql: "SELECT identifier FROM grdb_migrations ORDER BY rowid")
        }

        #expect(appliquees.contains(SchemaDeBase.veilleDeChapitres))
        #expect(appliquees == SchemaDeBase.migrationsAttendues)

        let tables = try await base.ecrivain.read { connexion in
            try (
                connexion.tableExists(VeilleDeSeriePersistee.databaseTableName),
                connexion.tableExists(EtatDeVeillePersiste.databaseTableName)
            )
        }

        #expect(tables.0)
        #expect(tables.1)
    }

    @Test("La suppression d une serie emporte sa ligne de veille")
    func cascadeDeSuppression() async throws {
        let (base, jeu) = try basePeuplee()
        let magasin = MagasinDeVeilleDeChapitres(base: base)

        try await magasin.enregistrerLaVerification(de: jeu.manga.id, chapitresConnus: [], le: reference)

        try await base.ecrivain.write { connexion in
            _ = try Manga.deleteOne(connexion, key: jeu.manga.id)
        }

        let restantes = try await base.ecrivain.read { connexion in
            try VeilleDeSeriePersistee.fetchCount(connexion)
        }

        #expect(restantes == 0)
    }
}
