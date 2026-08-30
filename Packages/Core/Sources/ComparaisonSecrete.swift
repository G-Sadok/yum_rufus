import Foundation

//
// ComparaisonSecrete
//
// La comparaison de deux secrets, ecrite une fois.
//
// Une comparaison de chaines s arrete au premier octet different. Le temps
// qu elle met revele donc la position du premier ecart, et un attaquant qui
// mesure ce temps devine le secret caractere par caractere : un jeton de
// soixante quatre chiffres se retrouve alors en quelques centaines d essais au
// lieu de deux puissance deux cent cinquante six.
//
// Le projet compare des secrets a trois endroits : le code de la reception
// Wi-Fi, le jeton de session de cette meme reception, et le jeton du pont
// navigateur. Trois copies de la meme boucle divergeraient au premier
// correctif, et une comparaison de secret qui diverge est exactement le genre
// de defaut qui ne se voit dans aucun test fonctionnel.
//
// `CodeDeTransfert` garde sa propre comparaison, et c est volontaire : elle
// ramene d abord la saisie a la forme d un code et compare quand meme quand la
// forme est mauvaise, pour ne pas repondre plus vite a une saisie mal formee
// qu a un code faux. Cette regle la est propre au code a six chiffres et n a
// rien a faire dans une comparaison generale.
//

/// Comparaison de deux secrets sans laisser mesurer ou ils different.
public enum ComparaisonSecrete {
    /// Vrai quand les deux textes portent exactement les memes octets.
    ///
    /// La difference de longueur sort tout de suite, et c est sans consequence :
    /// la longueur d un jeton n est pas un secret, elle est fixee par le format
    /// et connue de qui lit le code de l extension.
    public static func egales(_ attendu: String, _ presente: String) -> Bool {
        egales(Array(attendu.utf8), Array(presente.utf8))
    }

    /// Vrai quand les deux suites portent exactement les memes octets.
    public static func egales(_ attendu: [UInt8], _ presente: [UInt8]) -> Bool {
        guard attendu.count == presente.count else {
            return false
        }

        var ecart: UInt8 = 0

        for index in attendu.indices {
            ecart |= attendu[index] ^ presente[index]
        }

        return ecart == 0
    }
}
