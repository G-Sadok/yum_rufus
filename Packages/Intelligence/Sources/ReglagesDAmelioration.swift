//
// ReglagesDAmelioration
//
// Parametres de l amelioration IA en deux fois, quatrieme etape de la chaine de
// traitement de la section 6.3.
//
// Un seul reglage, parce que la section 9 n en expose qu un : Amelioration IA en
// deux fois, interrupteur, livre inactif, reserve a l abonnement. Le facteur ne
// se regle pas, il est celui du modele installe, et le cote de tuile ne se regle
// pas davantage, il est celui que la section 8 impose.
//
// L empreinte existe pour la meme raison que celle du rognage : la section 6.3
// range cette etape parmi les couteuses, dont le resultat se met en cache sous
// une cle qui integre le hachage des parametres. Elle ne suffit pourtant pas a
// elle seule. Le resultat depend aussi du modele installe et de son facteur, que
// l utilisateur ne regle pas mais qu une mise a jour peut changer. C est
// l acteur qui compose les deux, voir AmeliorateurIA.cle.
//

/// Parametres de l amelioration IA d une page.
public struct ReglagesDAmelioration: Sendable, Hashable {
    /// Vrai quand l amelioration doit etre appliquee.
    ///
    /// Le tableau des reglages de la section 9 livre cet interrupteur inactif.
    /// Une page n est donc jamais amelioree sans que l utilisateur l ait
    /// demande, ce qui compte double ici : le traitement se paie en secondes et
    /// en memoire.
    public let actif: Bool

    public init(actif: Bool) {
        self.actif = actif
    }

    /// Reglages livres par defaut : interrupteur inactif.
    public static let parDefaut = ReglagesDAmelioration(actif: false)

    /// Reglages une fois l interrupteur arme.
    public static let arme = ReglagesDAmelioration(actif: true)

    /// Empreinte des parametres, destinee aux cles de cache.
    public var empreinte: String {
        actif ? "ia=1" : "ia=0"
    }
}
