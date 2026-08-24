import Core

//
// AjustementDePage
//
// Calcul de la taille qu occupe une page ajustee a la zone d affichage, et du
// cote a demander au decodeur.
//
// C est le calcul qui empeche l erreur numero trois du cahier de developpement,
// celle qui a coule le plus de lecteurs de manga : decoder une page de 3000 par
// 4500 en pleine resolution pour l afficher sur 900 pixels de haut coute 54 Mo
// au lieu de 2,2 Mo.
//

/// Ajustement d une page a la zone qui l affiche.
public enum AjustementDePage {
    /// Taille occupee par une page ajustee a la zone, ratio conserve.
    ///
    /// La page est agrandie quand la zone est plus grande qu elle, parce que le
    /// mode page simple demande une page ajustee a l ecran et non une page
    /// posee a sa taille d origine au milieu du noir.
    ///
    /// - Parameters:
    ///   - page: dimensions de la page telles que le fichier les annonce.
    ///   - zone: dimensions de la zone d affichage, en pixels reels.
    public static func tailleAjustee(page: TailleEnPixels, dans zone: TailleEnPixels) -> TailleEnPixels {
        guard page.estVide == false, zone.estVide == false else {
            return .nulle
        }

        let facteur = facteurDAjustement(page: page, dans: zone)

        return TailleEnPixels(
            largeur: max(1, Int((Double(page.largeur) * facteur).rounded())),
            hauteur: max(1, Int((Double(page.hauteur) * facteur).rounded()))
        )
    }

    /// Plus grand cote a demander au decodeur pour cette page dans cette zone.
    ///
    /// C est la valeur passee a `kCGImageSourceThumbnailMaxPixelSize`, qui
    /// borne le plus grand cote de l image produite et conserve le ratio.
    ///
    /// Le cote est celui de la page **ajustee**, pas celui de la zone. Une page
    /// haute affichee dans une fenetre large est bornee par la hauteur, et
    /// demander le cote de la zone ferait decoder une image plus large que
    /// necessaire.
    public static func coteMaximalADecoder(page: TailleEnPixels, dans zone: TailleEnPixels) -> Int {
        let ajustee = tailleAjustee(page: page, dans: zone)

        guard ajustee.estVide == false else {
            return max(1, zone.plusGrandCote)
        }

        return ajustee.plusGrandCote
    }

    /// Facteur applique a la page pour qu elle tienne entierement dans la zone.
    private static func facteurDAjustement(page: TailleEnPixels, dans zone: TailleEnPixels) -> Double {
        min(
            Double(zone.largeur) / Double(page.largeur),
            Double(zone.hauteur) / Double(page.hauteur)
        )
    }
}
