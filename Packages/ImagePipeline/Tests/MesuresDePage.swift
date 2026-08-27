import Core
@testable import ImagePipeline

//
// MesuresDePage
//
// Les trois mesures sur lesquelles les tests de filtres se prononcent.
//
// Toutes portent sur une colonne, jamais sur une ligne. La page de test est
// faite de bandes horizontales : une ligne y est uniforme et sa variance vaut
// zero quels que soient les filtres appliques. Un test qui mesurerait une ligne
// passerait au vert sans rien prouver, et c est exactement ce qui est arrive
// avant que la mesure ne soit corrigee. Une colonne, elle, traverse les trente
// deux bandes et voit chaque transition.
//
// Chaque mesure rend nil quand le systeme refuse la matrice de gris. L appelant
// en fait alors echouer son test, plutot que de conclure sur une valeur
// inventee.
//

enum MesuresDePage {
    /// Ecart type des niveaux de gris de la colonne du milieu.
    ///
    /// Mesure le contraste reel de la page : etaler le contraste ecarte les
    /// valeurs de part et d autre du gris moyen, l aplatir les rassemble.
    static func ecartTypeDUneColonne(de page: ImageDePage) -> Double? {
        guard let matrice = MatriceDeGris(page.image) else {
            return nil
        }

        let statistiques = matrice.statistiques(
            colonne: matrice.largeur / 2,
            lignes: 0..<matrice.hauteur
        )

        return statistiques.variance.squareRoot()
    }

    /// Ecart entre le niveau le plus clair et le plus sombre de cette colonne.
    ///
    /// Mesure l accentuation : une passe de nettete depasse de part et d autre
    /// de chaque transition, ce qui ouvre l amplitude sans toucher aux aplats.
    static func amplitudeDUneColonne(de page: ImageDePage) -> Int? {
        guard let matrice = MatriceDeGris(page.image) else {
            return nil
        }

        let colonne = matrice.largeur / 2
        var minimum = UInt8.max
        var maximum = UInt8.min

        for ligne in 0..<matrice.hauteur {
            let valeur = matrice.valeur(colonne: colonne, ligne: ligne)
            minimum = min(minimum, valeur)
            maximum = max(maximum, valeur)
        }

        return Int(maximum) - Int(minimum)
    }

    /// Nombre de pixels dont le niveau de gris differe entre deux pages.
    ///
    /// Rend nil quand les deux pages n ont pas les memes dimensions : comparer
    /// pixel a pixel deux formats differents ne veut rien dire.
    static func pixelsModifies(entre avant: ImageDePage, et apres: ImageDePage) -> Int? {
        guard let source = MatriceDeGris(avant.image),
              let cible = MatriceDeGris(apres.image),
              source.largeur == cible.largeur,
              source.hauteur == cible.hauteur
        else {
            return nil
        }

        var compte = 0

        for ligne in 0..<source.hauteur {
            for colonne in 0..<source.largeur {
                let ecart = source.valeur(colonne: colonne, ligne: ligne)
                    != cible.valeur(colonne: colonne, ligne: ligne)

                if ecart {
                    compte += 1
                }
            }
        }

        return compte
    }
}
