import Core

//
// CurseurDeProgression
//
// Sens du curseur de progression du lecteur, dicte par le sens de lecture.
//

/// Axe le long duquel la lecture progresse.
public enum AxeDeLecture: String, Sendable, CaseIterable, Hashable {
    case horizontal
    case vertical
}

/// Bord depuis lequel le curseur de progression se remplit.
public enum OrigineDuCurseur: String, Sendable, CaseIterable, Hashable {
    case gauche
    case droite
    case haut
}

/// Curseur de progression du lecteur.
///
/// Le curseur suit le sens de lecture de la serie, jamais la direction de
/// l interface. Une interface arabe affichant un manhwa garde un curseur qui
/// se remplit de la gauche vers la droite.
public struct CurseurDeProgression: Sendable, Hashable {
    /// Sens de lecture resolu pour la serie affichee.
    public let sens: SensDeLecture

    public init(sens: SensDeLecture) {
        self.sens = sens
    }

    /// Axe du curseur.
    public var axe: AxeDeLecture {
        sens.estVertical ? .vertical : .horizontal
    }

    /// Bord depuis lequel le curseur se remplit.
    public var origine: OrigineDuCurseur {
        switch sens {
        case .gaucheDroite: .gauche
        case .droiteGauche: .droite
        case .hautBas: .haut
        }
    }

    /// Position du curseur sur son axe pour une progression donnee.
    ///
    /// La position est toujours mesuree depuis le bord gauche sur un axe
    /// horizontal, et depuis le bord haut sur un axe vertical. C est la couche
    /// geometrique qui reste neutre, et le sens de lecture qui inverse la
    /// valeur quand il le faut.
    ///
    /// - Parameter progression: avancement dans le chapitre, entre zero et un.
    ///   Une valeur hors de cet intervalle est ramenee dedans.
    public func position(pourProgression progression: Double) -> Double {
        let bornee = Self.borner(progression)
        return sens.commenceParLaDroite ? 1 - bornee : bornee
    }

    /// Progression correspondant a une position sur l axe, pour un curseur que
    /// l utilisateur fait glisser.
    ///
    /// Reciproque exacte de `position(pourProgression:)`.
    public func progression(pourPosition position: Double) -> Double {
        let bornee = Self.borner(position)
        return sens.commenceParLaDroite ? 1 - bornee : bornee
    }

    private static func borner(_ valeur: Double) -> Double {
        min(max(valeur, 0), 1)
    }
}
