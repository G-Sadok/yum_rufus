import Core
import Foundation
import Testing

/// Couvre le premier critere de la fonctionnalite : aucun identifiant
/// n apparait dans UserDefaults ni dans la base.
///
/// Ces tests ne verifient pas un comportement, ils verifient une impossibilite.
/// Un test qui se contenterait de constater qu aucun mot de passe ne fuit
/// aujourd hui ne dirait rien de celui qui fuira apres la prochaine
/// modification. Ceux ci ferment les chemins : un type qui ne sait pas
/// s encoder ne peut pas etre range dans une liste de proprietes ni dans une
/// colonne, et une configuration sans champ secret ne peut pas en porter un.
struct IdentifiantsHorsDeLaBaseTests {
    // MARK: Impossibilite d encoder

    @Test("Les identifiants ne savent pas s encoder, ce qui leur ferme UserDefaults et la base")
    func identifiantsNonEncodables() {
        let type: Any.Type = IdentifiantsDeSource.self

        #expect(type is any Encodable.Type == false, "IdentifiantsDeSource a gagne une conformance a Encodable")
        #expect(type is any Decodable.Type == false, "IdentifiantsDeSource a gagne une conformance a Decodable")
    }

    @Test("Les identifiants ne sont pas une valeur de liste de proprietes")
    func identifiantsRefusesParUneListeDeProprietes() {
        // C est la verification concrete du meme fait. UserDefaults n accepte
        // que des valeurs de liste de proprietes, et une enumeration Swift a
        // valeurs associees n en est pas une.
        let identifiants = IdentifiantsDeSource.cleDApi("cle-api-jellyfin")

        #expect(PropertyListSerialization.propertyList(identifiants, isValidFor: .binary) == false)
    }

    // MARK: Impossibilite de configurer un secret

    /// Fragments qui trahissent un champ secret dans une cle serialisee.
    static let fragmentsInterdits = [
        "motdepasse",
        "password",
        "secret",
        "jeton",
        "token",
        "cledapi",
        "apikey",
        "identifiants",
    ]

    @Test("La configuration persistee ne porte aucun champ ou un secret puisse se glisser")
    func configurationSansChampSecret() throws {
        let configuration = ConfigurationDeSource(
            adresse: URL(string: "https://komga.exemple.test"),
            chemin: "/api/v1",
            authentification: .basique,
            accepteLeHttpEnClair: true
        )

        let suspectes = try Self.clesSuspectes(dans: configuration.donnees())

        #expect(suspectes.isEmpty, "Champ suspect dans la configuration : \(suspectes)")
    }

    @Test("La sauvegarde exportee ne porte aucun champ ou un secret puisse se glisser")
    func sauvegardeSansChampSecret() throws {
        var source = Source(type: .kavita, nom: "Serveur")
        try source.definirLaConfiguration(
            ConfigurationDeSource(adresse: URL(string: "https://kavita.exemple.test"), authentification: .jeton)
        )

        let suspectes = try Self.clesSuspectes(dans: SauvegardeDesSources([source]).donnees())

        #expect(suspectes.isEmpty, "Champ suspect dans la sauvegarde : \(suspectes)")
    }

    @Test("Le champ de nature d authentification dit la forme sans dire le secret")
    func natureSansSecret() throws {
        let configuration = ConfigurationDeSource(authentification: .cleDApi)
        let texte = try #require(try String(bytes: configuration.donnees(), encoding: .utf8))

        // La valeur nomme la forme, la cle du champ ne la nomme pas : c est
        // pour cela que le balayage porte sur les cles et non sur le texte.
        #expect(texte.contains("cleDApi"))
        #expect(try Self.clesSuspectes(dans: configuration.donnees()).isEmpty)
    }

    // MARK: Absence de UserDefaults

    @Test("Aucun fichier qui touche aux reglages du systeme ne touche aux identifiants")
    func aucunIdentifiantDansLesReglagesDuSysteme() throws {
        // Ce qui est cherche est un appel, pas une mention. La premiere version
        // de ce test cherchait le seul nom du type et se signalait elle meme,
        // en meme temps que le commentaire de `IdentifiantsDeSource` qui
        // explique justement pourquoi ce type n y va jamais. Un controle qui
        // interdit d ecrire le nom de ce qu il interdit ne tient pas une
        // semaine : la regle porte sur l acces au magasin de reglages, donc sur
        // le point ou sur la parenthese qui le suivent.
        //
        // Les marqueurs sont assembles a l execution pour la meme raison, celle
        // que donne deja ArborescenceTests.
        let reglages = "User" + "Defaults"
        let acces = [reglages + ".", reglages + "("]
        let marqueursDIdentifiants = [
            "IdentifiantsDeSource",
            "CodageDIdentifiants",
            "MagasinDIdentifiants",
            "motDePasse",
        ]

        let sources = try Self.sourcesDuProjet()

        // Un balayage qui ne trouverait aucun fichier passerait sans rien
        // verifier. Le projet en compte plus de deux cents, ce plancher tres
        // bas suffit a distinguer une arborescence vide d une arborescence
        // saine, sans avoir a etre corrige a chaque fichier ajoute.
        #expect(sources.count > 100, "Le balayage n a trouve que \(sources.count) fichiers")

        let fautifs = try sources
            .filter { fichier in
                let texte = try String(contentsOf: fichier, encoding: .utf8)

                return acces.contains { texte.contains($0) }
                    && marqueursDIdentifiants.contains { texte.contains($0) }
            }
            .map(\.lastPathComponent)

        #expect(fautifs.isEmpty, "Identifiant proche des reglages du systeme : \(fautifs)")
    }

    // MARK: Balayage

    /// Cles serialisees dont le nom trahit un champ secret, a tous les niveaux.
    static func clesSuspectes(dans donnees: Data) -> [String] {
        guard let objet = try? JSONSerialization.jsonObject(with: donnees) else {
            return []
        }

        return clesSuspectes(dans: objet).sorted()
    }

    private static func clesSuspectes(dans objet: Any) -> [String] {
        if let dictionnaire = objet as? [String: Any] {
            let ici = dictionnaire.keys.filter { cle in
                let minuscule = cle.lowercased()

                return fragmentsInterdits.contains { minuscule.contains($0) }
            }

            return ici + dictionnaire.values.flatMap { clesSuspectes(dans: $0) }
        }

        if let tableau = objet as? [Any] {
            return tableau.flatMap { clesSuspectes(dans: $0) }
        }

        return []
    }

    /// Tous les fichiers Swift du projet, paquets et application.
    static func sourcesDuProjet() throws -> [URL] {
        let racine = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // Core
            .deletingLastPathComponent() // Packages
            .deletingLastPathComponent() // racine du depot

        guard let parcours = FileManager.default.enumerator(
            at: racine,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return parcours
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
            .filter { $0.path.contains("/.build/") == false }
    }
}
