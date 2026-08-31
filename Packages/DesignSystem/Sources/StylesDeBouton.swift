import SwiftUI

//
// Boutons, section 4.6 de DESIGN-SPEC.md.
//
// Trois variantes sur les quatre du tableau : principal, aplat accent,
// secondaire, fond `surface.menu` avec contour, et destructif, transparent avec
// texte et contour en `danger`. La variante discrete arrive avec l ecran qui en
// a besoin.
//

/// Bouton principal, aplat `accent`, texte blanc en graisse 600.
public struct BoutonPrincipal: ButtonStyle {
    @Environment(\.palette) private var palette

    /// Hauteur du bouton, choisie dans le tableau des contextes de 4.6.
    public let hauteur: Double
    /// Rayon du bouton, choisi dans le meme tableau.
    public let rayon: Double

    public init(hauteur: Double, rayon: Double) {
        self.hauteur = hauteur
        self.rayon = rayon
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .style(Jetons.Typo.body.enGraisse(.semiGrasse))
            .foregroundStyle(palette.textes.onAccent.couleur)
            .padding(.horizontal, Jetons.Bouton.remplissageHorizontal)
            .frame(minHeight: hauteur)
            .background(fond(pressee: configuration.isPressed))
            .contentShape(Rectangle())
    }

    private func fond(pressee: Bool) -> some View {
        let couleur = pressee
            ? palette.semantiques.accentPressed.couleur
            : palette.semantiques.accent.couleur

        return RoundedRectangle(cornerRadius: rayon, style: .continuous).fill(couleur)
    }
}

/// Bouton secondaire, fond `surface.menu`, contour `border`.
public struct BoutonSecondaire: ButtonStyle {
    @Environment(\.palette) private var palette

    /// Hauteur du bouton.
    public let hauteur: Double
    /// Rayon du bouton.
    public let rayon: Double

    public init(hauteur: Double, rayon: Double) {
        self.hauteur = hauteur
        self.rayon = rayon
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .style(Jetons.Typo.body)
            .foregroundStyle(palette.textes.primary.couleur)
            .padding(.horizontal, Jetons.Bouton.remplissageHorizontal)
            .frame(minHeight: hauteur)
            .background(fond(pressee: configuration.isPressed))
            .contentShape(Rectangle())
    }

    private func fond(pressee: Bool) -> some View {
        let couleur = pressee
            ? palette.surfaces.selected.couleur
            : palette.surfaces.menu.couleur

        return RoundedRectangle(cornerRadius: rayon, style: .continuous)
            .fill(couleur)
            .overlay {
                RoundedRectangle(cornerRadius: rayon, style: .continuous)
                    .strokeBorder(
                        palette.semantiques.border.couleur,
                        lineWidth: Jetons.Fenetre.epaisseurDuFilet
                    )
            }
    }
}

/// Bouton discret, fond transparent, texte en `accent.text`.
///
/// La quatrieme variante du tableau 4.6. Elle porte les liens poses dans le
/// contenu, comme `Tout voir` et `Reessayer` des rangees de l ecran Rechercher,
/// ou `Afficher plus` du resume d une fiche.
///
/// Le role de texte est un parametre parce que le tableau 4.6 donne `body` a la
/// variante, la ou la section 5.4 ecrit `callout` pour le lien Tout voir. La
/// regle 0.1 tranche en faveur du chiffre le plus precis, celui de l ecran.
public struct BoutonDiscret: ButtonStyle {
    @Environment(\.palette) private var palette

    /// Role de texte du libelle.
    public let style: StyleTypographique
    /// Hauteur minimale, qui vaut cible de pointage.
    public let hauteur: Double

    public init(
        style: StyleTypographique = Jetons.Typo.body,
        hauteur: Double = Jetons.Cible.auPointeur
    ) {
        self.style = style
        self.hauteur = hauteur
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .style(style)
            .foregroundStyle(couleur(pressee: configuration.isPressed))
            .frame(minHeight: hauteur)
            .contentShape(Rectangle())
    }

    /// `accent.text` et non `accent` : le libelle est sous 18 px, et seule la
    /// derivation tient le seuil de 4.5:1 en apparence claire, section 1.3.
    ///
    /// Le bouton discret n a pas de fond propre. Il se pose sur une carte ou
    /// sur la zone de contenu, et `accent.text` tombe sous le seuil sur la
    /// carte survolee des themes Slate et Paper. La derivation ferme l ecart.
    private func couleur(pressee: Bool) -> Color {
        let jeton = pressee ? palette.semantiques.accentPressed : palette.semantiques.accentText
        return palette.lisible(jeton, sur: fondsPossibles).couleur
    }

    /// Fonds sous lesquels un bouton discret peut se trouver.
    private var fondsPossibles: [CouleurHexadecimale] {
        [palette.surfaces.canvas, palette.surfaces.card, palette.surfaces.cardHover]
    }
}

/// Bouton destructif, fond transparent, texte et contour en `danger`.
///
/// Reserve a ce qui detruit, comme la confirmation d un effacement. Le tableau
/// 4.6 ne lui donne pas d aplat : une action irreversible ne doit pas etre le
/// bouton le plus attirant d une modale.
public struct BoutonDestructif: ButtonStyle {
    @Environment(\.palette) private var palette

    /// Hauteur du bouton.
    public let hauteur: Double
    /// Rayon du bouton.
    public let rayon: Double

    public init(hauteur: Double, rayon: Double) {
        self.hauteur = hauteur
        self.rayon = rayon
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .style(Jetons.Typo.body)
            .foregroundStyle(couleurDuTexte)
            .padding(.horizontal, Jetons.Bouton.remplissageHorizontal)
            .frame(minHeight: hauteur)
            .background(fond(pressee: configuration.isPressed))
            .contentShape(Rectangle())
    }

    /// `danger` mesure 4.4:1 sur `surface.cardHover` en variante sombre, sous
    /// le seuil de la section 7. Le libelle est derive sur les deux fonds que
    /// le bouton peut montrer, voir `Lisibilite`.
    private var couleurDuTexte: Color {
        palette.lisible(
            palette.semantiques.danger,
            sur: [palette.surfaces.card, palette.surfaces.cardHover]
        ).couleur
    }

    /// Le contour est un element graphique, il releve du seuil de 3:1.
    private var couleurDuContour: Color {
        palette.lisible(
            palette.semantiques.danger,
            sur: [palette.surfaces.card, palette.surfaces.cardHover],
            seuil: Jetons.Contraste.grandTexte
        ).couleur
    }

    /// Le tableau 4.6 ne donne aucun fond a cette variante au repos. L etat
    /// presse reprend la regle generale du meme tableau, le fond de survol.
    private func fond(pressee: Bool) -> some View {
        RoundedRectangle(cornerRadius: rayon, style: .continuous)
            .fill(pressee ? palette.surfaces.cardHover.couleur : .clear)
            .overlay {
                RoundedRectangle(cornerRadius: rayon, style: .continuous)
                    .strokeBorder(
                        couleurDuContour,
                        lineWidth: Jetons.Fenetre.epaisseurDuFilet
                    )
            }
    }
}

extension StyleTypographique {
    /// Le meme role, dans une autre graisse autorisee par la section 1.5.
    public func enGraisse(_ graisse: Graisse) -> StyleTypographique {
        StyleTypographique(
            taille: taille,
            graisse: graisse,
            interlignage: interlignage,
            interlettrageEnEm: interlettrageEnEm
        )
    }
}
