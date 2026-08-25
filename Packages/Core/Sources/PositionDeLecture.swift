import Foundation

//
// PositionDeLecture
//
// Position exacte de la lecture et regle de marquage automatique, section 7.5
// du cahier de developpement.
//
// La position est un couple chapitre et index de page, plus un decalage de
// defilement pour les modes verticaux. Le decalage est une fraction de la
// hauteur de la page courante, jamais un nombre de points : un nombre de points
// depend de la taille de la fenetre et du zoom, et la meme position reprise sur
// un telephone apres une tablette tomberait ailleurs dans la page.
//

/// Endroit precis ou la lecture s est arretee.
public struct PositionDeLecture: Sendable, Codable, Hashable {
    /// Chapitre ouvert.
    public var chapitreId: UUID

    /// Page atteinte, indexee a partir de zero.
    public var pageIndex: Int

    /// Part de la page courante deja depassee par le defilement, entre zero et
    /// un.
    ///
    /// Vaut zero dans les modes pagines, ou une page affichee n a pas de
    /// decalage interne. En defilement continu et en webtoon, c est ce qui
    /// distingue le haut d une page de vingt mille pixels de son bas.
    public var decalageDeDefilement: Double

    public init(chapitreId: UUID, pageIndex: Int, decalageDeDefilement: Double = 0) {
        self.chapitreId = chapitreId
        self.pageIndex = pageIndex
        self.decalageDeDefilement = decalageDeDefilement
    }

    /// Position ramenee dans les bornes du chapitre.
    ///
    /// Un chapitre dont la source n annonce pas encore le nombre de pages garde
    /// son index tel quel, ramene a zero s il etait negatif. Le nombre de pages
    /// arrive parfois apres l ouverture, et ecraser l index a ce moment la
    /// renverrait le lecteur en debut de chapitre.
    public func normalisee(nombreDePages: Int) -> PositionDeLecture {
        var normalisee = self

        normalisee.pageIndex = max(pageIndex, 0)

        if nombreDePages > 0 {
            normalisee.pageIndex = min(normalisee.pageIndex, nombreDePages - 1)
        }

        normalisee.decalageDeDefilement = min(max(decalageDeDefilement, 0), 1)

        return normalisee
    }
}

/// Avancement d un chapitre et seuil de marquage automatique.
///
/// La part se compte en pages atteintes et ignore volontairement le decalage de
/// defilement. Le decalage sert a restituer une position, pas a la mesurer :
/// le faire entrer dans le calcul donnerait deux regles de marquage, une pour
/// les modes pagines et une pour les modes verticaux, pour un ecart au plus
/// egal a une page.
public enum ProgressionDeChapitre {
    /// Part au dela de laquelle un chapitre est marque lu sans intervention de
    /// l utilisateur.
    ///
    /// Le seuil est strict : un chapitre pile a la valeur du seuil n est pas
    /// marque. Une serie de vingt pages arretee a la dix neuvieme reste donc en
    /// cours, ce qui est bien ce que l utilisateur voit a l ecran.
    public static let seuilDeMarquageAutomatique = 0.95

    /// Part du chapitre deja lue, entre zero et un.
    ///
    /// Une page atteinte compte pour lue, d ou le plus un : arriver sur la
    /// derniere page d un chapitre de vingt pages donne un, pas zero virgule
    /// quatre vingt quinze.
    ///
    /// Un chapitre dont le nombre de pages est encore inconnu rend zero. Sans
    /// cette garde, une division par zero marquerait lu tout ce qui s ouvre
    /// avant que la source ait repondu.
    public static func part(pageAtteinte: Int, nombreDePages: Int) -> Double {
        guard nombreDePages > 0, pageAtteinte >= 0 else {
            return 0
        }

        return min(Double(pageAtteinte + 1) / Double(nombreDePages), 1)
    }

    /// Vrai quand la page atteinte depasse le seuil de marquage automatique.
    public static func depasseLeSeuil(pageAtteinte: Int, nombreDePages: Int) -> Bool {
        part(pageAtteinte: pageAtteinte, nombreDePages: nombreDePages) > seuilDeMarquageAutomatique
    }
}

/// Depose une position de lecture la ou elle survivra a la fermeture de
/// l application.
///
/// Le moteur de lecture pilote la cadence de sauvegarde sans rien savoir de la
/// base de donnees. C est ce protocole qui les separe : `ReaderEngine` ne
/// depend pas de `Storage`, et un test remplace la base par un espion.
public protocol EnregistreurDePosition: Sendable {
    /// Enregistre la position, ou echoue en laissant l ancienne intacte.
    func enregistrer(_ position: PositionDeLecture) async throws
}
