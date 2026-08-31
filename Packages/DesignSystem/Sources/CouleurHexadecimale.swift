import Foundation
import SwiftUI

/// Couleur d un jeton, portee exactement comme dans DESIGN-SPEC.md.
///
/// Le document ecrit ses couleurs en hexadecimal opaque, ou en `rgba` quand
/// elles portent une opacite. Le type garde les deux formes et sait rendre la
/// notation d origine, ce qui permet a la suite de tests de comparer le code au
/// document caractere par caractere plutot que par approximation numerique.
public struct CouleurHexadecimale: Sendable, Equatable, Hashable {
    /// Composante rouge, de 0 a 255.
    public let rouge: Int
    /// Composante verte, de 0 a 255.
    public let vert: Int
    /// Composante bleue, de 0 a 255.
    public let bleu: Int
    /// Opacite, de 0 a 1.
    public let opacite: Double

    /// Construit une couleur a partir de la valeur hexadecimale du document.
    ///
    /// - Parameters:
    ///   - valeur: les trois octets rouge, vert, bleu, par exemple `0x0E0E10`.
    ///   - opacite: 1 pour une couleur opaque, la valeur du `rgba` sinon.
    public init(_ valeur: UInt32, opacite: Double = 1) {
        rouge = Int((valeur >> 16) & 0xFF)
        vert = Int((valeur >> 8) & 0xFF)
        bleu = Int(valeur & 0xFF)
        self.opacite = opacite
    }

    /// Construit une couleur a partir de ses trois composantes.
    ///
    /// Reservee aux derivations calculees, comme celle de la lisibilite. Un
    /// jeton du document passe toujours par la forme hexadecimale, qui se
    /// compare caractere par caractere au tableau dont il sort.
    ///
    /// Les composantes hors bornes sont ramenees dans l intervalle plutot que
    /// de casser : une derivation qui deborde doit donner du blanc ou du noir,
    /// pas une couleur repliee de l autre cote de l echelle.
    public init(rouge: Int, vert: Int, bleu: Int, opacite: Double = 1) {
        self.rouge = min(max(rouge, 0), 255)
        self.vert = min(max(vert, 0), 255)
        self.bleu = min(max(bleu, 0), 255)
        self.opacite = opacite
    }

    /// Notation telle qu elle apparait dans DESIGN-SPEC.md.
    ///
    /// `#0E0E10` pour une couleur opaque, `rgba(0,0,0,0.45)` sinon.
    public var notation: String {
        let composantes = [rouge, vert, bleu].map(Self.enHexadecimal)

        guard opacite < 1 else {
            return "#" + composantes.joined()
        }

        let alpha = String(format: "%.2f", opacite)
        return "rgba(\(rouge),\(vert),\(bleu),\(alpha))"
    }

    /// Couleur prete a etre posee dans une vue.
    public var couleur: Color {
        Color(
            .sRGB,
            red: Double(rouge) / 255,
            green: Double(vert) / 255,
            blue: Double(bleu) / 255,
            opacity: opacite
        )
    }

    private static func enHexadecimal(_ composante: Int) -> String {
        let chiffres = String(composante, radix: 16, uppercase: true)
        return composante < 0x10 ? "0" + chiffres : chiffres
    }
}
