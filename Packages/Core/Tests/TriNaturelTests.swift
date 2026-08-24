import Core
import Foundation
import Testing

/// Couvre le comparateur de tri naturel de la section 5.3 du cahier de
/// developpement.
///
/// Le jeu de paires est la piece maitresse : chaque paire est ecrite dans
/// l ordre attendu, et la suite verifie les deux sens plus la reflexivite, ce
/// qui interdit a une implementation de repondre au hasard.
struct TriNaturelTests {
    /// Une paire de noms dont l ordre attendu est connu.
    ///
    /// L etiquette dit quelle combinaison de prefixes la paire couvre, pour
    /// que l echec nomme la regle cassee plutot que deux chaines nues.
    struct Paire: Sendable, CustomStringConvertible {
        let etiquette: String
        let avant: String
        let apres: String

        var description: String {
            "\(etiquette) : \(avant) avant \(apres)"
        }
    }

    /// Paires ordonnees, le premier nom doit venir avant le second.
    static let pairesOrdonnees: [Paire] = [
        Paire(etiquette: "chiffre simple contre deux chiffres", avant: "page2.jpg", apres: "page10.jpg"),
        Paire(etiquette: "neuf contre dix", avant: "page9.jpg", apres: "page10.jpg"),
        Paire(etiquette: "zeros initiaux a largeur egale", avant: "page002.jpg", apres: "page010.jpg"),
        Paire(etiquette: "meme valeur, moins de zeros initiaux devant", avant: "page2.jpg", apres: "page002.jpg"),
        Paire(etiquette: "un zero initial", avant: "page1.jpg", apres: "page01.jpg"),
        Paire(etiquette: "zeros initiaux contre valeur superieure", avant: "page0002.jpg", apres: "page3.jpg"),
        Paire(etiquette: "aucun prefixe", avant: "2.jpg", apres: "10.jpg"),
        Paire(etiquette: "entier avant son decimal", avant: "page1.jpg", apres: "page1.5.jpg"),
        Paire(etiquette: "decimal avant l entier suivant", avant: "page1.5.jpg", apres: "page2.jpg"),
        Paire(etiquette: "decimales comparees rang par rang", avant: "page1.10.jpg", apres: "page1.5.jpg"),
        Paire(etiquette: "zero final de decimale", avant: "page1.5.jpg", apres: "page1.50.jpg"),
        Paire(etiquette: "prefixe de dossier commun", avant: "chapitre1/page1.jpg", apres: "chapitre1/page2.jpg"),
        Paire(etiquette: "numero de dossier", avant: "chapitre2/page1.jpg", apres: "chapitre10/page1.jpg"),
        Paire(etiquette: "nom sans numero avant nom numerote", avant: "page.jpg", apres: "page1.jpg"),
        Paire(etiquette: "casse melangee, majuscule a gauche", avant: "Page1.jpg", apres: "page2.jpg"),
        Paire(etiquette: "casse melangee, majuscule a droite", avant: "page1.jpg", apres: "Page2.jpg"),
        Paire(etiquette: "meme nom, la majuscule departage", avant: "Page1.jpg", apres: "page1.jpg"),
        Paire(etiquette: "extensions differentes", avant: "page1.jpg", apres: "page1.png"),
        Paire(etiquette: "extensions de meme famille", avant: "page1.jpeg", apres: "page1.png"),
        Paire(etiquette: "prefixe alphabetique different", avant: "cover.jpg", apres: "page1.jpg"),
        Paire(etiquette: "separateur souligne", avant: "scan_001.jpg", apres: "scan_002.jpg"),
        Paire(etiquette: "suffixe alphabetique apres le numero", avant: "scan_2_a.jpg", apres: "scan_2_b.jpg"),
        Paire(etiquette: "trois champs numerotes, dernier champ", avant: "v01_c003_p01.jpg", apres: "v01_c003_p02.jpg"),
        Paire(etiquette: "trois champs numerotes, premier champ", avant: "v01_c003_p10.jpg", apres: "v02_c001_p01.jpg"),
        Paire(etiquette: "champs separes par des espaces", avant: "vol1 ch2 p3.jpg", apres: "vol1 ch10 p1.jpg"),
        Paire(etiquette: "zero contre un", avant: "0.jpg", apres: "1.jpg"),
        Paire(etiquette: "prefixe alphabetique proche", avant: "abc.jpg", apres: "abd.jpg"),
        Paire(etiquette: "numero nu contre numero suivi de lettre", avant: "page10.jpg", apres: "page10a.jpg"),
        Paire(etiquette: "separateur tiret", avant: "page-1.jpg", apres: "page-2.jpg"),
        Paire(
            etiquette: "numero plus grand qu un entier 64 bits",
            avant: "123456789012345678901.jpg",
            apres: "123456789012345678902.jpg"
        ),
    ]

