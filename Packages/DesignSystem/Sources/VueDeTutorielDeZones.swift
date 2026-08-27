import Core
import SwiftUI

//
// Surimpression du tutoriel des zones de toucher, section 5.7 de DESIGN-SPEC.
//
// C est la seule fois du produit ou les zones deviennent visibles. La vue ne
// decide ni de leur decoupage, qui vient de `DispositionDeZones`, ni de leur
// duree, qui vient de `TutorielDeZones` : elle recoit une liste de zones et la
// dessine. Une liste vide ne dessine rien, ce qui est l etat normal du lecteur.
//
// La surimpression ne capte aucun appui. Les zones qu elle montre restent
// actives dessous pendant les quatre secondes : le tutoriel explique le
// decoupage, il ne suspend pas la lecture.
//

/// Zones de toucher rendues visibles pendant le tutoriel de premiere ouverture.
public struct VueDeTutorielDeZones: View {
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var animationsReduites

    private let zones: [ZoneDeToucher]
    private let libelles: LibellesDeZonesDeToucher

    /// - Parameters:
    ///   - zones: zones a montrer, telles que `TutorielDeZones` les rend. Vide
    ///     hors du tutoriel.
    ///   - libelles: etiquettes prises dans le catalogue de chaines.
    public init(zones: [ZoneDeToucher], libelles: LibellesDeZonesDeToucher) {
        self.zones = zones
        self.libelles = libelles
    }

    public var body: some View {
        GeometryReader { geometrie in
            ZStack {
                ForEach(Array(zones.enumerated()), id: \.offset) { _, zone in
                    aplat(de: zone, dans: geometrie.size)
                }
            }
            .frame(width: geometrie.size.width, height: geometrie.size.height)
        }
        .allowsHitTesting(false)
        .animation(animation, value: zones)
    }

    private func aplat(de zone: ZoneDeToucher, dans taille: CGSize) -> some View {
        Rectangle()
            .fill(AplatDeZone.couleur(de: zone.role, palette: palette).couleur)
            .opacity(AplatDeZone.opacite(de: zone.role))
            .frame(
                width: zone.largeur * taille.width,
                height: zone.hauteur * taille.height
            )
            .position(
                x: (zone.abscisse + zone.largeur / 2) * taille.width,
                y: (zone.ordonnee + zone.hauteur / 2) * taille.height
            )
            .accessibilityElement()
            .accessibilityLabel(libelles.etiquette(de: zone.role))
    }

    private var animation: Animation {
        animationsReduites
            ? Jetons.Mouvement.animationsReduites.animation
            : Jetons.ZonesDeToucher.apparition.animation
    }
}

/// Aplat pose sur une zone pendant le tutoriel.
///
/// Sorti de la vue pour rester verifiable : c est la seule regle de la
/// surimpression qui associe une couleur a un role, et la suite de tests la
/// compare a la phrase du document.
enum AplatDeZone {
    /// Couleur de l aplat.
    ///
    /// L accent ne decore jamais. Ici il signale les seules zones ou un appui
    /// agit sur la lecture. La zone de menu porte du blanc, qui ne designe
    /// aucune action.
    static func couleur(de role: RoleDeZone, palette: Palette) -> CouleurHexadecimale {
        role.navigue
            ? palette.semantiques.accent
            : Jetons.ZonesDeToucher.couleurDeZoneDeMenu
    }

    /// Opacite de l aplat, section 5.7.
    static func opacite(de role: RoleDeZone) -> Double {
        role.navigue
            ? Jetons.ZonesDeToucher.opaciteDeZoneActive
            : Jetons.ZonesDeToucher.opaciteDeZoneDeMenu
    }
}
