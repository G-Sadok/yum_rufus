import Core
import Foundation
import Testing

/// Couvre le troisieme critere de la fonctionnalite : l export de sauvegarde
/// n inclut jamais les mots de passe.
///
/// Les tests balaient le JSON produit a la recherche des secrets, plutot que de
/// comparer champ par champ. Une comparaison de champs ne verrait pas un secret
/// arrive par un chemin auquel elle ne pense pas, or c est exactement ce genre
/// de chemin qui produit une fuite.
struct SauvegardeSansMotDePasseTests {
    static let identifiants = IdentifiantsDeSource.basique(
        compte: "lecteur-de-la-maison",
        motDePasse: "mot-de-passe-tres-reconnaissable"
    )

    /// Une source de serveur, configuree comme la feuille de configuration le
    /// ferait, avec ses identifiants ranges a part.
    static func sourceConfiguree() throws -> Source {
        var source = Source(type: .komga, nom: "Serveur de la maison", ordreAffichage: 2)
        try source.definirLaConfiguration(
            ConfigurationDeSource(
                adresse: URL(string: "https://komga.exemple.test"),
                chemin: "/api/v1",
                authentification: .basique
            )
        )

        return source
    }

    @Test("Le JSON exporte ne contient aucun mot de passe")
    func exportSansMotDePasse() throws {
        let sauvegarde = try SauvegardeDesSources([Self.sourceConfiguree()])
        let texte = try #require(String(bytes: sauvegarde.donnees(), encoding: .utf8))

        for secret in Self.identifiants.valeursSecretes {
            #expect(texte.contains(secret) == false, "Secret exporte : \(secret.count) caracteres")
        }
    }

    @Test("Le JSON exporte ne contient pas non plus le nom du compte")
    func exportSansCompte() throws {
        let sauvegarde = try SauvegardeDesSources([Self.sourceConfiguree()])
        let texte = try #require(String(bytes: sauvegarde.donnees(), encoding: .utf8))

        #expect(texte.contains("lecteur-de-la-maison") == false)
    }

    @Test("Le balayage saurait voir un secret, il voit bien le reste de la configuration")
    func leBalayageNEstPasAveugle() throws {
        let sauvegarde = try SauvegardeDesSources([Self.sourceConfiguree()])
        let texte = try #require(String(bytes: sauvegarde.donnees(), encoding: .utf8))

        #expect(texte.contains("komga.exemple.test"))
        #expect(texte.contains("Serveur de la maison"))
    }

    @Test("Une colonne de configuration remplie hors du type ferme n est pas recopiee dans l export")
    func laColonneNEstJamaisRecopieeTelleQuelle() throws {
        // Le seul chemin d ecriture legitime passe par un type sans champ
        // secret. Ce test simule ce qu une version anterieure, ou un bogue,
        // aurait pu deposer dans la colonne : la sauvegarde refuse plutot que
        // d emporter des octets qu elle ne sait pas lire.
        var source = try Self.sourceConfiguree()
        source.configurationChiffree = Data(#"{"motDePasse":"mot-de-passe-tres-reconnaissable"}"#.utf8)

        #expect(throws: ErreurDeConfigurationDeSource.illisible) {
            try SauvegardeDesSources([source])
        }
    }

    @Test("Une source exportee puis restauree retrouve sa configuration, sans ses identifiants")
    func allerRetourDeLaSauvegarde() throws {
        let origine = try Self.sourceConfiguree()
        let relue = try SauvegardeDesSources(donnees: SauvegardeDesSources([origine]).donnees())

        let restauree = try #require(relue.sources.first).source()

        #expect(restauree.id == origine.id)
        #expect(restauree.nom == origine.nom)
        #expect(try restauree.configuration() == origine.configuration())
        #expect(try restauree.configuration()?.authentification == .basique)
    }

    @Test("Une source restauree revient non verifiee, la sauvegarde ne promet aucune connexion")
    func restaurationSansEtatDeConnexion() throws {
        var origine = try Self.sourceConfiguree()
        origine.etatConnexion = .connecte
        origine.dateDerniereVerification = Date(timeIntervalSince1970: 1_700_000_000)

        let restauree = try SourceExportee(origine).source()

        #expect(restauree.etatConnexion == .nonVerifie)
        #expect(restauree.dateDerniereVerification == nil)
    }

    @Test("Une sauvegarde d une autre version est refusee, jamais lue de travers")
    func versionInconnueRefusee() throws {
        let etrangere = SauvegardeDesSources(version: 99, sources: [])
        let donnees = try etrangere.donnees()

        #expect(throws: ErreurDeSauvegarde.formatInconnu(version: 99)) {
            try SauvegardeDesSources(donnees: donnees)
        }
    }

    @Test("Un fichier qui n est pas une sauvegarde est refuse")
    func fichierEtrangerRefuse() {
        #expect(throws: ErreurDeSauvegarde.fichierIllisible) {
            try SauvegardeDesSources(donnees: Data([0x00, 0x01]))
        }
    }
}
