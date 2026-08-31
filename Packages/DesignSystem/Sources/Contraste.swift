import Foundation

//
// Contraste, section 7 de DESIGN-SPEC.md.
//
// Le document donne deux seuils, 4.5:1 sous 18 px et 3:1 au dela, puis une
// table de ratios mesures sur `surface.card`. Ces ratios etaient jusqu ici des
// nombres ecrits dans un tableau, que rien ne recalculait. Un jeton retouche
// les rendait faux en silence.
//
// La formule est celle de WCAG 2.1 : luminance relative de chaque couleur, puis
// rapport des deux luminances augmentees de 0.05. Elle vit ici, dans le seul
// paquet qui connait les couleurs, et la suite de tests s en sert pour comparer
// chaque paire de jetons au seuil du document.
//

extension CouleurHexadecimale {
    /// Luminance relative de la couleur, definition WCAG 2.1.
    ///
    /// L opacite n entre pas dans le calcul. Une couleur translucide se compose
    /// d abord sur son fond avec `composee(sur:)`, ce qui donne la couleur
    /// reellement vue, dont on prend ensuite la luminance.
    public var luminanceRelative: Double {
        let composantes = [rouge, vert, bleu].map(Self.canalLineaire)
        return 0.2126 * composantes[0] + 0.7152 * composantes[1] + 0.0722 * composantes[2]
    }

    /// Rapport de contraste entre cette couleur et une autre.
    ///
    /// Le rapport est symetrique et vaut au minimum 1, au maximum 21.
    public func contraste(avec autre: CouleurHexadecimale) -> Double {
        let claire = max(luminanceRelative, autre.luminanceRelative)
        let sombre = min(luminanceRelative, autre.luminanceRelative)
        return (claire + 0.05) / (sombre + 0.05)
    }

    /// Couleur reellement vue lorsque celle ci est posee sur un fond opaque.
    ///
    /// Une couleur deja opaque se rend elle meme.
    public func composee(sur fond: CouleurHexadecimale) -> CouleurHexadecimale {
        guard opacite < 1 else { return self }

        let melange = { (dessus: Int, dessous: Int) -> Int in
            let valeur = Double(dessus) * opacite + Double(dessous) * (1 - opacite)
            return Int(valeur.rounded())
        }

        let valeur = UInt32(melange(rouge, fond.rouge)) << 16
            | UInt32(melange(vert, fond.vert)) << 8
            | UInt32(melange(bleu, fond.bleu))

        return CouleurHexadecimale(valeur)
    }

    /// Rapport de contraste arrondi au dixieme, comme le document l ecrit.
    public func contrasteArrondi(avec autre: CouleurHexadecimale) -> Double {
        (contraste(avec: autre) * 10).rounded() / 10
    }

    private static func canalLineaire(_ composante: Int) -> Double {
        let valeur = Double(composante) / 255
        return valeur <= 0.03928 ? valeur / 12.92 : pow((valeur + 0.055) / 1.055, 2.4)
    }
}

extension Jetons {
    /// Seuils de contraste, section 7.
    public enum Contraste {
        /// Seuil du texte sous 18 px.
        public static let texteCourant: Double = 4.5

        /// Seuil du texte de 18 px et plus, et des elements graphiques.
        public static let grandTexte: Double = 3

        /// Taille a partir de laquelle un texte passe au seuil reduit.
        public static let tailleDuGrandTexte: Double = 18

        /// Seuil applicable a un texte de la taille donnee.
        public static func seuil(pourTailleDeTexte taille: Double) -> Double {
            taille >= tailleDuGrandTexte ? grandTexte : texteCourant
        }
    }
}
