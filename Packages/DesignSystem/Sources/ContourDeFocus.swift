import SwiftUI

//
// Contour de focus clavier, section 7 de DESIGN-SPEC.md.
//
// Le document ecrit une seule ligne : contour de 2 en `accent`, decalage de 2,
// jamais supprime. Elle etait jusqu ici recopiee dans quatorze vues, chacune
// avec son rayon et son propre calcul de decalage. Une recopie de plus qui
// oubliait le decalage passait inapercue, et un composant qui coupait l effet
// de focus du systeme sans reposer le contour laissait un element atteignable
// au clavier sans aucun signe visible.
//
// Le contour vit donc ici, en un seul exemplaire. Une vue qui appelle
// `focusEffectDisabled` doit reposer celui ci, et un test de source le verifie.
//

/// Anneau pose autour d un element qui porte le focus clavier.
///
/// Le rayon demande est celui de l element. L anneau ajoute le decalage du
/// document par dessus, de sorte que sa courbe reste concentrique a la sienne.
public struct ContourDeFocus: View {
    @Environment(\.palette) private var palette

    private let visible: Bool
    private let rayonDeLElement: Double

    /// Construit le contour.
    ///
    /// - Parameters:
    ///   - visible: vrai quand l element porte le focus clavier.
    ///   - rayonDeLElement: rayon de coin de l element entoure, section 1.6.
    public init(visible: Bool, rayonDeLElement: Double) {
        self.visible = visible
        self.rayonDeLElement = rayonDeLElement
    }

    public var body: some View {
        if visible {
            RoundedRectangle(
                cornerRadius: rayonDeLElement + Jetons.Focus.decalage,
                style: .continuous
            )
            .strokeBorder(
                palette.semantiques.focusRing.couleur,
                lineWidth: Jetons.Focus.epaisseur
            )
            .padding(-Jetons.Focus.decalage)
        }
    }
}

extension View {
    /// Pose le contour de focus de la section 7 autour de la vue.
    ///
    /// - Parameters:
    ///   - visible: vrai quand l element porte le focus clavier.
    ///   - rayonDeLElement: rayon de coin de l element entoure, section 1.6.
    public func contourDeFocus(_ visible: Bool, rayonDeLElement: Double) -> some View {
        overlay(ContourDeFocus(visible: visible, rayonDeLElement: rayonDeLElement))
    }
}
