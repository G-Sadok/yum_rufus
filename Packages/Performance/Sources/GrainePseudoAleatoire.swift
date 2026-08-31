import Foundation

//
// GrainePseudoAleatoire
//
// Le tirage du generateur de corpus.
//
// Le generateur systeme est exclu : un corpus tire au hasard change a chaque
// execution, et un budget qui rougit devient alors indiscernable d un corpus
// different. Celui ci est splitmix64, entierement determine par sa graine, donc
// deux machines qui partent de la meme graine obtiennent le meme corpus.
//

/// Tirage pseudo aleatoire reproductible.
public struct GrainePseudoAleatoire: RandomNumberGenerator, Sendable {
    private var etat: UInt64

    public init(graine: UInt64) {
        etat = graine
    }

    public mutating func next() -> UInt64 {
        etat &+= 0x9E37_79B9_7F4A_7C15

        var melange = etat
        melange = (melange ^ (melange >> 30)) &* 0xBF58_476D_1CE4_E5B9
        melange = (melange ^ (melange >> 27)) &* 0x94D0_49BB_1331_11EB

        return melange ^ (melange >> 31)
    }

    /// Un entier dans l intervalle demande, bornes comprises.
    public mutating func entier(de bas: Int, a haut: Int) -> Int {
        guard haut > bas else {
            return bas
        }

        return bas + Int(next() % UInt64(haut - bas + 1))
    }

    /// Un identifiant reproductible.
    ///
    /// Les entites du domaine sont identifiees par UUID, et un UUID tire au
    /// hasard ferait perdre la reproductibilite de tout le corpus, y compris
    /// l ordre dans lequel SQLite range les cles primaires en blob.
    public mutating func identifiant() -> UUID {
        let haut = next()
        let bas = next()

        return UUID(uuid: (
            UInt8(truncatingIfNeeded: haut >> 56),
            UInt8(truncatingIfNeeded: haut >> 48),
            UInt8(truncatingIfNeeded: haut >> 40),
            UInt8(truncatingIfNeeded: haut >> 32),
            UInt8(truncatingIfNeeded: haut >> 24),
            UInt8(truncatingIfNeeded: haut >> 16),
            UInt8(truncatingIfNeeded: haut >> 8),
            UInt8(truncatingIfNeeded: haut),
            UInt8(truncatingIfNeeded: bas >> 56),
            UInt8(truncatingIfNeeded: bas >> 48),
            UInt8(truncatingIfNeeded: bas >> 40),
            UInt8(truncatingIfNeeded: bas >> 32),
            UInt8(truncatingIfNeeded: bas >> 24),
            UInt8(truncatingIfNeeded: bas >> 16),
            UInt8(truncatingIfNeeded: bas >> 8),
            UInt8(truncatingIfNeeded: bas)
        ))
    }
}
