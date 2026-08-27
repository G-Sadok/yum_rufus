import Core

//
// Textes du tutoriel des zones de toucher, section 5.7 de DESIGN-SPEC.md.
//
// La section 6 ne donne pas ces libelles, la surimpression n etant dessinee ni
// par le texte ni par les wireframes. Ils suivent donc ses regles d ecriture :
// voix active, le libelle dit ce qui se passe, aucun point d exclamation.
//
// Les trois libelles nomment une action de lecture et jamais un bord d ecran.
// Un texte qui dirait la gauche ou la droite deviendrait faux des que le sens
// de lecture change ou que l option Inverser les zones est active, alors que
// l action, elle, ne bouge pas.
//

/// Textes du tutoriel des zones de toucher, pris dans le catalogue de chaines.
public struct LibellesDeZonesDeToucher: Sendable, Equatable {
    /// Etiquette de la zone qui avance d une page.
    public let pageSuivante: String

    /// Etiquette de la zone qui recule d une page.
    public let pagePrecedente: String

    /// Etiquette de la zone qui affiche ou masque les barres.
    public let afficherLesBarres: String

    public init(
        pageSuivante: String,
        pagePrecedente: String,
        afficherLesBarres: String
    ) {
        self.pageSuivante = pageSuivante
        self.pagePrecedente = pagePrecedente
        self.afficherLesBarres = afficherLesBarres
    }

    /// Etiquette d accessibilite d une zone.
    ///
    /// Chaque zone en porte une : la section 7 interdit qu une information
    /// passe par la seule couleur, et le decoupage des zones ne se lit
    /// autrement que par l aplat qui les distingue.
    public func etiquette(de role: RoleDeZone) -> String {
        switch role {
        case .avance: pageSuivante
        case .recule: pagePrecedente
        case .menu: afficherLesBarres
        }
    }
}
