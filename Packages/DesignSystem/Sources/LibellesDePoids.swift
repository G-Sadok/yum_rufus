import Foundation

//
// Mise en forme d un poids en octets
//
// La file de telechargement de la section 4.11 et les trois ecrans de stockage
// de la section 15 affichent le meme genre de chiffre. Un seul calcul les sert,
// pour qu un chapitre annonce `32 Mo` dans la file et `32 Mo` dans l ecran de
// detail, jamais `32 Mo` d un cote et `30,5 Mio` de l autre.
//
// Base mille, comme le document qui ecrit `32 Mo`. Les paliers passent au
// multiple suivant a mille et non a mille vingt quatre, sans quoi un fichier de
// 999 500 octets s afficherait `1000 Ko`.
//
// Aucun formateur du systeme n intervient. Une chaine qui depend de la langue de
// l appareil rendrait la suite de tests incapable de verifier que la sous ligne
// du document est bien celle qui s affiche.
//

/// Motifs des quatre paliers de poids, pris dans le catalogue de chaines.
public struct MotifsDePoids: Sendable, Equatable {
    /// Motif du plus petit palier, `%lld o`.
    public let octets: String

    /// Motif du kilooctet, `%lld Ko`.
    public let kilooctets: String

    /// Motif du megaoctet, `%lld Mo`.
    public let megaoctets: String

    /// Motif du gigaoctet, `%.1f Go`.
    public let gigaoctets: String

    public init(octets: String, kilooctets: String, megaoctets: String, gigaoctets: String) {
        self.octets = octets
        self.kilooctets = kilooctets
        self.megaoctets = megaoctets
        self.gigaoctets = gigaoctets
    }
}

/// Poids mis en forme, du plus petit multiple qui tienne en trois chiffres.
public enum TexteDePoids {
    /// Poids affiche d un nombre d octets.
    public static func poids(_ octets: Int, motifs: MotifsDePoids) -> String {
        let base = Jetons.Telechargements.baseDesPoids

        guard octets >= base else {
            return String(format: motifs.octets, octets)
        }

        let enKo = octets / base

        guard enKo >= base else {
            return String(format: motifs.kilooctets, enKo)
        }

        let enMo = enKo / base

        guard enMo >= base else {
            return String(format: motifs.megaoctets, enMo)
        }

        return String(format: motifs.gigaoctets, Double(enMo) / Double(base))
    }
}

extension LibellesDeTelechargements {
    /// Motifs de poids de la file, servis au calcul commun.
    public var motifsDePoids: MotifsDePoids {
        MotifsDePoids(
            octets: poidsEnOctets,
            kilooctets: poidsEnKo,
            megaoctets: poidsEnMo,
            gigaoctets: poidsEnGo
        )
    }
}
