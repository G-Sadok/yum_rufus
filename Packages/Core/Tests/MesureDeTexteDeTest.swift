import Core

//
// Mesure de texte a chasse fixe, pour les tests de mise en page de bulle.
//
// La mise en page reelle mesure avec la police du systeme, dont la largeur d un
// caractere depend du caractere. Une suite de tests qui dependrait de cette
// mesure testerait la police plutot que l algorithme, et changerait de resultat
// a la premiere mise a jour du systeme.
//
// Cette mesure la est exacte et connue : un caractere vaut une demie fois le
// corps en largeur, une ligne vaut une fois et demie le corps en hauteur. Les
// deux rapports sont ceux d une police a chasse fixe courante, assez proches du
// reel pour que les cas limites du test soient les cas limites du produit.
//

/// Mesure a chasse fixe, dont le test connait le resultat au point pres.
struct MesureAChasseFixe: MesureDeTexte {
    /// Largeur d un caractere, en part du corps.
    static let chasse = 0.5

    /// Hauteur d une ligne, en part du corps.
    static let interligne = 1.5

    func largeur(de fragment: String, corps: Double) -> Double {
        Double(fragment.count) * corps * Self.chasse
    }

    func hauteurDeLigne(corps: Double) -> Double {
        corps * Self.interligne
    }
}

/// Gabarit de reference des tests, celui que le systeme de design pose.
///
/// Les valeurs sont celles de l echelle typographique de la section 1.5 de
/// DESIGN-SPEC.md, `body` en haut et `caption` en bas.
extension GabaritDeBulle {
    static let deTest = GabaritDeBulle(
        corpsMaximal: 15,
        corpsMinimal: 11,
        pas: 1,
        margeInterne: 4,
        marqueDeTroncature: "..."
    )
}
