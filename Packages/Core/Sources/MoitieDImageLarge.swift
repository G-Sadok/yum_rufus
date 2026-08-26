//
// MoitieDImageLarge
//
// Les deux moities d une image large coupee au milieu, et l ordre dans lequel
// elles se lisent, section 6.3 du cahier de developpement.
//
// La regle vit dans Core pour la meme raison que `DetectionDePageLarge` : deux
// couches en dependent. La chaine d images decoupe la matrice et rend les deux
// moities deja rangees, le moteur de lecture les enchaine dans la sequence du
// chapitre. Une seconde copie de la regle divergerait tot ou tard, et l ecart
// ne serait visible qu en droite a gauche, la ou personne ne relit.
//

/// Moitie d une image large coupee en deux.
public enum MoitieDImageLarge: String, Sendable, CaseIterable, Hashable {
    /// Moitie de gauche de l image d origine.
    case gauche

    /// Moitie de droite de l image d origine.
    case droite
}

extension SensDeLecture {
    /// Ordre de lecture des deux moities d une image large.
    ///
    /// En droite a gauche la moitie droite vient en premier. C est le bogue le
    /// plus frequent de ce domaine et le plus invisible en test manuel : une
    /// planche lue a l envers reste une planche, et rien ne signale l erreur a
    /// qui ne lit pas le japonais.
    ///
    /// Le sens vertical range les moities de gauche a droite. Une image large
    /// coupee en mode webtoon empile ses deux moities dans le defilement, et
    /// c est l ordre occidental qui s applique alors, comme pour tout ce qui
    /// n est pas gouverne par le sens horizontal.
    public var ordreDesMoities: [MoitieDImageLarge] {
        commenceParLaDroite ? [.droite, .gauche] : [.gauche, .droite]
    }
}
