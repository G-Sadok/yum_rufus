import Core

//
// ZonesDeToucher
//
// Decoupage de la surface de lecture en trois zones, orientees par le sens de
// lecture.
//

/// Zones de toucher du lecteur.
///
/// La surface se decoupe en trois bandes le long de l axe de lecture. La bande
/// du milieu n avance pas, elle appelle le menu. Les deux autres avancent ou
/// reculent selon le sens de lecture, et selon l option Inverser les zones de
/// la section 12.
public enum ZonesDeToucher {
    /// Part de la surface occupee par chaque bande active.
    public static let partDUneBandeActive = 1.0 / 3.0

    /// Intention produite par un appui sur la surface de lecture.
    ///
    /// - Parameters:
    ///   - fraction: position de l appui le long de l axe de lecture, entre
    ///     zero et un. Elle se mesure depuis le bord gauche sur un axe
    ///     horizontal et depuis le bord haut sur un axe vertical, quel que soit
    ///     le sens de lecture et quelle que soit la direction de l interface.
    ///   - sens: sens de lecture resolu pour la serie.
    ///   - zonesInversees: option Inverser les zones. Elle echange les deux
    ///     bandes actives sans toucher a la bande du milieu.
    public static func intention(
        pourFraction fraction: Double,
        sens: SensDeLecture,
        zonesInversees: Bool = false
    ) -> IntentionDeNavigation {
        let position = min(max(fraction, 0), 1)

        guard position < partDUneBandeActive || position > 1 - partDUneBandeActive else {
            return .aucune
        }

        let appuiSurLaBandeDeTete = position < partDUneBandeActive

        // En droite a gauche la page suivante se trouve a gauche, donc la
        // bande de tete, celle du bord gauche, avance. En gauche a droite comme
        // en vertical, c est la bande de queue qui avance.
        let avance = appuiSurLaBandeDeTete == sens.commenceParLaDroite

        if zonesInversees {
            return avance ? .pagePrecedente : .pageSuivante
        }

        return avance ? .pageSuivante : .pagePrecedente
    }
}
