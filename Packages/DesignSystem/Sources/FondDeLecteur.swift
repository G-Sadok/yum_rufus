//
// Fonds du lecteur, section 1.4 de DESIGN-SPEC.md.
//

/// Les quatre fonds proposes par le reglage Fond du lecteur.
///
/// Ce reglage prime sur `surface.reader` du theme des que l utilisateur y
/// touche. Le libelle visible vient du catalogue de chaines, jamais d ici.
public enum FondDeLecteur: String, CaseIterable, Sendable {
    case noirOled
    case grisSombre
    case blanc
    case sepia

    /// Fond applique tant que l utilisateur n a rien choisi.
    ///
    /// Le lecteur est noir par defaut, conformement a la section 5.7.
    public static let defaut = FondDeLecteur.noirOled

    /// Couleur du fond.
    public var couleur: CouleurHexadecimale {
        switch self {
        case .noirOled: CouleurHexadecimale(0x000000)
        case .grisSombre: CouleurHexadecimale(0x1A1A1C)
        case .blanc: CouleurHexadecimale(0xFFFFFF)
        case .sepia: CouleurHexadecimale(0xEFE3CE)
        }
    }

    /// Valeur telle qu elle est ecrite dans le tableau 1.4.
    ///
    /// Sert a rapprocher le code du document. Ce n est pas un libelle
    /// d interface, le texte affiche passe par le catalogue de chaines.
    public var valeurDuDocument: String {
        switch self {
        case .noirOled: "Noir OLED"
        case .grisSombre: "Gris sombre"
        case .blanc: "Blanc"
        case .sepia: "Sepia"
        }
    }
}
