import Core

//
// OrdreDesPages
//
// Passage de l ordre narratif d un chapitre a l ordre ou les pages occupent
// reellement l ecran, et ordre des moities apres division d une image large.
//

/// Ordre des pages, a l ecran et apres division.
public enum OrdreDesPages {
    /// Ordre narratif d un chapitre, indexe a partir de zero.
    ///
    /// Il ne depend pas du sens de lecture : la premiere page reste la
    /// premiere. C est la disposition a l ecran qui change, pas la sequence.
    public static func ordreNarratif(nombreDePages: Int) -> [Int] {
        guard nombreDePages > 0 else {
            return []
        }

        return Array(0..<nombreDePages)
    }

    /// Range des pages affichees ensemble dans l ordre ou elles occupent
    /// l ecran, du bord gauche vers le bord droit.
    ///
    /// En droite a gauche, la premiere page de la sequence se place a droite,
    /// donc la liste est renversee. En vertical, les pages s empilent du haut
    /// vers le bas et la sequence est conservee telle quelle.
    ///
    /// - Parameters:
    ///   - pages: pages dans leur ordre narratif.
    ///   - sens: sens de lecture resolu pour la serie.
    public static func aLEcran(_ pages: [Int], sens: SensDeLecture) -> [Int] {
        sens.commenceParLaDroite ? Array(pages.reversed()) : pages
    }

    /// Ordre de lecture des deux moities d une image large.
    ///
    /// En droite a gauche la moitie droite vient en premier. La regle elle meme
    /// vit dans Core, aupres du sens de lecture, parce que la chaine d images en
    /// depend autant que le moteur : c est elle qui rend les deux moities deja
    /// rangees. Ce point d entree reste ici pour que le moteur nomme l ordre des
    /// moities au meme endroit que l ordre des pages a l ecran.
    public static func ordreDesMoities(sens: SensDeLecture) -> [MoitieDImageLarge] {
        sens.ordreDesMoities
    }
}
