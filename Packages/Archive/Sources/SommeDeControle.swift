import Foundation

//
// SommeDeControle
//
// CRC 32 tel que le definit le format ZIP, polynome inverse 0xEDB88320.
//
// L implementation est ecrite ici plutot que prise dans zlib pour eviter une
// dependance de lien a un paquet metier qui n en a aucune autre. Le cout est de
// vingt lignes, le gain est un paquet Archive qui se compile partout sans
// reglage d editeur de liens.
//

enum SommeDeControle {
    /// Table du CRC 32, calculee une fois au premier usage.
    private static let table: [UInt32] = (0..<256).map { rang -> UInt32 in
        var valeur = UInt32(rang)
        for _ in 0..<8 {
            valeur = (valeur & 1) == 1 ? (valeur >> 1) ^ 0xEDB8_8320 : valeur >> 1
        }
        return valeur
    }

    /// Rend le CRC 32 des octets fournis.
    static func crc32(_ donnees: Data) -> UInt32 {
        var accumulateur: UInt32 = 0xFFFF_FFFF

        for octet in donnees {
            let rang = Int((accumulateur ^ UInt32(octet)) & 0xFF)
            accumulateur = (accumulateur >> 8) ^ table[rang]
        }

        return accumulateur ^ 0xFFFF_FFFF
    }
}
