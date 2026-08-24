import SwiftUI

//
// Transport de la palette jusqu aux vues.
//
// Une vue ne choisit ni theme ni apparence. Elle lit la palette que la coquille
// a resolue et posee dans l environnement.
//

extension EnvironmentValues {
    /// Palette resolue pour le theme et l apparence courants.
    @Entry public var palette: Palette = .defaut
}

extension View {
    /// Pose la palette du theme et de l apparence demandes.
    public func palette(theme: ThemeDeSurface, apparence: Apparence) -> some View {
        environment(\.palette, Palette.pour(theme: theme, apparence: apparence))
    }
}
