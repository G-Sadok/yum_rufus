import Core

//
// ReglagesDeDivision
//
// Parametres de la division des images larges, deuxieme etape de la chaine de
// traitement de la section 6.3.
//
// Un interrupteur et un seuil, rien de plus. Il n y a pas de reglage de
// position de coupe : le cahier impose de couper au milieu, et laisser regler
// ce point ouvrirait la porte a des demi planches decalees dont personne ne
// saurait dire si elles sont justes.
//
// Le seuil est celui de `DetectionDePageLarge`, et il est ramene dans son
// domaine par elle. Deux bornages separes finiraient par diverger, et une page
// serait alors affichee seule en mode double page sans etre coupee, ou coupee
// sans etre affichee seule.
//
// L interrupteur est livre inactif, comme le tableau de la section 10 l ecrit.
// Une planche double coupee sans que l utilisateur l ait demande passe pour un
// defaut du fichier.
//

/// Parametres de la division d une image large en deux moities.
public struct ReglagesDeDivision: Sendable, Hashable {
    /// Vrai quand les images larges doivent etre coupees en deux.
    public let actif: Bool

    /// Rapport largeur sur hauteur au dela duquel une image est coupee.
    public let seuil: Double

    /// Construit des reglages, le seuil ramene dans son domaine.
    public init(actif: Bool, seuil: Double = DetectionDePageLarge.seuilParDefaut) {
        self.actif = actif
        self.seuil = DetectionDePageLarge(seuil: seuil).seuil
    }

    /// Reglages livres par defaut : interrupteur inactif.
    public static let parDefaut = ReglagesDeDivision(actif: false)

    /// Reglages conseilles une fois l interrupteur arme, seuil standard.
    public static let recommande = ReglagesDeDivision(actif: true)

    /// Detection qui applique ce seuil.
    public var detection: DetectionDePageLarge {
        DetectionDePageLarge(seuil: seuil)
    }

    /// Empreinte des parametres, destinee aux cles de cache.
    ///
    /// Deux reglages qui produisent le meme resultat portent la meme empreinte,
    /// et deux reglages qui produisent des resultats differents en portent deux.
    /// La division inactive ecrase le seuil, qui ne change alors plus rien au
    /// resultat : le faire entrer dans l empreinte multiplierait les entrees de
    /// cache pour des pages identiques.
    public var empreinte: String {
        guard actif else { return "division=0" }

        return "division=1;s=\(seuil)"
    }
}
