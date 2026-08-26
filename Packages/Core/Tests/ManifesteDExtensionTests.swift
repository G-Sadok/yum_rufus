import Foundation
import Testing
@testable import Core

/// Couvre le premier critere de la fonctionnalite : aucun code fourni par une
/// extension n est execute.
///
/// Le critere ne se prouve pas en montrant que rien ne s execute, ce qui ne se
/// mesure pas. Il se prouve par la forme du langage : ce qu une extension peut
/// ecrire est un jeu ferme de valeurs, et tout ce qui n en fait pas partie fait
/// refuser le paquet entier au lieu d etre ignore. Ces tests exercent la
/// frontiere dans les deux sens.
struct ManifesteDExtensionTests {
    // MARK: Lecture du manifeste de reference

    @Test("Le manifeste de reference se lit entierement")
    func lectureDuManifesteComplet() throws {
        let manifeste = try ManifesteDeTest.manifeste()

        #expect(manifeste.identifiant == "exemple.catalogue")
        #expect(manifeste.nom == "Catalogue Exemple")
        #expect(manifeste.version == VersionDExtension(majeure: 1, mineure: 4))
        #expect(manifeste.langue == "fr")
        #expect(manifeste.libelleDeVersion == "v1.4")
        #expect(manifeste.regles.pageDeDepart == 1)
        #expect(manifeste.regles.formatDeDate == "yyyy-MM-dd")
        #expect(manifeste.regles.chapitres.ordreInverse)
        #expect(manifeste.regles.sections.count == 2)
        #expect(manifeste.regles.regle(pour: .recentes) != nil)
        #expect(manifeste.regles.regle(pour: .tout) == nil)
    }

    /// Le manifeste de reference emploie toutes les cles du langage. S il se
    /// lit, aucune cle declaree par un type n a ete oubliee dans le vocabulaire,
    /// et le refus des cles inconnues ne frappera pas nos propres manifestes.
    @Test("Toutes les cles du manifeste de reference figurent au vocabulaire")
    func vocabulaireComplet() throws {
        let arbre = try ValeurJson(donnees: ManifesteDeTest.donnees)

        #expect(arbre.clesPresentes.subtracting(MotsClesDuManifeste.connus).isEmpty)
    }

    // MARK: Refus de ce qui n est pas du declaratif

