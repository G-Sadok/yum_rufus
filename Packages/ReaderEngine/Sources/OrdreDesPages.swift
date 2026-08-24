import Core

//
// OrdreDesPages
//
// Passage de l ordre narratif d un chapitre a l ordre ou les pages occupent
// reellement l ecran, et ordre des moities apres division d une image large.
//

/// Moitie d une image large coupee en deux.
public enum MoitieDImageLarge: String, Sendable, CaseIterable, Hashable {
    case gauche
    case droite
}

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
    /// En droite a gauche la moitie droite vient en premier. C est le bogue le
    /// plus frequent de ce domaine et le plus invisible en test manuel.
    public static func ordreDesMoities(sens: SensDeLecture) -> [MoitieDImageLarge] {
        sens.commenceParLaDroite ? [.droite, .gauche] : [.gauche, .droite]
    }
}
