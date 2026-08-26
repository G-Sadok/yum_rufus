import Core
import Foundation
import Testing
@testable import Sources

//
// AnalyseDesRequetesDeDepotTests
//
// Le cadrage et le decoupage multipartie, c est a dire ce qui separe des octets
// arrivant par paquets d une requete utilisable.
//
// Le test qui compte le plus est celui du contenu qui finit par un saut de
// ligne. C est la facon dont les serveurs de depot ecrits a la va vite abiment
// un fichier sur deux : le `\r\n` qui precede la frontiere appartient a la
// frontiere, et le retirer du contenu enleve deux octets a une archive dont ce
// sont les derniers.
//

struct AnalyseDesRequetesDeDepotTests {
    // MARK: Cadrage

    @Test("Une requete coupee en trois n est rendue qu une fois complete")
    func requeteCoupeeEnTrois() throws {
        let complete = RequeteDeTest.deposer([(nom: "Tome 1.cbz", contenu: Data(repeating: 0x2A, count: 300))])
        var cadrage = CadrageDeRequete(plafondDuCorps: ServeurDeTransfertWifi.plafondParDepot)

        let tiers = complete.count / 3
        let debut = complete.startIndex

        #expect(try cadrage.ajouter(complete.subdata(in: debut..<(debut + tiers))) == nil)
        #expect(try cadrage.ajouter(complete.subdata(in: (debut + tiers)..<(debut + 2 * tiers))) == nil)

        let octets = try #require(try cadrage.ajouter(complete.subdata(in: (debut + 2 * tiers)..<complete.endIndex)))
        let requete = try RequeteDeDepot.analyser(octets)

        #expect(octets == complete)
        #expect(requete.methode == "POST")
        #expect(requete.chemin == CheminsDeLaReception.depot)
        #expect(try requete.corps.count == Int(#require(requete.entete("content-length"))))
    }

