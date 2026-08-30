import Foundation
import Testing
@testable import Core

//
// JetonDuPontTests
//
// Le jeton du pont, son magasin, et l envoi que le navigateur pousse.
//
// Le tirage est verifie sur un generateur connu, ce qui prouve la forme sans
// dependre du hasard, et sur deux tirages du systeme, ce qui prouve qu il n est
// pas constant. La comparaison est verifiee sur un jeton juste, un jeton faux
// de meme longueur, et deux longueurs differentes : c est le cas de longueur
// differente qui casse une boucle ecrite un peu vite.
//

struct JetonDuPontTests {
    @Test("Un jeton tire porte soixante quatre chiffres hexadecimaux")
    func formeDuJetonTire() {
        var generateur = GenerateurConnu(mots: [0x0123_4567_89AB_CDEF, 0, .max, 1])
        let jeton = JetonDuPont.tire(avec: &generateur)

        #expect(jeton.valeur.count == JetonDuPont.nombreDeChiffres)
        #expect(jeton.valeur == "0123456789abcdef0000000000000000ffffffffffffffff0000000000000001")
    }

    @Test("Deux tirages du systeme ne rendent pas le meme jeton")
    func deuxTiragesDonnentDeuxJetons() {
        #expect(JetonDuPont.tire() != JetonDuPont.tire())
    }

    @Test("Un jeton se relit depuis son texte")
    func relectureDuTexte() throws {
        let jeton = JetonDuPont.tire()
        let relu = try #require(JetonDuPont(jeton.valeur))

        #expect(relu == jeton)
    }

    @Test("Les espaces et la casse autour d un jeton colle sont absorbes")
    func espacesEtCasseAbsorbes() throws {
        let texte = String(repeating: "AB", count: JetonDuPont.nombreDeChiffres / 2)
        let jeton = try #require(JetonDuPont("  \(texte)\n"))

        #expect(jeton.valeur == texte.lowercased())
    }

    @Test(
        "Un texte qui n est pas un jeton est refuse",
        arguments: [
            "",
            "abc",
            String(repeating: "a", count: 63),
            String(repeating: "a", count: 65),
            String(repeating: "g", count: 64),
            String(repeating: "a", count: 63) + " ",
        ]
    )
    func textesRefuses(texte: String) {
        #expect(JetonDuPont(texte) == nil, "\(texte.count) caracteres")
    }

    @Test("Le jeton reconnait son texte et refuse tout le reste")
    func comparaisonDuJeton() throws {
        let valeur = String(repeating: "5", count: JetonDuPont.nombreDeChiffres)
        let jeton = try #require(JetonDuPont(valeur))

        #expect(jeton.correspond(a: valeur))
        #expect(jeton.correspond(a: String(repeating: "5", count: 63) + "6") == false)
        #expect(jeton.correspond(a: "6" + String(repeating: "5", count: 63)) == false)
        #expect(jeton.correspond(a: String(repeating: "5", count: 63)) == false)
        #expect(jeton.correspond(a: valeur + "5") == false)
        #expect(jeton.correspond(a: "") == false)
    }

    @Test("La description d un jeton ne porte jamais sa valeur")
    func descriptionMasquee() {
        let jeton = JetonDuPont.tire()

        #expect("\(jeton)".contains(jeton.valeur) == false)
        #expect(String(reflecting: jeton).contains(jeton.valeur) == false)
    }
}

/// La comparaison de secrets, sur laquelle repose le refus d un jeton faux.
struct ComparaisonSecreteTests {
    @Test("Deux textes identiques sont egaux")
    func textesIdentiques() {
        #expect(ComparaisonSecrete.egales("abc", "abc"))
        #expect(ComparaisonSecrete.egales("", ""))
    }

    @Test("Un ecart n importe ou est vu")
    func ecartVuPartout() {
        #expect(ComparaisonSecrete.egales("abc", "abd") == false)
        #expect(ComparaisonSecrete.egales("abc", "bbc") == false)
        #expect(ComparaisonSecrete.egales("abc", "ab") == false)
        #expect(ComparaisonSecrete.egales("ab", "abc") == false)
    }

    @Test("Les octets non ASCII se comparent comme les autres")
    func octetsNonAscii() {
        #expect(ComparaisonSecrete.egales("cle", "cle"))
        #expect(ComparaisonSecrete.egales("cle", "clé") == false)
    }
}

/// Le magasin en memoire, celui que les tests et les apercus emploient.
struct MagasinDeJetonDuPontTests {
    @Test("Un magasin neuf ne porte aucun jeton")
    func magasinNeufSansJeton() async {
        let magasin = MagasinDeJetonDuPontEnMemoire()

        #expect(await magasin.jeton() == nil)
    }

    @Test("Le jeton range se relit")
    func jetonRangeSeRelit() async {
        let magasin = MagasinDeJetonDuPontEnMemoire()
        let jeton = JetonDuPont.tire()

        await magasin.enregistrer(jeton)

        #expect(await magasin.jeton() == jeton)
    }

    @Test("La revocation efface la ligne")
    func revocationEffaceLaLigne() async {
        let magasin = MagasinDeJetonDuPontEnMemoire(jeton: JetonDuPont.tire())

        await magasin.revoquer()

        #expect(await magasin.jeton() == nil)
        #expect(await magasin.revocations == 1)
    }

    @Test("La revocation d un magasin vide n est pas une erreur")
    func revocationIdempotente() async {
        let magasin = MagasinDeJetonDuPontEnMemoire()

        await magasin.revoquer()
        await magasin.revoquer()

        #expect(await magasin.jeton() == nil)
    }

    @Test("Le renouvellement remplace le jeton en place")
    func renouvellementRemplace() async throws {
        let ancien = JetonDuPont.tire()
        let magasin = MagasinDeJetonDuPontEnMemoire(jeton: ancien)

        let neuf = try await magasin.renouveler()

        #expect(neuf != ancien)
        #expect(await magasin.jeton() == neuf)
    }

    @Test("Le jeton en place survit a une demande de jeton")
    func jetonOuNouveauGardeCeQuIlTrouve() async throws {
        let existant = JetonDuPont.tire()
        let magasin = MagasinDeJetonDuPontEnMemoire(jeton: existant)

        let trouve = try await magasin.jetonOuNouveau()

        #expect(trouve == existant)
    }

    @Test("Un magasin vide se voit poser un jeton a la demande")
    func jetonOuNouveauEnPoseUn() async throws {
        let magasin = MagasinDeJetonDuPontEnMemoire()
        let tire = try await magasin.jetonOuNouveau()

        #expect(await magasin.jeton() == tire)
    }

    @Test("Le jeton du pont est range sous un service de trousseau qui lui est propre")
    func serviceDeTrousseauSepare() {
        #expect(RequeteDeTrousseau.serviceDuPont != RequeteDeTrousseau.serviceParDefaut)
        #expect(RequeteDeTrousseau.serviceDuPont != RequeteDeTrousseau.serviceDesSuivis)
    }
}

/// Un generateur qui rend une suite connue, pour prouver la forme du tirage.
private struct GenerateurConnu: RandomNumberGenerator {
    private var mots: [UInt64]
    private var suivant = 0

    init(mots: [UInt64]) {
        self.mots = mots
    }

    mutating func next() -> UInt64 {
        defer { suivant += 1 }

        return mots.isEmpty ? 0 : mots[suivant % mots.count]
    }
}
