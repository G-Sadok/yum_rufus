import Core

//
// NavigationDeLecture
//
// Traduction d un geste ou d une touche en intention de navigation, sous le
// seul gouvernement du sens de lecture.
//

/// Direction dans laquelle le doigt se deplace pendant un balayage.
///
/// C est bien la direction du doigt, pas celle de la page qui arrive. En
/// droite a gauche la page suivante se trouve a gauche, donc le doigt part
/// vers la droite pour la faire entrer.
public enum BalayageDeNavigation: String, Sendable, CaseIterable, Hashable {
    case versLaGauche
    case versLaDroite
    case versLeHaut
    case versLeBas
}

/// Touche du clavier capable de faire avancer ou reculer la lecture.
///
/// Contrairement au balayage, une fleche designe la position de la page visee.
/// En droite a gauche, la page suivante est a gauche, donc c est la fleche
/// gauche qui avance.
public enum ToucheDeNavigation: String, Sendable, CaseIterable, Hashable {
    case flecheGauche
    case flecheDroite
    case flecheHaut
    case flecheBas
    case espace
    case espaceAvecMajuscule
}

/// Ce que la navigation doit faire une fois le geste interprete.
public enum IntentionDeNavigation: String, Sendable, CaseIterable, Hashable {
    case pageSuivante
    case pagePrecedente

    /// Le geste ne navigue pas. Il appartient a une autre couche : appel du
    /// menu, defilement du zoom, rien du tout.
    case aucune
}

/// Traduction des gestes et des touches en intentions, selon le sens de
/// lecture et lui seul.
///
/// Aucune fonction de ce type ne recoit la direction de l interface. C est
/// volontaire : la disposition de l interface ne doit jamais entrer dans une
/// decision de navigation.
public enum NavigationDeLecture {
    /// Intention produite par un balayage.
    public static func intention(
        pourBalayage balayage: BalayageDeNavigation,
        sens: SensDeLecture
    ) -> IntentionDeNavigation {
        switch sens {
        case .gaucheDroite:
            intentionHorizontale(balayage, balayageQuiAvance: .versLaGauche)
        case .droiteGauche:
            intentionHorizontale(balayage, balayageQuiAvance: .versLaDroite)
        case .hautBas:
            intentionVerticale(balayage)
        }
    }

    /// Intention produite par une touche du clavier.
    public static func intention(
        pourTouche touche: ToucheDeNavigation,
        sens: SensDeLecture
    ) -> IntentionDeNavigation {
        // L espace avance et le meme espace avec majuscule recule, quel que
        // soit le sens : ces deux touches ne portent aucune direction.
        switch touche {
        case .espace:
            return .pageSuivante
        case .espaceAvecMajuscule:
            return .pagePrecedente
        default:
            break
        }

        switch sens {
        case .gaucheDroite:
            return intentionDeFleche(touche, flecheQuiAvance: .flecheDroite, flecheQuiRecule: .flecheGauche)
        case .droiteGauche:
            return intentionDeFleche(touche, flecheQuiAvance: .flecheGauche, flecheQuiRecule: .flecheDroite)
        case .hautBas:
            return intentionDeFleche(touche, flecheQuiAvance: .flecheBas, flecheQuiRecule: .flecheHaut)
        }
    }

    /// Balayage qui fait avancer d une page dans ce sens de lecture.
    public static func balayageQuiAvance(_ sens: SensDeLecture) -> BalayageDeNavigation {
        switch sens {
        case .gaucheDroite: .versLaGauche
        case .droiteGauche: .versLaDroite
        case .hautBas: .versLeHaut
        }
    }

    /// Touche qui fait avancer d une page dans ce sens de lecture.
    public static func toucheQuiAvance(_ sens: SensDeLecture) -> ToucheDeNavigation {
        switch sens {
        case .gaucheDroite: .flecheDroite
        case .droiteGauche: .flecheGauche
        case .hautBas: .flecheBas
        }
    }

    private static func intentionHorizontale(
        _ balayage: BalayageDeNavigation,
        balayageQuiAvance: BalayageDeNavigation
    ) -> IntentionDeNavigation {
        switch balayage {
        case .versLeHaut, .versLeBas:
            .aucune
        default:
            balayage == balayageQuiAvance ? .pageSuivante : .pagePrecedente
        }
    }

    private static func intentionVerticale(_ balayage: BalayageDeNavigation) -> IntentionDeNavigation {
        switch balayage {
        case .versLeHaut: .pageSuivante
        case .versLeBas: .pagePrecedente
        case .versLaGauche, .versLaDroite: .aucune
        }
    }

    private static func intentionDeFleche(
        _ touche: ToucheDeNavigation,
        flecheQuiAvance: ToucheDeNavigation,
        flecheQuiRecule: ToucheDeNavigation
    ) -> IntentionDeNavigation {
        if touche == flecheQuiAvance {
            return .pageSuivante
        }

        if touche == flecheQuiRecule {
            return .pagePrecedente
        }

        return .aucune
    }
}
