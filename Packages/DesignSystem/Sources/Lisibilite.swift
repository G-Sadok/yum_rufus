//
// Lisibilite d une couleur sur une surface, sections 1.3 et 7 de
// DESIGN-SPEC.md.
//
// La section 1.3 pose le principe : `accent.text` existe parce que `#0A84FF`
// sur fond blanc plafonne a 3.3:1 et ne peut pas porter du texte sous 18 px.
// C est une derivation obligatoire, decidee par la mesure, pas par le gout.
//
// La section 7 mesure les ratios sur `surface.card` uniquement. Le produit pose
// pourtant du texte sur d autres surfaces, et trois d entre elles sont plus
// claires que `card` en variante sombre : `menu`, `selected` et `premium`. Sur
// elles, les memes jetons tombent sous le seuil de 4.5:1. Mesures en Midnight
// sombre, avant correction :
//
//   `accent.text` sur `surface.menu`      3.8:1
//   `accent.text` sur `surface.premium`   4.1:1
//   `text.tertiary` sur `surface.menu`    4.3:1
//   `text.tertiary` sur `surface.selected` 3.5:1
//
// Le document ne donne pas de jeton de remplacement pour ces cas. Plutot que
// d en inventer un par surface, on applique la regle que la section 1.3 a deja
// posee pour `accent.text` : quand la mesure ne passe pas, la couleur est
// derivee, du minimum necessaire, dans la direction qui l ecarte de la surface.
// Une couleur qui tient deja le seuil sort inchangee, ce qui laisse la quasi
// totalite du produit sur ses jetons d origine.
//
// La derivation prend la liste des surfaces qu un composant peut montrer, repos
// et survol compris, et tient le seuil sur la pire. Sans cela la couleur
// changerait au passage de la souris, ce qui ferait clignoter le libelle.
//

extension Palette {
    /// Variante de la couleur qui tient le seuil sur toutes les surfaces citees.
    ///
    /// - Parameters:
    ///   - couleur: jeton d origine, celui que le document nomme.
    ///   - surfaces: surfaces que le composant peut montrer sous ce texte.
    ///   - seuil: seuil de contraste vise, section 7.
    /// - Returns: le jeton d origine s il tient deja le seuil, sinon la
    ///   premiere derivation qui le tient.
    public func lisible(
        _ couleur: CouleurHexadecimale,
        sur surfaces: [CouleurHexadecimale],
        seuil: Double = Jetons.Contraste.texteCourant
    ) -> CouleurHexadecimale {
        Lisibilite.derivee(couleur, sur: surfaces, seuil: seuil)
    }
}

/// Derivation d une couleur jusqu au seuil de contraste demande.
public enum Lisibilite {
    /// Couleur derivee du minimum necessaire pour tenir le seuil.
    ///
    /// La derivation melange la couleur avec du blanc ou avec du noir, un
    /// deux cent cinquante cinquieme a la fois, et rend le premier melange qui
    /// tient le seuil sur toutes les surfaces. La direction est celle qui
    /// eloigne la couleur de la surface la plus genante.
    ///
    /// Une liste de surfaces vide rend la couleur telle quelle.
    public static func derivee(
        _ couleur: CouleurHexadecimale,
        sur surfaces: [CouleurHexadecimale],
        seuil: Double = Jetons.Contraste.texteCourant
    ) -> CouleurHexadecimale {
        guard surfaces.isEmpty == false else { return couleur }
        guard tient(couleur, sur: surfaces, seuil: seuil) == false else { return couleur }

        let cible = extremiteLaPlusEloignee(de: couleur, sur: surfaces)

        for pas in 1...255 {
            let part = Double(pas) / 255
            let candidate = melange(couleur, vers: cible, part: part)

            if tient(candidate, sur: surfaces, seuil: seuil) {
                return candidate
            }
        }

        return cible
    }

    /// Vrai quand la couleur tient le seuil sur chacune des surfaces.
    public static func tient(
        _ couleur: CouleurHexadecimale,
        sur surfaces: [CouleurHexadecimale],
        seuil: Double = Jetons.Contraste.texteCourant
    ) -> Bool {
        surfaces.allSatisfy { couleur.contraste(avec: $0) >= seuil }
    }

    /// Blanc ou noir, selon celle des deux extremites qui s eloigne le plus de
    /// la surface la plus genante.
    private static func extremiteLaPlusEloignee(
        de couleur: CouleurHexadecimale,
        sur surfaces: [CouleurHexadecimale]
    ) -> CouleurHexadecimale {
        let blanc = CouleurHexadecimale(0xFFFFFF)
        let noir = CouleurHexadecimale(0x000000)

        let pireEnBlanc = surfaces.map { blanc.contraste(avec: $0) }.min() ?? 1
        let pireEnNoir = surfaces.map { noir.contraste(avec: $0) }.min() ?? 1

        return pireEnBlanc >= pireEnNoir ? blanc : noir
    }

    private static func melange(
        _ couleur: CouleurHexadecimale,
        vers cible: CouleurHexadecimale,
        part: Double
    ) -> CouleurHexadecimale {
        let composante = { (depart: Int, arrivee: Int) -> Int in
            Int((Double(depart) + (Double(arrivee) - Double(depart)) * part).rounded())
        }

        return CouleurHexadecimale(
            rouge: composante(couleur.rouge, cible.rouge),
            vert: composante(couleur.vert, cible.vert),
            bleu: composante(couleur.bleu, cible.bleu),
            opacite: couleur.opacite
        )
    }
}
