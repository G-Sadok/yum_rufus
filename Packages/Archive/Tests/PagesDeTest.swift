import Foundation

//
// PagesDeTest
//
// Contenus de page reproductibles.
//
// Les octets sont tires d un generateur congruentiel a graine fixe : ils sont
// les memes a chaque execution, differents d une page a l autre, et assez peu
// repetitifs pour qu une page rendue a la place d une autre se voie tout de
// suite. Un contenu constant laisserait passer une confusion de pages.
//

enum PagesDeTest {
    /// Taille d une page de test, choisie pour qu une archive de vingt quatre
    /// pages depasse la zone de recherche de l enregistrement de fin, soit
    /// 65557 octets. Sans ce depassement, lire la fin du fichier reviendrait a
    /// lire tout le fichier et le test d acces direct ne prouverait rien.
    static let taille = 8192

    /// Contenu de la page numerotee.
    static func contenu(_ numero: Int, taille: Int = taille) -> Data {
        var octets = [UInt8]()
        octets.reserveCapacity(taille)

        var etat = UInt32(truncatingIfNeeded: numero &* 2_654_435_761) | 1
        for _ in 0..<taille {
            etat = etat &* 1_664_525 &+ 1_013_904_223
            octets.append(UInt8((etat >> 24) & 0xFF))
        }

        return Data(octets)
    }

    /// Contenu tres compressible, pour eprouver le chemin deflate.
    static func contenuRepetitif(_ numero: Int, taille: Int = taille) -> Data {
        Data(repeating: UInt8(truncatingIfNeeded: numero), count: taille)
    }

    /// Nom de la page numerotee.
    static func nom(_ numero: Int) -> String {
        "page\(numero).jpg"
    }

    /// Archive de vingt quatre pages stockees, dans l ordre naturel.
    static func archiveDeVingtQuatrePages() -> ArchiveDeTest {
        ConstructeurDeZip.archive((1...24).map { numero in
            EntreeDeTest(nom(numero), contenu: contenu(numero))
        })
    }
}
