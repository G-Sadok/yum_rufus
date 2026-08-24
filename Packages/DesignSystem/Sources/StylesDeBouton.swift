import SwiftUI

//
// Boutons, section 4.6 de DESIGN-SPEC.md.
//
// Deux variantes suffisent a la coquille : principal, aplat accent, et
// secondaire, fond `surface.menu` avec contour. Les variantes discrete et
// destructive arrivent avec les ecrans qui en ont besoin.
//

/// Bouton principal, aplat `accent`, texte blanc en graisse 600.
public struct BoutonPrincipal: ButtonStyle {
    @Environment(\.palette) private var palette

    /// Hauteur du bouton, choisie dans le tableau des contextes de 4.6.
    public let hauteur: Double
    /// Rayon du bouton, choisi dans le meme tableau.
    public let rayon: Double

    public init(hauteur: Double, rayon: Double) {
        self.hauteur = hauteur
        self.rayon = rayon
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .style(Jetons.Typo.body.enGraisse(.semiGrasse))
            .foregroundStyle(palette.textes.onAccent.couleur)
            .padding(.horizontal, Jetons.Bouton.remplissageHorizontal)
            .frame(minHeight: hauteur)
            .background(fond(pressee: configuration.isPressed))
            .contentShape(Rectangle())
    }

    private func fond(pressee: Bool) -> some View {
        let couleur = pressee
            ? palette.semantiques.accentPressed.couleur
            : palette.semantiques.accent.couleur

        return RoundedRectangle(cornerRadius: rayon, style: .continuous).fill(couleur)
    }
}

/// Bouton secondaire, fond `surface.menu`, contour `border`.
public struct BoutonSecondaire: ButtonStyle {
    @Environment(\.palette) private var palette

    /// Hauteur du bouton.
    public let hauteur: Double
    /// Rayon du bouton.
    public let rayon: Double

    public init(hauteur: Double, rayon: Double) {
        self.hauteur = hauteur
        self.rayon = rayon
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .style(Jetons.Typo.body)
            .foregroundStyle(palette.textes.primary.couleur)
            .padding(.horizontal, Jetons.Bouton.remplissageHorizontal)
            .frame(minHeight: hauteur)
            .background(fond(pressee: configuration.isPressed))
            .contentShape(Rectangle())
    }

    private func fond(pressee: Bool) -> some View {
        let couleur = pressee
            ? palette.surfaces.selected.couleur
            : palette.surfaces.menu.couleur

        return RoundedRectangle(cornerRadius: rayon, style: .continuous)
            .fill(couleur)
            .overlay {
                RoundedRectangle(cornerRadius: rayon, style: .continuous)
                    .strokeBorder(
                        palette.semantiques.border.couleur,
                        lineWidth: Jetons.Fenetre.epaisseurDuFilet
                    )
            }
    }
}

extension StyleTypographique {
    /// Le meme role, dans une autre graisse autorisee par la section 1.5.
    public func enGraisse(_ graisse: Graisse) -> StyleTypographique {
        StyleTypographique(
            taille: taille,
            graisse: graisse,
            interlignage: interlignage,
            interlettrageEnEm: interlettrageEnEm
        )
    }
}