    @Test("Chaque paire connue est ordonnee dans le bon sens", arguments: pairesOrdonnees)
    func paireOrdonnee(_ paire: Paire) {
        #expect(TriNaturel.comparer(paire.avant, paire.apres) == .orderedAscending, "\(paire)")
    }

    @Test("La comparaison est antisymetrique", arguments: pairesOrdonnees)
    func comparaisonAntisymetrique(_ paire: Paire) {
        #expect(TriNaturel.comparer(paire.apres, paire.avant) == .orderedDescending, "\(paire)")
    }

    @Test("Un nom est egal a lui meme", arguments: pairesOrdonnees)
    func comparaisonReflexive(_ paire: Paire) {
        #expect(TriNaturel.comparer(paire.avant, paire.avant) == .orderedSame)
        #expect(TriNaturel.comparer(paire.apres, paire.apres) == .orderedSame)
    }

    @Test("page2 passe avant page10")
    func criterePrincipal() {
        #expect(TriNaturel.precede("page2.jpg", "page10.jpg"))
        #expect(TriNaturel.precede("page10.jpg", "page2.jpg") == false)
    }

    @Test("Le tri lexicographique et le tri naturel divergent bien")
    func divergenceAvecLeTriLexicographique() {
        let noms = ["page10.jpg", "page2.jpg", "page1.jpg"]

        #expect(noms.sorted() == ["page1.jpg", "page10.jpg", "page2.jpg"])
        #expect(TriNaturel.trier(noms) == ["page1.jpg", "page2.jpg", "page10.jpg"])
    }

    @Test("Une sequence complete de pages revient dans l ordre de lecture")
    func sequenceComplete() {
        let desordre = [
            "page11.jpg",
            "page2.jpg",
            "page1.jpg",
            "page20.jpg",
            "page3.jpg",
            "page10.jpg",
            "page1.5.jpg",
        ]

        #expect(TriNaturel.trier(desordre) == [
            "page1.jpg",
            "page1.5.jpg",
            "page2.jpg",
            "page3.jpg",
            "page10.jpg",
            "page11.jpg",
            "page20.jpg",
        ])
    }

    @Test("Les zeros initiaux ne changent pas la valeur comparee")
    func zerosInitiaux() {
        #expect(TriNaturel.trier(["page010.jpg", "page002.jpg", "page0001.jpg"]) == [
            "page0001.jpg",
            "page002.jpg",
            "page010.jpg",
        ])
    }

    @Test("Les numeros decimaux s intercalent entre deux entiers")
    func numerosDecimaux() {
        #expect(TriNaturel.trier(["chapitre2.jpg", "chapitre1.5.jpg", "chapitre1.jpg"]) == [
            "chapitre1.jpg",
            "chapitre1.5.jpg",
            "chapitre2.jpg",
        ])
    }

    @Test("Le point d une extension n est jamais lu comme une virgule decimale")
    func pointDExtension() {
        // Sans cette regle, page1.jpg et page1.5.jpg seraient departages par
        // une comparaison de jpg contre 5, ce qui n a aucun sens.
        #expect(TriNaturel.precede("page1.jpg", "page1.5.jpg"))
        #expect(TriNaturel.precede("page9.jpg", "page10.jpg"))
    }

    @Test("Les doublons de numero sont departages par le reste du nom")
    func doublonsDeNumero() {
        #expect(TriNaturel.trier(["page1_b.jpg", "page1_a.jpg", "page1.jpg"]) == [
            "page1.jpg",
            "page1_a.jpg",
            "page1_b.jpg",
        ])
    }

    @Test("Le tri est total, deux noms distincts ne sont jamais equivalents")
    func triTotal() {
        let noms = Self.pairesOrdonnees.flatMap { [$0.avant, $0.apres] }

        for gauche in noms {
            for droite in noms where gauche != droite {
                #expect(
                    TriNaturel.comparer(gauche, droite) != .orderedSame,
                    "\(gauche) et \(droite) ne devraient pas etre equivalents"
                )
            }
        }
    }

    @Test("Le tri est idempotent")
    func triIdempotent() {
        let noms = Self.pairesOrdonnees.flatMap { [$0.avant, $0.apres] }
        let unePasse = TriNaturel.trier(noms)

        #expect(TriNaturel.trier(unePasse) == unePasse)
    }

    @Test("Le tri accepte une cle extraite d un element quelconque")
    func triSurCle() {
        struct Entree: Equatable {
            let chemin: String
        }

        let entrees = [Entree(chemin: "page10.jpg"), Entree(chemin: "page2.jpg")]

        #expect(TriNaturel.trier(entrees, selon: \.chemin) == [
            Entree(chemin: "page2.jpg"),
            Entree(chemin: "page10.jpg"),
        ])
    }

    @Test("Une chaine vide se compare sans planter")
    func chaineVide() {
        #expect(TriNaturel.comparer("", "") == .orderedSame)
        #expect(TriNaturel.precede("", "page1.jpg"))
    }
}