    @Test("Un corps annonce au dela du plafond est refuse sans etre lu")
    func corpsAuDelaDuPlafond() throws {
        let plafond = 1024
        var cadrage = CadrageDeRequete(plafondDuCorps: plafond)
        let tete = Data(
            """
            POST /depot HTTP/1.1\r
            Content-Type: multipart/form-data; boundary=x\r
            Content-Length: \(plafond + 1)\r
            \r

            """.utf8
        )

        #expect(throws: ErreurDeTransfert.depotTropVolumineux(plafondOctets: plafond)) {
            _ = try cadrage.ajouter(tete)
        }
    }

    @Test("Des entetes sans fin sont refuses avant de remplir la memoire")
    func entetesSansFin() throws {
        var cadrage = CadrageDeRequete(plafondDuCorps: ServeurDeTransfertWifi.plafondParDepot)
        let bavarde = Data(("GET / HTTP/1.1\r\nX: " + String(repeating: "a", count: 32 * 1024)).utf8)

        #expect(throws: ErreurDeTransfert.requeteMalformee) {
            _ = try cadrage.ajouter(bavarde)
        }
    }

    @Test("Le codage par morceaux est refuse")
    func codageParMorceauxRefuse() throws {
        var cadrage = CadrageDeRequete(plafondDuCorps: ServeurDeTransfertWifi.plafondParDepot)
        let requete = Data("POST /depot HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n".utf8)

        #expect(throws: ErreurDeTransfert.requeteMalformee) {
            _ = try cadrage.ajouter(requete)
        }
    }

    @Test("Une premiere ligne illisible est refusee")
    func premiereLigneIllisible() throws {
        #expect(throws: ErreurDeTransfert.requeteMalformee) {
            _ = try RequeteDeDepot.analyser(Data("BONJOUR\r\n\r\n".utf8))
        }
    }

    // MARK: Lecture

    @Test("La chaine de requete et l encodage en pourcentage sortent du chemin")
    func cheminDecode() throws {
        let requete = try RequeteDeDepot.analyser(Data("GET /de%20pot?x=1#ancre HTTP/1.1\r\n\r\n".utf8))

        #expect(requete.chemin == "/de pot")
    }

    @Test("Une cible absolue est ramenee a son chemin")
    func cibleAbsolue() throws {
        let requete = try RequeteDeDepot.analyser(Data("GET http://192.168.1.20:8080/depot HTTP/1.1\r\n\r\n".utf8))

        #expect(requete.chemin == CheminsDeLaReception.depot)
    }

    @Test("Les biscuits sont lus un par un")
    func biscuitsLus() throws {
        let requete = try RequeteDeDepot.analyser(
            Data("GET / HTTP/1.1\r\nCookie: reception=abc; autre=def\r\n\r\n".utf8)
        )

        #expect(requete.biscuits["reception"] == "abc")
        #expect(requete.biscuits["autre"] == "def")
    }

    @Test("Le type de contenu se lit sans ses parametres")
    func typeDeContenu() throws {
        let requete = try RequeteDeDepot.analyser(
            Data("POST /depot HTTP/1.1\r\nContent-Type: multipart/form-data; boundary=\"xyz\"\r\n\r\n".utf8)
        )

        #expect(requete.typeDeContenu == "multipart/form-data")
        #expect(requete.parametreDeContenu("boundary") == "xyz")
    }

    // MARK: Multipartie

    @Test("Un contenu qui finit par un saut de ligne arrive intact")
    func contenuTermineParUnSautDeLigne() throws {
        let contenu = Data([0x50, 0x4B, 0x05, 0x06, 0x0D, 0x0A])
        let requete = try RequeteDeDepot.analyser(
            RequeteDeTest.deposer([(nom: "Tome 1.cbz", contenu: contenu)])
        )
        let champs = try FormulaireDeDepot.champsMultipartie(requete.corps, frontiere: RequeteDeTest.frontiere)

        #expect(champs.count == 1)
        #expect(champs.first?.contenu == contenu)
    }

    @Test("Plusieurs fichiers sont rendus dans l ordre du formulaire")
    func plusieursFichiers() throws {
        let requete = try RequeteDeDepot.analyser(
            RequeteDeTest.deposer(
                [
                    (nom: "Tome 1.cbz", contenu: Data(repeating: 0x01, count: 10)),
                    (nom: "Tome 2.cbz", contenu: Data(repeating: 0x02, count: 20)),
                ]
            )
        )
        let champs = try FormulaireDeDepot.champsMultipartie(requete.corps, frontiere: RequeteDeTest.frontiere)

        #expect(champs.map(\.nomDeFichier) == ["Tome 1.cbz", "Tome 2.cbz"])
        #expect(champs.map(\.contenu.count) == [10, 20])
        let tousDesFichiers = champs.allSatisfy(\.estUnFichier)

        #expect(tousDesFichiers)
    }

    @Test("Un nom de fichier hors ASCII est lu sous sa forme etendue")
    func nomEtendu() throws {
        let frontiere = "limite"
        var corps = Data("--\(frontiere)\r\n".utf8)
        corps.append(
            Data(
                """
                Content-Disposition: form-data; name="fichiers"; filename="Tome 1.cbz";\
                 filename*=UTF-8''Tome%20%C3%A9t%C3%A9.cbz\r
                \r

                """.utf8
            )
        )
        corps.append(Data("archive".utf8))
        corps.append(Data("\r\n--\(frontiere)--\r\n".utf8))

        let champs = try FormulaireDeDepot.champsMultipartie(corps, frontiere: frontiere)

        // Le nom attendu s ecrit par ses points de code : le depot suit des
        // sources sans accent, et un accent litteral ici serait invisible dans
        // une revue.
        #expect(champs.first?.nomDeFichier == "Tome \u{e9}t\u{e9}.cbz")
    }

    @Test("Un corps sans frontiere est refuse")
    func corpsSansFrontiere() throws {
        #expect(throws: ErreurDeTransfert.requeteMalformee) {
            _ = try FormulaireDeDepot.champsMultipartie(Data("rien".utf8), frontiere: "limite")
        }
    }

    @Test("Le formulaire de code se lit avec ses caracteres encodes")
    func formulaireEncode() {
        let champs = FormulaireDeDepot.champsEncodes(Data("code=428+193&autre=a%20b".utf8))

        #expect(champs["code"] == "428 193")
        #expect(champs["autre"] == "a b")
    }
}
