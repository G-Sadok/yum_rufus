import Foundation
import Testing
@testable import Core

//
// AdresseDuPairTests
//
// La regle qui decide si une connexion vient de cet appareil.
//
// Elle est couverte sur les trois facons connues de faire passer une machine
// distante pour locale, et sur les formes legitimes que le systeme rapporte
// vraiment. Un test qui se contenterait de `127.0.0.1` et de `192.168.1.20`
// passerait au vert avec une simple comparaison de tete, qui laisserait entrer
// un nom de domaine finissant en `127.0.0.1`.
//

struct AdresseDuPairTests {
    @Test(
        "Les adresses de bouclage sont locales",
        arguments: [
            "127.0.0.1",
            "127.0.0.53",
            "127.1.2.3",
            "127.255.255.255",
            "::1",
            "0:0:0:0:0:0:0:1",
            "0000:0000:0000:0000:0000:0000:0000:0001",
            "::ffff:127.0.0.1",
            "::1%lo0",
            "[::1]",
            "::FFFF:127.0.0.1",
        ]
    )
    func adressesDeBouclage(hote: String) {
        #expect(AdresseDuPair(hote: hote).estLocale, "\(hote)")
    }

    @Test(
        "Les adresses du reseau ne sont pas locales",
        arguments: [
            "192.168.1.20",
            "10.0.0.4",
            "172.16.3.9",
            "8.8.8.8",
            "0.0.0.0",
            "128.0.0.1",
            "2001:db8::1",
            "fe80::1",
            "::",
            "::ffff:192.168.1.20",
            "::ffff:8.8.8.8",
        ]
    )
    func adressesDuReseau(hote: String) {
        #expect(AdresseDuPair(hote: hote).estLocale == false, "\(hote)")
    }

    @Test(
        "Un nom n est jamais une adresse locale",
        arguments: [
            "localhost",
            "LOCALHOST",
            "localhost.",
            "127.0.0.1.exemple.net",
            "exemple.net",
            "bouclage",
        ]
    )
    func lesNomsSontRefuses(hote: String) {
        // Un nom se resout par le fichier des hotes de la machine, que toute
        // application locale peut avoir change. Accepter `localhost` reviendrait
        // a faire confiance a ce fichier la.
        #expect(AdresseDuPair(hote: hote).estLocale == false, "\(hote)")
    }

    @Test(
        "Une adresse mal formee n est pas locale",
        arguments: [
            "",
            "   ",
            "127.0.0",
            "127.0.0.1.1",
            "127.0.0.256",
            "0177.0.0.1",
            "00000127.0.0.1",
            "127.0.0.-1",
            "::1::1",
            "12345::1",
            "::gggg:1",
        ]
    )
    func adressesMalFormees(hote: String) {
        #expect(AdresseDuPair(hote: hote).estLocale == false, "\(hote)")
    }

    @Test("Les deux adresses de bouclage nommees sont locales")
    func lesDeuxBouclagesNommes() {
        #expect(AdresseDuPair.bouclageIPv4.estLocale)
        #expect(AdresseDuPair.bouclageIPv6.estLocale)
    }

    @Test("Les espaces autour d une adresse ne changent pas la reponse")
    func lesEspacesNeChangentRien() {
        #expect(AdresseDuPair(hote: "  127.0.0.1  ").estLocale)
        #expect(AdresseDuPair(hote: "  192.168.1.20  ").estLocale == false)
    }
}
