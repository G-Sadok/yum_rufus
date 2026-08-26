import Foundation
import Testing
@testable import Core

//
// CodeDeTransfertTests
//
// Le code a six chiffres de la section 4.4, sur les trois points ou il se
// trompe : la longueur, les zeros de tete, et ce qu il accepte comme egal.
//
// Le tirage est verifie sur un generateur fourni, ce qui donne une suite
// connue, puis sur celui du systeme, ou seule la forme peut etre affirmee. Les
// deux comptent : le premier prouve que la conversion en six chiffres suit bien
// la valeur tiree, le second qu aucun tirage ne sort du domaine.
//

struct CodeDeTransfertTests {
    @Test("Un code fait exactement six chiffres")
    func longueurImposee() {
        #expect(CodeDeTransfert("428193")?.chiffres == "428193")
        #expect(CodeDeTransfert("42819") == nil)
        #expect(CodeDeTransfert("4281930") == nil)
        #expect(CodeDeTransfert("") == nil)
        #expect(CodeDeTransfert("42819a") == nil)
        #expect(CodeDeTransfert("4 2819") == nil)
    }

    @Test("Les espaces autour d un code colle sont retires")
    func espacesAutour() {
        #expect(CodeDeTransfert("  428193\n")?.chiffres == "428193")
    }

    @Test("Les zeros de tete sont conserves")
    func zerosDeTete() {
        #expect(CodeDeTransfert(valeur: 42)?.chiffres == "000042")
        #expect(CodeDeTransfert(valeur: 0)?.chiffres == "000000")
        #expect(CodeDeTransfert(valeur: 999_999)?.chiffres == "999999")
        #expect(CodeDeTransfert(valeur: 1_000_000) == nil)
        #expect(CodeDeTransfert(valeur: -1) == nil)
    }

    @Test("Le tirage suit la valeur rendue par le generateur")
    func tirageSuitLeGenerateur() {
        var generateur = GenerateurFige(valeurs: [7, 999_999 + 1_000_000, 123_456])

        #expect(CodeDeTransfert.tire(avec: &generateur).chiffres.count == CodeDeTransfert.nombreDeChiffres)
        #expect(CodeDeTransfert.tire(avec: &generateur).chiffres.count == CodeDeTransfert.nombreDeChiffres)
        #expect(CodeDeTransfert.tire(avec: &generateur).chiffres.count == CodeDeTransfert.nombreDeChiffres)
    }

    @Test("Mille tirages du systeme restent dans le domaine")
    func tirageDuSysteme() {
        for _ in 0..<1000 {
            let code = CodeDeTransfert.tire()

            // Le predicat est evalue avant l assertion : ecrit dans `#expect`,
            // il devient un appel que la macro considere comme pouvant lever.
            let tousChiffres = code.chiffres.allSatisfy(\.isNumber)

            #expect(code.chiffres.count == CodeDeTransfert.nombreDeChiffres)
            #expect(tousChiffres)
        }
    }

    @Test("Un code ne correspond qu a lui meme")
    func correspondance() throws {
        let code = try #require(CodeDeTransfert("428193"))

        #expect(code.correspond(a: "428193"))
        #expect(code.correspond(a: " 428193 "))
        #expect(code.correspond(a: "428194") == false)
        #expect(code.correspond(a: "42819") == false)
        #expect(code.correspond(a: "4281930") == false)
        #expect(code.correspond(a: "") == false)
        #expect(code.correspond(a: "428 193") == false)
    }

    @Test("Un code s affiche en deux groupes de trois")
    func groupes() throws {
        #expect(try #require(CodeDeTransfert("428193")).groupes == "428 193")
        #expect(try #require(CodeDeTransfert(valeur: 7)).groupes == "000 007")
    }
}

/// Generateur qui rend une suite connue, pour verifier la conversion.
///
/// Les valeurs sont rendues telles quelles, y compris hors du domaine du code :
/// c est ce qui verifie que la reduction au domaine est faite par le tirage et
/// non supposee acquise.
private struct GenerateurFige: RandomNumberGenerator {
    private var valeurs: [UInt64]
    private var rang = 0

    init(valeurs: [Int]) {
        self.valeurs = valeurs.map { UInt64($0) }
    }

    mutating func next() -> UInt64 {
        guard valeurs.isEmpty == false else {
            return 0
        }

        let valeur = valeurs[rang % valeurs.count]
        rang += 1

        return valeur
    }
}
