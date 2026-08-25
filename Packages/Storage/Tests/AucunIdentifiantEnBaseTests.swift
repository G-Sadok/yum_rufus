import Core
import Foundation
import GRDB
import Testing
@testable import Storage

/// Couvre le premier critere de la fonctionnalite du cote de la base : aucun
/// identifiant n y apparait, et le deuxieme critere de bout en bout : supprimer
/// une source efface sa ligne et ses identifiants du meme geste.
///
/// Le balayage porte sur toutes les colonnes de toutes les lignes de toutes les
/// tables, et non sur la seule table `source`. Une fuite arrive rarement la ou
/// on la cherche : c est le champ libre d une autre table qui finit par porter
/// un mot de passe, et une verification limitee a la table attendue ne le
/// verrait jamais.
struct AucunIdentifiantEnBaseTests {
    static let motDePasse = "mot-de-passe-tres-reconnaissable"
    static let compte = "lecteur-de-la-maison"

    /// Une source de serveur configuree comme la feuille de configuration le
    /// ferait, avec ses identifiants ranges dans le trousseau.
    static func configurer(
        _ magasin: MagasinDeSources,
        _ trousseau: MagasinDIdentifiantsEnMemoire
    ) async throws -> Source {
        var source = Source(type: .komga, nom: "Serveur de la maison")
        try source.definirLaConfiguration(
            ConfigurationDeSource(
                adresse: URL(string: "https://komga.exemple.test"),
                authentification: .basique
            )
        )
        try magasin.enregistrer(source)

        await trousseau.enregistrer(
            .basique(compte: compte, motDePasse: motDePasse),
            pour: SourceID(source.id)
        )

        return source
    }

    // MARK: Le mot de passe n atteint pas la base

    @Test("Configurer une source avec un mot de passe ne l ecrit nulle part dans la base")
    func aucunMotDePasseDansLaBase() async throws {
        let base = try BaseDeDonnees.enMemoire()
        let trousseau = MagasinDIdentifiantsEnMemoire()
        _ = try await Self.configurer(MagasinDeSources(base: base), trousseau)

        let contenu = try Self.toutLeContenu(base)

        #expect(contenu.contains(Self.motDePasse) == false)
        #expect(contenu.contains(Self.compte) == false)
    }

    @Test("Le balayage saurait voir une fuite, il voit bien le reste de la configuration")
    func leBalayageNEstPasAveugle() async throws {
        let base = try BaseDeDonnees.enMemoire()
        _ = try await Self.configurer(MagasinDeSources(base: base), MagasinDIdentifiantsEnMemoire())

        let contenu = try Self.toutLeContenu(base)

        #expect(contenu.contains("komga.exemple.test"))
        #expect(contenu.contains("Serveur de la maison"))
    }

    @Test("La colonne de configuration ne se remplit que par un type sans champ secret")
    func configurationRelueSansSecret() async throws {
        let base = try BaseDeDonnees.enMemoire()
        let magasin = MagasinDeSources(base: base)
        let source = try await Self.configurer(magasin, MagasinDIdentifiantsEnMemoire())

        let relue = try #require(try magasin.source(source.id))
        let configuration = try #require(try relue.configuration())

        #expect(configuration.authentification == .basique)
        #expect(configuration.adresse?.host() == "komga.exemple.test")
    }

    // MARK: La suppression efface les deux

    @Test("Supprimer une source efface sa ligne et ses identifiants")
    func suppressionEffaceLaLigneEtLesIdentifiants() async throws {
        let base = try BaseDeDonnees.enMemoire()
        let magasin = MagasinDeSources(base: base)
        let trousseau = MagasinDIdentifiantsEnMemoire()
        let source = try await Self.configurer(magasin, trousseau)

        let echecs = await SuppressionDeSource(traces: [magasin, trousseau])
            .supprimer(SourceID(source.id))

        #expect(echecs.isEmpty)
        #expect(try magasin.source(source.id) == nil)
        #expect(await trousseau.identifiants(pour: SourceID(source.id)) == .aucun)
    }

    @Test("Supprimer une source emporte ses series, sans toucher aux autres sources")
    func suppressionEnCascade() async throws {
        let base = try BaseDeDonnees.enMemoire()
        let magasin = MagasinDeSources(base: base)
        let trousseau = MagasinDIdentifiantsEnMemoire()
        let supprimee = try await Self.configurer(magasin, trousseau)

        var conservee = Source(type: .fichiersLocaux, nom: "Dossier")
        conservee.ordreAffichage = 1
        try magasin.enregistrer(conservee)
        await trousseau.enregistrer(.cleDApi("cle-conservee"), pour: SourceID(conservee.id))

        // Le await n est pas decoratif : dans une fonction asynchrone, le
        // compilateur retient la surcharge asynchrone de GRDB. Sans lui, rien
        // ne compile, et l ecrire sync forcerait un blocage de fil.
        try await base.ecrivain.write { connexion in
            try Manga(sourceId: supprimee.id, identifiantDistant: "serie-1", titre: "Serie").insert(connexion)
        }

        await SuppressionDeSource(traces: [magasin, trousseau]).supprimer(SourceID(supprimee.id))

        let sourcesRestantes = try magasin.sources()
        let series = try await base.ecrivain.read { try Manga.fetchCount($0) }

        #expect(sourcesRestantes.map(\.id) == [conservee.id])
        #expect(series == 0)
        #expect(await trousseau.identifiants(pour: SourceID(conservee.id)) == .cleDApi("cle-conservee"))
    }

    // MARK: Balayage

    /// Tout le texte de toutes les colonnes de toutes les tables de la base.
    ///
    /// Les blobs y figurent aussi, decodes en UTF-8 quand ils le peuvent : la
    /// colonne de configuration en est un, et une fuite qui s y logerait
    /// echapperait a un balayage limite aux colonnes de texte.
    static func toutLeContenu(_ base: BaseDeDonnees) throws -> String {
        try base.ecrivain.read { connexion in
            let tables = try String.fetchAll(
                connexion,
                sql: "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'"
            )

            var morceaux: [String] = []

            for table in tables {
                for ligne in try Row.fetchAll(connexion, sql: "SELECT * FROM \"\(table)\"") {
                    for valeur in ligne.databaseValues {
                        morceaux.append(texte(de: valeur))
                    }
                }
            }

            return morceaux.joined(separator: "\n")
        }
    }

    private static func texte(de valeur: DatabaseValue) -> String {
        if let chaine = String.fromDatabaseValue(valeur) {
            return chaine
        }

        if let donnees = Data.fromDatabaseValue(valeur) {
            // Un blob qui n est pas de l UTF-8 ne peut porter aucune des
            // chaines cherchees. Le rendre par sa description suffit, et evite
            // de fabriquer un texte a partir d octets qui n en sont pas un.
            return String(bytes: donnees, encoding: .utf8) ?? valeur.description
        }

        return valeur.description
    }
}
