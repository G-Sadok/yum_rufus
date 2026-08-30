//
// DisponibiliteDuReseau
//
// La seule question que la traduction pose au reseau : repond il.
//
// Le paquet Intelligence ne depend pas de Sources, ou vit la couture reseau du
// projet, et il n a aucune raison d en dependre : il ne fait aucune requete lui
// meme, il decide seulement s il a le droit d appeler un moteur qui en fera
// une. Un protocole d une seule propriete suffit a poser cette decision, et il
// evite d ouvrir une dependance entiere pour un booleen.
//
// La reponse est lue au moment ou la traduction demarre, jamais gardee. Une
// connexion perdue entre deux pages doit se voir a la page suivante, et un etat
// memorise ferait exactement l inverse.
//

/// Ce qui sait dire si le reseau repond a cet instant.
public protocol DisponibiliteDuReseau: Sendable {
    /// Vrai quand une requete a une chance d aboutir.
    var estAccessible: Bool { get }
}

/// Reponse fixe, pour un appareil dont l etat reseau est connu d avance.
///
/// Sert aux appelants qui n ont pas de surveillance a brancher, et a la suite
/// de tests, qui doit pouvoir couper le reseau sans en avoir un.
public struct ReseauSuppose: DisponibiliteDuReseau {
    public let estAccessible: Bool

    public init(estAccessible: Bool) {
        self.estAccessible = estAccessible
    }

    /// Reseau declare joignable.
    public static let joignable = ReseauSuppose(estAccessible: true)

    /// Reseau declare injoignable, cas du mode avion et de la lecture hors
    /// ligne.
    public static let coupe = ReseauSuppose(estAccessible: false)
}
