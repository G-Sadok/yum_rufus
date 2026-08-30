//
// ReglagesDeColorisation
//
// Parametres de la colorisation par IA, cinquieme etape de la chaine de
// traitement de la section 6.3.
//
// Un seul reglage, parce que la section 9 n en expose qu un : Colorisation par
// IA, interrupteur, livre inactif, reserve a l abonnement. Ni la palette, ni
// l intensite, ni le cote de tuile ne se reglent : ce sont des proprietes du
// modele installe.
//
// L empreinte existe pour la meme raison que celle de l amelioration : la
// section 6.3 range cette etape parmi les couteuses, dont le resultat se met en
// cache sous une cle qui integre le hachage des parametres. Elle ne suffit
// pourtant pas a elle seule, le resultat depend aussi du modele installe, et
// c est l acteur qui compose les deux, voir ColoriseurIA.cle.
//
// L empreinte ne reprend pas le prefixe de celle de l amelioration. Les deux
// etapes se suivent dans la chaine, leurs deux empreintes se retrouvent donc
// dans la meme cle quand les deux interrupteurs sont armes, et deux prefixes
// identiques rendraient la cle ambigue.
//

/// Parametres de la colorisation par IA d une page.
public struct ReglagesDeColorisation: Sendable, Hashable {
    /// Vrai quand la colorisation doit etre appliquee.
    ///
    /// Le tableau des reglages de la section 9 livre cet interrupteur inactif.
    /// Une page n est donc jamais colorisee sans que l utilisateur l ait
    /// demande, ce qui compte double ici : le traitement se paie en secondes et
    /// en memoire, et il change la planche que l auteur a dessinee.
    public let actif: Bool

    public init(actif: Bool) {
        self.actif = actif
    }

    /// Reglages livres par defaut : interrupteur inactif.
    public static let parDefaut = ReglagesDeColorisation(actif: false)

    /// Reglages une fois l interrupteur arme.
    public static let arme = ReglagesDeColorisation(actif: true)

    /// Empreinte des parametres, destinee aux cles de cache.
    public var empreinte: String {
        actif ? "col=1" : "col=0"
    }
}
