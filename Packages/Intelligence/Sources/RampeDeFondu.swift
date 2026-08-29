//
// RampeDeFondu
//
// Poids d une tuile le long d un axe, du bord vers le centre.
//
// Le poids vaut un partout sauf sur la largeur du recouvrement, ou il descend
// lineairement jusqu au bord sans jamais l atteindre. La valeur au tout dernier
// pixel vaut un sur la longueur de rampe plus un : elle est faible, ce qui est
// le but, et strictement positive, ce qui garantit qu aucun pixel de la page ne
// se retrouve avec un poids total nul.
//
// Un bord de tuile qui est aussi un bord de page ne recoit pas de rampe. La
// raison est dans TamponDeRecomposition : rien ne vient s y fondre, une rampe y
// delaverait le bord de la planche.
//
// La rampe est calculee dans le repere de la sortie et non de l entree. Le
// modele multiplie les distances par son facteur, un recouvrement de seize
// pixels en entree fait donc trente deux pixels de fondu en sortie sur un
// modele qui double.
//

/// Poids d une tuile le long d un axe, calcules une fois par tuile.
enum RampeDeFondu {
    /// Poids de chaque position, du premier au dernier pixel de la tuile.
    ///
    /// - Parameters:
    ///   - longueur: nombre de pixels de la tuile sur cet axe, en sortie.
    ///   - fondu: largeur de la descente, en pixels de sortie.
    ///   - debutLibre: vrai quand le bord de depart est un bord de page.
    ///   - finLibre: vrai quand le bord d arrivee est un bord de page.
    static func poids(
        longueur: Int,
        fondu: Int,
        debutLibre: Bool,
        finLibre: Bool
    ) -> [Float] {
        guard longueur > 0 else { return [] }

        let descente = Float(max(0, fondu) + 1)

        return (0..<longueur).map { position in
            let versLeDebut = debutLibre ? 1 : min(1, Float(position + 1) / descente)
            let versLaFin = finLibre ? 1 : min(1, Float(longueur - position) / descente)

            return min(versLeDebut, versLaFin)
        }
    }
}
