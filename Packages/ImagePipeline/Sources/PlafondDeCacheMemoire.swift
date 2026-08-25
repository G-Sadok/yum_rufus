//
// PlafondDeCacheMemoire
//
// Les deux bornes du cache memoire de la section 6.1 : six pages ou 220 Mo,
// selon la premiere limite atteinte.
//
// Les deux comptent, et aucune ne suffit seule. Sur une petite zone
// d affichage, six pages tiennent largement sous 220 Mo et c est le compte de
// pages qui borne. Sur un ecran dense avec une page tres haute, deux pages
// peuvent deja peser plus que le plafond d octets, et c est lui qui borne.
//
// Comme pour BudgetDeDecodage, 220 Mo se lit ici 220 millions d octets et non
// 220 mebioctets. Le cahier ne tranche pas entre les deux conventions, cette
// valeur passe sous la plus stricte des deux.
//

/// Bornes du cache memoire de pages.
public struct PlafondDeCacheMemoire: Sendable, Hashable {
    /// Nombre maximal de pages retenues en meme temps.
    public let pages: Int

    /// Nombre maximal d octets retenus en meme temps.
    public let octets: Int

    /// Construit un plafond, en refusant des bornes plus petites qu une page.
    public init(pages: Int, octets: Int) {
        self.pages = max(1, pages)
        self.octets = max(Self.plancherDOctets, octets)
    }

    /// Plafond de la section 6.1, applique quand l appelant n en impose pas.
    public static let parDefaut = PlafondDeCacheMemoire(pages: 6, octets: 220_000_000)

    /// Plus petit plafond d octets accepte, celui d une vignette de 64 par 64.
    private static let plancherDOctets = 64 * 64 * 4
}
