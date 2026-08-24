import SwiftUI

//
// Mouvement, section 1.9 de DESIGN-SPEC.md.
//
// Le mouvement explique une transition. Il n impressionne pas. Interdits :
// rebond sur les cartes, parallaxe, entree en cascade sur les grilles,
// rotation, particules. Le mode webtoon n a aucune animation de transition.
//

/// Courbe d une transition, dans la notation du tableau 1.9.
public enum CourbeDAnimation: Sendable, Equatable {
    case easeOut
    case easeInOut
    /// Fondu pur, sans glissement.
    case fondu
    /// Aller retour continu, utilise par la pulsation de squelette.
    case allerRetour
    /// Ressort, `spring(response:damping:)` du document.
    case ressort(reponse: Double, amortissement: Double)

    /// Notation telle qu elle apparait dans le tableau 1.9.
    public var notation: String {
        switch self {
        case .easeOut: "easeOut"
        case .easeInOut: "easeInOut"
        case .fondu: "fondu"
        case .allerRetour: "aller retour"
        case let .ressort(reponse, amortissement):
            "spring(response: \(reponse), damping: \(amortissement))"
        }
    }
}

/// Une transition du tableau 1.9.
public struct TransitionAnimee: Sendable, Equatable {
    /// Duree en millisecondes, comme dans le document.
    public let dureeEnMillisecondes: Double
    /// Courbe de la transition.
    public let courbe: CourbeDAnimation

    /// Duree en secondes, unite attendue par la couche vue.
    public var dureeEnSecondes: Double {
        dureeEnMillisecondes / 1000
    }

    /// Animation prete a etre appliquee.
    public var animation: Animation {
        switch courbe {
        case .easeOut:
            .easeOut(duration: dureeEnSecondes)
        case .easeInOut:
            .easeInOut(duration: dureeEnSecondes)
        case .fondu:
            .easeInOut(duration: dureeEnSecondes)
        case .allerRetour:
            .easeInOut(duration: dureeEnSecondes).repeatForever(autoreverses: true)
        case let .ressort(reponse, amortissement):
            .spring(response: reponse, dampingFraction: amortissement)
        }
    }

    /// Version appliquee quand Reduire les animations est actif.
    ///
    /// Le reglage systeme supprime toutes les translations et ramene chaque
    /// transition a un fondu de 100 ms. La vue demande cette variante, elle ne
    /// recalcule pas la regle de son cote.
    public var reduite: TransitionAnimee {
        Jetons.Mouvement.animationsReduites
    }
}

extension Jetons {
    /// Mouvement, section 1.9.
    public enum Mouvement {
        /// Survol, changement d etat local.
        public static let survol = TransitionAnimee(
            dureeEnMillisecondes: 120,
            courbe: .easeOut
        )

        /// Apparition de menu ou popover.
        public static let menu = TransitionAnimee(
            dureeEnMillisecondes: 180,
            courbe: .ressort(reponse: 0.28, amortissement: 0.86)
        )

        /// Modale entrante.
        public static let modale = TransitionAnimee(
            dureeEnMillisecondes: 240,
            courbe: .ressort(reponse: 0.34, amortissement: 0.82)
        )

        /// Changement d ecran principal, fondu croise pur, aucun glissement.
        public static let changementDEcran = TransitionAnimee(
            dureeEnMillisecondes: 200,
            courbe: .fondu
        )

        /// Tourne de page en mode pagine, desactivable par reglage.
        public static let tourneDePage = TransitionAnimee(
            dureeEnMillisecondes: 220,
            courbe: .easeInOut
        )

        /// Barres du lecteur, fondu plus translation de 8 px.
        public static let barresDuLecteur = TransitionAnimee(
            dureeEnMillisecondes: 200,
            courbe: .fondu
        )

        /// Pulsation de squelette, opacite 0.4 vers 0.8, aller retour.
        public static let pulsationDeSquelette = TransitionAnimee(
            dureeEnMillisecondes: 1200,
            courbe: .allerRetour
        )

        /// Survol de carte de serie, echelle 1.02.
        public static let survolDeCarte = TransitionAnimee(
            dureeEnMillisecondes: 120,
            courbe: .easeOut
        )

        /// Translation des barres du lecteur, en points.
        public static let translationDesBarres: Double = 8

        /// Echelle d une carte de serie au survol.
        public static let echelleDeCarteAuSurvol: Double = 1.02

        /// Opacite basse de la pulsation de squelette.
        public static let opaciteBasseDeSquelette: Double = 0.4

        /// Opacite haute de la pulsation de squelette.
        public static let opaciteHauteDeSquelette: Double = 0.8

        /// Transition appliquee quand Reduire les animations est actif.
        public static let animationsReduites = TransitionAnimee(
            dureeEnMillisecondes: 100,
            courbe: .fondu
        )

        /// Transitions indexees par leur libelle dans le tableau 1.9.
        public static let parTransition: [String: TransitionAnimee] = [
            "Survol, changement d etat local": survol,
            "Apparition de menu ou popover": menu,
            "Modale entrante": modale,
            "Changement d ecran principal": changementDEcran,
            "Tourne de page en mode pagine": tourneDePage,
            "Barres du lecteur": barresDuLecteur,
            "Pulsation de squelette": pulsationDeSquelette,
            "Survol de carte de serie": survolDeCarte,
        ]
    }
}
