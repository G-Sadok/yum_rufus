import SwiftUI

//
// Application d un role de l echelle typographique a une vue.
//
// Une vue ecrit `.style(Jetons.Typo.body)`, jamais une taille ni une graisse.
//

extension View {
    /// Applique un role de l echelle typographique, section 1.5.
    ///
    /// - Parameter chiffresTabulaires: obligatoire partout ou un nombre change
    ///   en place.
    public func style(
        _ style: StyleTypographique,
        chiffresTabulaires: Bool = false
    ) -> some View {
        font(style.police(chiffresTabulaires: chiffresTabulaires))
            .tracking(style.interlettrage)
    }
}
