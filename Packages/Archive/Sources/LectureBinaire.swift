import Foundation

//
// LectureBinaire
//
// Lecture d entiers petit boutiste dans un bloc d octets, avec bornes.
//
// Le format ZIP est integralement petit boutiste, quelle que soit la machine
// qui a produit l archive. Les accesseurs rendent une valeur optionnelle plutot
// que de faire confiance a l archive : une archive tronquee est un cas courant,
// pas un incident, et elle doit produire une erreur typee et non une lecture
// hors limites.
//

enum LectureBinaire {
    static func entier16(_ donnees: Data, a position: Int) -> UInt16? {
        entier(donnees, a: position)
    }

    static func entier32(_ donnees: Data, a position: Int) -> UInt32? {
        entier(donnees, a: position)
    }

    static func entier64(_ donnees: Data, a position: Int) -> UInt64? {
        entier(donnees, a: position)
    }

    /// Rend la valeur formee par les octets petit boutiste a la position donnee.
    private static func entier<Valeur: FixedWidthInteger & UnsignedInteger>(
        _ donnees: Data,
        a position: Int
    ) -> Valeur? {
        guard position >= 0 else { return nil }

        let debut = donnees.startIndex + position
        let fin = debut + MemoryLayout<Valeur>.size

        guard debut >= donnees.startIndex, fin <= donnees.endIndex else { return nil }

        var valeur = Valeur.zero
        for (rang, octet) in donnees[debut..<fin].enumerated() {
            valeur |= Valeur(octet) << (8 * rang)
        }

        return valeur
    }
}
