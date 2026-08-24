//
// TailleEnPixels
//
// Taille exprimee en pixels reels, jamais en points.
//
// La distinction compte pour la chaine d images : la section 6.1 impose de
// decoder a la taille d affichage, et une zone de 800 points sur un ecran a
// deux fois la densite demande 1600 pixels. Confondre les deux unites divise
// ou multiplie par deux la memoire consommee par chaque page.
//

/// Dimensions en pixels d une image ou d une zone d affichage.
public struct TailleEnPixels: Sendable, Hashable {
    /// Largeur en pixels. Jamais negative.
    public let largeur: Int

    /// Hauteur en pixels. Jamais negative.
    public let hauteur: Int

    /// Construit une taille, en ramenant a zero une dimension negative.
    public init(largeur: Int, hauteur: Int) {
        self.largeur = max(0, largeur)
        self.hauteur = max(0, hauteur)
    }

    /// Taille nulle, celle d une zone d affichage pas encore mesuree.
    public static let nulle = TailleEnPixels(largeur: 0, hauteur: 0)

    /// Vrai quand l une des deux dimensions est nulle.
    public var estVide: Bool {
        largeur == 0 || hauteur == 0
    }

    /// Le plus grand des deux cotes.
    public var plusGrandCote: Int {
        max(largeur, hauteur)
    }

    /// Nombre d octets occupes une fois l image decodee en RGBA.
    ///
    /// Sert a mesurer un budget memoire, pas a dimensionner un tampon.
    public var octetsUneFoisDecodee: Int {
        largeur * hauteur * 4
    }
}
