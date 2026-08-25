import SwiftUI

//
// Application d un niveau d elevation a une vue, section 1.8 de DESIGN-SPEC.md.
//
// Le niveau 0 ne pose rien, et c est le cas de toutes les cartes du produit :
// aucune ombre sur une carte, la hierarchie passe par la valeur de surface. Le
// niveau 1 ajoute son ombre et le contour `border` que le document lui associe.
// Le voile du niveau 2 appartient a la vue qui presente la modale, pas a la
// modale elle meme, il n est donc pas pose ici.
//

extension View {
    /// Applique l ombre et le complement d un niveau d elevation.
    ///
    /// - Parameters:
    ///   - niveau: niveau du tableau 1.8.
    ///   - rayon: rayon de la forme sur laquelle le contour se pose.
    ///   - palette: palette courante, pour la couleur du contour.
    public func elevation(
        _ niveau: NiveauDElevation,
        rayon: Double,
        palette: Palette
    ) -> some View {
        modifier(ElevationAppliquee(niveau: niveau, rayon: rayon, palette: palette))
    }
}

/// Ombre et contour d un niveau d elevation.
private struct ElevationAppliquee: ViewModifier {
    let niveau: NiveauDElevation
    let rayon: Double
    let palette: Palette

    func body(content: Content) -> some View {
        content
            .overlay(contour)
            .shadow(
                color: couleurDeLOmbre,
                radius: niveau.ombre?.rayon ?? 0,
                y: niveau.ombre?.decalageVertical ?? 0
            )
    }

    @ViewBuilder
    private var contour: some View {
        if niveau.complement == .contour {
            RoundedRectangle(cornerRadius: rayon, style: .continuous)
                .strokeBorder(
                    palette.semantiques.border.couleur,
                    lineWidth: Jetons.Fenetre.epaisseurDuFilet
                )
        }
    }

    private var couleurDeLOmbre: Color {
        niveau.ombre?.couleur.couleur ?? .clear
    }
}
