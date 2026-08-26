import Core
import Foundation
import Testing

/// Couvre la moitie modele du deuxieme critere : ce que la liste blanche
/// autorise et ce qu elle refuse. Le blocage effectif d une requete et sa
/// journalisation sont couverts cote transport, dans le paquet Sources.
///
/// Les cas rassembles ici sont ceux par lesquels une liste blanche se contourne
/// en pratique : la casse, le point final, le sous domaine non demande,
/// l adresse numerique, le nom sans point, et l ecriture Unicode d un nom qui
/// se compare en punycode.
struct ListeBlancheDeDomainesTests {
    // MARK: Lecture d un domaine declare

    @Test("Un domaine simple ne couvre que lui meme")
    func domaineSimple() throws {
        let domaine = try DomaineAutorise("api.exemple.net")

        #expect(domaine.inclutLesSousDomaines == false)
        #expect(domaine.couvre("api.exemple.net"))
        #expect(domaine.couvre("images.api.exemple.net") == false)
        #expect(domaine.couvre("exemple.net") == false)
    }

    @Test("Une etoile couvre le domaine et ses sous domaines")
    func domaineAvecEtoile() throws {
        let domaine = try DomaineAutorise("*.exemple.net")

        #expect(domaine.inclutLesSousDomaines)
        #expect(domaine.texte == "*.exemple.net")
        #expect(domaine.couvre("exemple.net"))
        #expect(domaine.couvre("images.exemple.net"))
        #expect(domaine.couvre("a.b.exemple.net"))
        #expect(domaine.couvre("exemple.net.attaquant.org") == false)
        #expect(domaine.couvre("faux-exemple.net") == false)
    }

    @Test("La casse et le point final ne changent rien")
    func normalisation() throws {
        let domaine = try DomaineAutorise("API.Exemple.NET")

        #expect(domaine.hote == "api.exemple.net")
        #expect(domaine.couvre("API.EXEMPLE.NET"))
        #expect(domaine.couvre("api.exemple.net."))
        #expect(domaine.couvre(" api.exemple.net "))
    }

    // MARK: Ce qu un manifeste n a pas le droit de declarer

    @Test("Une adresse numerique est refusee")
    func adresseNumerique() {
        #expect(throws: ErreurDExtension.self) {
            try DomaineAutorise("127.0.0.1")
        }
        #expect(throws: ErreurDExtension.self) {
            try DomaineAutorise("192.168.1.20")
        }
    }

    @Test("Un nom sans point est refuse")
    func nomSansPoint() {
        #expect(throws: ErreurDExtension.self) {
            try DomaineAutorise("localhost")
        }
        #expect(throws: ErreurDExtension.self) {
            try DomaineAutorise("*")
        }
    }

    @Test("Un nom non ASCII est refuse, la forme punycode est attendue")
    func nomNonAscii() throws {
        #expect(throws: ErreurDExtension.self) {
            try DomaineAutorise("exempleaccentue.net".replacingOccurrences(of: "e", with: "\u{00e9}"))
        }

        let punycode = try DomaineAutorise("xn--exemple-cya.net")

        #expect(punycode.couvre("xn--exemple-cya.net"))
    }

    @Test("Une adresse complete n est pas un domaine")
    func adresseComplete() {
        #expect(throws: ErreurDExtension.self) {
            try DomaineAutorise("https://api.exemple.net/catalogue")
        }
        #expect(throws: ErreurDExtension.self) {
            try DomaineAutorise("api.exemple.net:8443")
        }
        #expect(throws: ErreurDExtension.self) {
            try DomaineAutorise("compte@api.exemple.net")
        }
    }

    @Test("Une etiquette mal formee est refusee")
    func etiquetteMalFormee() {
        #expect(throws: ErreurDExtension.self) {
            try DomaineAutorise("-exemple.net")
        }
        #expect(throws: ErreurDExtension.self) {
            try DomaineAutorise("exemple-.net")
        }
        #expect(throws: ErreurDExtension.self) {
            try DomaineAutorise("exemple..net")
        }
    }

    // MARK: La liste elle meme

    @Test("La liste trie et dedoublonne ce qu elle recoit")
    func listeTrieeEtDedoublonnee() throws {
        let liste = try ListeBlancheDeDomaines(domaines: [
            DomaineAutorise("zeta.exemple.net"),
            DomaineAutorise("alpha.exemple.net"),
            DomaineAutorise("alpha.exemple.net"),
        ])

        #expect(liste.domaines.map(\.texte) == ["alpha.exemple.net", "zeta.exemple.net"])
    }

    @Test("Une liste vide ne couvre rien")
    func listeVide() {
        let liste = ListeBlancheDeDomaines(domaines: [])

        #expect(liste.estVide)
        #expect(liste.autorise("api.exemple.net") == false)
    }

    @Test("Une adresse en clair est refusee meme sur un domaine autorise")
    func adresseEnClair() throws {
        let liste = try ListeBlancheDeDomaines(domaines: [DomaineAutorise("api.exemple.net")])

        #expect(try liste.autorise(#require(URL(string: "https://api.exemple.net/serie"))))
        #expect(try liste.autorise(#require(URL(string: "http://api.exemple.net/serie"))) == false)
    }

    /// Une adresse dont la partie utilisateur porte un domaine autorise est le
    /// piege classique : elle se lit comme si elle allait chez exemple.net,
    /// et elle va chez attaquant.org.
    @Test("Un domaine autorise place en partie utilisateur ne trompe pas la liste")
    func domaineEnPartieUtilisateur() throws {
        let liste = try ListeBlancheDeDomaines(domaines: [DomaineAutorise("api.exemple.net")])
        let piege = try #require(URL(string: "https://api.exemple.net@attaquant.org/serie"))

        #expect(ListeBlancheDeDomaines.hote(de: piege) == "attaquant.org")
        #expect(liste.autorise(piege) == false)
    }

    @Test("Une adresse sans hote est refusee")
    func adresseSansHote() throws {
        let liste = try ListeBlancheDeDomaines(domaines: [DomaineAutorise("api.exemple.net")])

        #expect(try liste.autorise(#require(URL(string: "file:///etc/passwd"))) == false)
        #expect(try liste.autorise(#require(URL(string: "https:///serie"))) == false)
    }
}
