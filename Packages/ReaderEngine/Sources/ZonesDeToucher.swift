import Core

//
// ZonesDeToucher
//
// Traduction d un appui sur la surface de lecture en intention de navigation.
//
// La geometrie des quatre dispositions vit dans `DispositionDeZones`, cote
// modele, parce que la surimpression du tutoriel de la section 5.7 la dessine
// et que le systeme de design ne voit pas le moteur. Ce fichier ne fait que la
// traduction : un role de zone devient une intention, rien de plus.
//

/// Zones de toucher du lecteur.
///
/// Les quatre dispositions de la section 9 du cahier de developpement decoupent
/// la surface differemment, mais aucune ne decide seule : le sens de lecture les
/// oriente, et l option Inverser les zones echange leurs deux roles actifs.
public enum ZonesDeToucher {
    /// Part de la surface occupee par chaque bande active, section 5.7.
    public static let partDUneBandeActive = DispositionDeZones.partDUneBande

    /// Part de la surface occupee par la bande centrale, section 5.7.
    public static let partDeLaBandeCentrale = DispositionDeZones.partDeLaBandeCentrale

    /// Intention portee par un role de zone.
    public static func intention(pourRole role: RoleDeZone) -> IntentionDeNavigation {
        switch role {
        case .avance: .pageSuivante
        case .recule: .pagePrecedente
        case .menu: .aucune
        }
    }

    /// Intention produite par un appui sur la surface de lecture.
    ///
    /// - Parameters:
    ///   - abscisse: part de la largeur, mesuree depuis le bord gauche.
    ///   - ordonnee: part de la hauteur, mesuree depuis le bord haut. Les deux
    ///     se mesurent ainsi quel que soit le sens de lecture et quelle que
    ///     soit la direction de l interface.
    ///   - sens: sens de lecture resolu pour la serie.
    ///   - disposition: disposition choisie au reglage Zones de toucher.
    ///   - zonesInversees: option Inverser les zones.
    public static func intention(
        pourAbscisse abscisse: Double,
        ordonnee: Double,
        sens: SensDeLecture,
        disposition: DispositionDeZones,
        zonesInversees: Bool = false
    ) -> IntentionDeNavigation {
        intention(
            pourRole: disposition.role(
                pourAbscisse: abscisse,
                ordonnee: ordonnee,
                sens: sens,
                zonesInversees: zonesInversees
            )
        )
    }

    /// Intention produite par un appui mesure le long du seul axe de lecture,
    /// en disposition Standard.
    ///
    /// - Parameters:
    ///   - fraction: position de l appui le long de l axe de lecture, entre
    ///     zero et un. Elle se mesure depuis le bord gauche sur un axe
    ///     horizontal et depuis le bord haut sur un axe vertical.
    ///   - sens: sens de lecture resolu pour la serie.
    ///   - zonesInversees: option Inverser les zones. Elle echange les deux
    ///     bandes actives sans toucher a la bande du milieu.
    public static func intention(
        pourFraction fraction: Double,
        sens: SensDeLecture,
        zonesInversees: Bool = false
    ) -> IntentionDeNavigation {
        // Les trois bandes de Standard traversent toute la surface : la
        // coordonnee transversale ne change rien, on la pose au milieu.
        let milieu = 0.5

        return intention(
            pourAbscisse: sens.estVertical ? milieu : fraction,
            ordonnee: sens.estVertical ? fraction : milieu,
            sens: sens,
            disposition: .standard,
            zonesInversees: zonesInversees
        )
    }
}
