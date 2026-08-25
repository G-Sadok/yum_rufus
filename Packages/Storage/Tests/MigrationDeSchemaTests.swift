import Core
import Foundation
import GRDB
import Testing
@testable import Storage

/// Verifie que la migration d une base vide vers la version courante produit
/// exactement le schema decrit par la section 3 du cahier de developpement.
///
/// Ces tests lisent `sqlite_master` plutot que le code de migration. Une
/// migration qui compile mais qui oublie une colonne, un index ou une cle
/// etrangere passerait un test ecrit contre le code Swift, pas contre le
/// schema reellement en place.
struct MigrationDeSchemaTests {
    /// Colonnes attendues pour chaque entite de la section 3.1.
    static let colonnesAttendues: [String: Set<String>] = [
        "source": [
            "id", "type", "nom", "configurationChiffree", "versionExtension",
            "langue", "ordreAffichage", "estActive", "dateDerniereVerification",
            "etatConnexion",
        ],
        "manga": [
            "id", "sourceId", "identifiantDistant", "titre", "titresAlternatifs",
            "auteurs", "dessinateurs", "resume", "genres", "statut", "langue",
            "urlCouverture", "cheminCouvertureLocale", "sensLectureForce",
            "estDansBibliotheque", "dateAjout", "dateDerniereMiseAJour",
            "dateDerniereLecture", "chapitresNonLus",
        ],
        "chapitre": [
            "id", "mangaId", "identifiantDistant", "numero", "titre",
            "groupeTraduction", "langue", "datePublication", "nombrePages",
            "estLu", "pageAtteinte", "decalageDeDefilement", "dateLecture",
            "ordreDansSerie",
        ],
        "page": [
            "id", "chapitreId", "index", "urlDistante", "cheminLocal",
            "largeur", "hauteur", "octets",
        ],
        "categorie": ["id", "nom", "ordre"],
        "mangaCategorie": ["mangaId", "categorieId"],
        "ordreDeLecture": ["id", "nom", "descriptif"],
        "ordreDeLectureChapitre": ["ordreDeLectureId", "chapitreId", "position"],
        "entreeHistorique": [
            "id", "chapitreId", "dateLecture", "dureeSeconde", "pageAtteinte",
        ],
        "signet": [
            "id", "chapitreId", "pageIndex", "note", "dateCreation", "vignetteLocale",
        ],
        "telechargement": [
            "id", "chapitreId", "etat", "progression", "octetsTotal", "dateAjout",
            "messageErreur",
        ],
        "prereglageLecture": ["id", "nom", "donneesReglages"],
        "liaisonSuivi": [
            "id", "mangaId", "service", "identifiantDistant", "statut",
            "chapitreVu", "note", "dateSynchronisation",
        ],
        "reglageDeSensDeLecture": ["id", "sensGlobal"],
        "reglageDeListeDeChapitres": ["mangaId", "filtre", "critereDeTri", "ordreDeTri"],
    ]

    /// Les quatre index de la section 3.2, avec ce qui les distingue d un
    /// index ordinaire : la condition partielle et l ordre descendant.
    static let indexAttendus: [String: [String]] = [
        "idx_chapitre_manga_ordre": ["chapitre(mangaId, ordreDansSerie)"],
        "idx_chapitre_non_lu": ["chapitre(mangaId)", "WHERE estLu = 0"],
        "idx_manga_bibliotheque": ["manga(estDansBibliotheque, dateDerniereLecture)"],
        "idx_historique_date": ["entreeHistorique(dateLecture DESC)"],
    ]

    @Test("Une base vide migre jusqu a la version courante")
    func migrationDepuisUneBaseVide() throws {
        let file = try DatabaseQueue()
        let migrateur = SchemaDeBase.migrateur()

        let avant = try file.read { try migrateur.hasCompletedMigrations($0) }
        #expect(avant == false, "Une base neuve ne doit porter aucune migration")

        try migrateur.migrate(file)

        let appliquees = try file.read { try migrateur.appliedIdentifiers($0) }
        #expect(appliquees == Set(SchemaDeBase.migrationsAttendues))

        let apres = try file.read { try migrateur.hasCompletedMigrations($0) }
        #expect(apres, "La base doit etre a jour apres migration")
    }

    @Test("Rejouer la migration sur une base a jour ne change rien")
    func migrationIdempotente() throws {
        let file = try DatabaseQueue()
        let migrateur = SchemaDeBase.migrateur()

        try migrateur.migrate(file)
        let premierSchema = try file.read { try Self.empreinteDuSchema($0) }

        try migrateur.migrate(file)
        let secondSchema = try file.read { try Self.empreinteDuSchema($0) }

        #expect(premierSchema == secondSchema)
    }

    @Test("Toutes les entites de la section 3.1 existent avec leurs champs")
    func toutesLesEntitesExistent() throws {
        let base = try BaseDeDonnees.enMemoire()

        try base.ecrivain.read { connexion in
            for (table, colonnes) in Self.colonnesAttendues {
                let existe = try connexion.tableExists(table)
                #expect(existe, "Table absente : \(table)")

                let presentes = try Set(connexion.columns(in: table).map(\.name))
                let manquantes = colonnes.subtracting(presentes)

                #expect(manquantes.isEmpty, "Colonnes absentes dans \(table) : \(manquantes.sorted())")
            }
        }
    }

    @Test("Les quatre index de la section 3.2 sont crees")
    func lesQuatreIndexExistent() throws {
        let base = try BaseDeDonnees.enMemoire()

        try base.ecrivain.read { connexion in
            for (nom, fragments) in Self.indexAttendus {
                let definition = try String.fetchOne(
                    connexion,
                    sql: "SELECT sql FROM sqlite_master WHERE type = 'index' AND name = ?",
                    arguments: [nom]
                )

                let sql = try #require(definition, "Index absent : \(nom)")
                let normalise = sql.replacingOccurrences(of: "\n", with: " ")

                for fragment in fragments {
                    #expect(normalise.contains(fragment), "\(nom) ne porte pas \(fragment)")
                }
            }
        }
    }

    @Test("Supprimer une source emporte ses series, chapitres et pages")
    func laSuppressionCascade() throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 2)

        try base.ecrivain.write { connexion in
            _ = try Source.deleteOne(connexion, key: jeu.source.id)
        }

        try base.ecrivain.read { connexion in
            let series = try Manga.fetchCount(connexion)
            let chapitres = try Chapitre.fetchCount(connexion)
            let pages = try Page.fetchCount(connexion)

            #expect(series == 0, "La serie survit a la suppression de sa source")
            #expect(chapitres == 0, "Les chapitres survivent a la suppression de la serie")
            #expect(pages == 0, "Les pages survivent a la suppression du chapitre")
        }
    }

    /// Empreinte textuelle et stable du schema, tables, index et declencheurs
    /// compris. Deux schemas identiques produisent la meme empreinte.
    static func empreinteDuSchema(_ connexion: Database) throws -> [String] {
        try String.fetchAll(
            connexion,
            sql: """
            SELECT type || ' ' || name || ' ' || COALESCE(sql, '')
            FROM sqlite_master
            WHERE name NOT LIKE 'sqlite_%'
            ORDER BY type, name
            """
        )
    }
}
