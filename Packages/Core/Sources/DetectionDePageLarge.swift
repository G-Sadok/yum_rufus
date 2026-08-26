//
// DetectionDePageLarge
//
// Reconnait la page dont le rapport largeur sur hauteur depasse un, section 6.3
// et section 7.1 du cahier de developpement.
//
// La detection porte sur la forme de l image et sur elle seule. Elle ne lit
// aucun nom de fichier et n interroge aucune metadonnee : une page nommee
// spread.jpg peut etre une page ordinaire, et une double page peut porter un
// nom parfaitement banal.
//
// La regle vit dans Core parce que deux couches en dependent et doivent
// repondre exactement la meme chose. Le moteur de lecture s en sert pour
// afficher la page seule en mode double page, la chaine d images s en sert pour
// decider de la couper en deux. Deux copies de la meme regle finiraient par
// diverger, et le chapitre afficherait alors une planche a la fois seule et
// coupee.
//

/// Decide si une page est une double page, donc affichee seule ou divisee.
public struct DetectionDePageLarge: Sendable, Hashable {
    /// Rapport largeur sur hauteur a partir duquel une page est declaree large.
    ///
    /// Un rapport de un signifie qu une page plus large que haute est une double
    /// page. C est la forme d une planche imprimee sur deux feuilles, et aucune
    /// page simple de manga n est plus large que haute.
    public static let seuilParDefaut: Double = 1

    /// Rapport retenu, jamais inferieur a un.
    public let seuil: Double

    /// Construit une detection.
    ///
    /// - Parameter seuil: rapport largeur sur hauteur. Un seuil sous un est
    ///   ramene au defaut : il declarerait large une page plus haute que large,
    ///   donc tout le chapitre, et le mode double page n afficherait plus jamais
    ///   deux pages.
    public init(seuil: Double = seuilParDefaut) {
        self.seuil = seuil < Self.seuilParDefaut ? Self.seuilParDefaut : seuil
    }

    /// Vrai quand la page occupe l ecran seule.
    ///
    /// Une taille inconnue repond faux. Le moteur n invente pas une double page
    /// a partir d une dimension qu il n a pas encore mesuree, il apparie la page
    /// normalement et corrige quand la taille arrive.
    public func estLarge(_ taille: TailleEnPixels) -> Bool {
        guard taille.estVide == false else {
            return false
        }

        return Double(taille.largeur) > Double(taille.hauteur) * seuil
    }

    /// Index des pages larges d un chapitre, dans l ordre narratif.
    ///
    /// - Parameter tailles: taille de chaque page, indexee comme le chapitre.
    public func pagesLarges(parmi tailles: [TailleEnPixels]) -> Set<Int> {
        Set(tailles.indices.filter { estLarge(tailles[$0]) })
    }
}