    @Test("Une cle inconnue a la racine fait refuser le paquet")
    func cleInconnueALaRacine() {
        let donnees = ManifesteDeTest.avec(entree: "script", valeur: "\"return 1\"")

        #expect(throws: ErreurDExtension.cleInconnue(nom: "script")) {
            try ManifesteDExtension.lire(donnees)
        }
    }

    @Test("Une cle inconnue imbriquee fait refuser le paquet")
    func cleInconnueImbriquee() {
        let donnees = ManifesteDeTest.enRemplacant(
            "\"pageDeDepart\": 1,",
            par: "\"pageDeDepart\": 1, \"executable\": \"charge.dylib\","
        )

        #expect(throws: ErreurDExtension.cleInconnue(nom: "executable")) {
            try ManifesteDExtension.lire(donnees)
        }
    }

    @Test("Un refus de cle inconnue est un refus de securite")
    func refusDeSecurite() {
        #expect(ErreurDExtension.cleInconnue(nom: "script").estUnRefusDeSecurite)
        #expect(ErreurDExtension.manifesteIllisible.estUnRefusDeSecurite == false)
    }

    @Test("Une variable de gabarit inconnue fait refuser le paquet")
    func variableInconnue() {
        let donnees = ManifesteDeTest.enRemplacant("{texteRecherche}", par: "{commandeShell}")

        #expect(throws: ErreurDExtension.self) {
            try ManifesteDExtension.lire(donnees)
        }
    }

    @Test("Un document qui n est pas du JSON est refuse")
    func documentIllisible() {
        #expect(throws: ErreurDExtension.manifesteIllisible) {
            try ManifesteDExtension.lire(Data("ceci n est pas du json".utf8))
        }
        #expect(throws: ErreurDExtension.manifesteIllisible) {
            try ManifesteDExtension.lire(Data())
        }
    }

    // MARK: Version de format

    @Test("Un manifeste ecrit pour une version plus recente est refuse")
    func formatPlusRecent() {
        let donnees = ManifesteDeTest.enRemplacant("\"format\": 1,", par: "\"format\": 2,")

        #expect(throws: ErreurDExtension.formatNonPrisEnCharge(annoncee: 2, appliquee: 1)) {
            try ManifesteDExtension.lire(donnees)
        }
    }

    // MARK: Adresse de base

    @Test("Une adresse de base hors de la liste blanche est refusee")
    func adresseDeBaseHorsListe() {
        let donnees = ManifesteDeTest.enRemplacant(
            "\"adresseDeBase\": \"https://api.exemple.net\"",
            par: "\"adresseDeBase\": \"https://ailleurs.exemple.org\""
        )

        #expect(throws: ErreurDExtension.domaineMalForme(domaine: "ailleurs.exemple.org")) {
            try ManifesteDExtension.lire(donnees)
        }
    }

    @Test("Une adresse de base en clair est refusee")
    func adresseDeBaseEnClair() {
        let donnees = ManifesteDeTest.enRemplacant(
            "\"adresseDeBase\": \"https://api.exemple.net\"",
            par: "\"adresseDeBase\": \"http://api.exemple.net\""
        )

        #expect(throws: ErreurDExtension.self) {
            try ManifesteDExtension.lire(donnees)
        }
    }

    @Test("Un manifeste sans domaine est refuse")
    func aucunDomaine() {
        let donnees = ManifesteDeTest.enRemplacant(
            "\"domaines\": [\"api.exemple.net\", \"*.images.exemple.net\"],",
            par: "\"domaines\": [],"
        )

        #expect(throws: ErreurDExtension.aucunDomaineDeclare) {
            try ManifesteDExtension.lire(donnees)
        }
    }

    // MARK: Accord entre format et extraction

    @Test("Un selecteur dans une regle JSON est refuse")
    func selecteurDansUneRegleJson() {
        let donnees = ManifesteDeTest.enRemplacant(
            "\"elements\": { \"json\": \"$.items[*]\" }",
            par: "\"elements\": { \"html\": \"li.chapitre\" }"
        )

        #expect(throws: ErreurDExtension.self) {
            try ManifesteDExtension.lire(donnees)
        }
    }

    // MARK: Capacites

    @Test("Les capacites offertes sont celles que les regles savent servir")
    func capacitesServies() throws {
        let manifeste = try ManifesteDeTest.manifeste()

        #expect(manifeste.capacites.contains(.recherche))
        #expect(manifeste.capacites.contains(.pagination))
        #expect(manifeste.capacites.contains(.plusieursLangues))
        #expect(manifeste.capacites.contains(.telechargement))
        #expect(manifeste.capacites.contains(.progressionDistante) == false)
    }

    @Test("Une capacite annoncee sans regle n est pas offerte")
    func capaciteAnnonceeSansRegle() throws {
        let donnees = ManifesteDeTest.enRemplacant(
            "\"capacites\": [\"recherche\"",
            par: "\"capacites\": [\"filtres\", \"progressionDistante\", \"recherche\""
        )
        let manifeste = try ManifesteDExtension.lire(donnees)

        #expect(manifeste.capacitesAnnoncees.contains(.filtres))
        #expect(manifeste.capacites.contains(.filtres) == false)
        #expect(manifeste.capacites.contains(.progressionDistante) == false)
    }

    @Test("Une extension sans regle de recherche n offre pas la recherche")
    func rechercheAbsente() throws {
        let donnees = ManifesteDeTest.enRemplacant("\"recherche\": {", par: "\"details\": {")

        // Le remplacement produit deux cles `details` dans le meme objet, ce que
        // le decodeur JSON accepte en gardant la derniere. La regle de recherche
        // disparait donc, ce qui est exactement le cas a couvrir.
        let manifeste = try ManifesteDExtension.lire(donnees)

        #expect(manifeste.regles.recherche == nil)
        #expect(manifeste.capacites.contains(.recherche) == false)
    }

    // MARK: Champs de forme

    @Test("Un identifiant qui designe autre chose que l extension est refuse")
    func identifiantHorsForme() {
        #expect(ManifesteDExtension.identifiantEstUtilisable("exemple.catalogue"))
        #expect(ManifesteDExtension.identifiantEstUtilisable("exemple-2"))
        #expect(ManifesteDExtension.identifiantEstUtilisable("../autre") == false)
        #expect(ManifesteDExtension.identifiantEstUtilisable("Exemple") == false)
        #expect(ManifesteDExtension.identifiantEstUtilisable("exemple/catalogue") == false)
        #expect(ManifesteDExtension.identifiantEstUtilisable("") == false)
    }

    @Test("Une icone qui designe un fichier hors du paquet est refusee")
    func iconeHorsDuPaquet() {
        #expect(ManifesteDExtension.nomDeFichierEstUtilisable("icone.png"))
        #expect(ManifesteDExtension.nomDeFichierEstUtilisable("../../trousseau") == false)
        #expect(ManifesteDExtension.nomDeFichierEstUtilisable("/etc/passwd") == false)

        let donnees = ManifesteDeTest.enRemplacant("\"icone.png\"", par: "\"../../ailleurs.png\"")

        #expect(throws: ErreurDExtension.champManquant(nom: "icone")) {
            try ManifesteDExtension.lire(donnees)
        }
    }

    // MARK: Version

    @Test("La version se lit sous ses deux formes")
    func lectureDeLaVersion() throws {
        #expect(try VersionDExtension("1.4").texte == "1.4")
        #expect(try VersionDExtension("1.4.2").texte == "1.4.2")
        #expect(try VersionDExtension("2") == VersionDExtension(majeure: 2))
        #expect(try VersionDExtension("1.4") < VersionDExtension("1.10"))
        #expect(throws: ErreurDExtension.champManquant(nom: "version")) {
            try VersionDExtension("1.4.2.7")
        }
        #expect(throws: ErreurDExtension.champManquant(nom: "version")) {
            try VersionDExtension("derniere")
        }
    }
}
