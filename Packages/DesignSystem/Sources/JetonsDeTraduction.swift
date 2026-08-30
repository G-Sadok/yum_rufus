import Core

//
// Jetons de la traduction des bulles, section 8 du cahier de developpement.
//
// DESIGN-SPEC.md ne dessine pas la surimpression. Il nomme l action de la barre
// du lecteur, `Traduire` au tableau 6.5, et il fixe la seule chose qui compte
// vraiment ici, la these de la section 0 : l interface doit disparaitre devant
// le dessin. Aucune valeur nouvelle n est donc inventee, tout est repris de
// jetons deja poses ailleurs, comme l impose la regle 4 de la section 0,
// composer avant de creer.
//
// Trois emprunts, et chacun a sa raison.
//
// Le gabarit typographique prend le haut et le bas de l echelle de la section
// 1.5, `body` a quinze points et `caption` a onze. Le haut parce qu une bulle
// n est pas un titre et n a aucune raison de crier plus fort que le texte
// courant du produit. Le bas parce que le document ne descend pas plus bas :
// onze points est la taille de la mention legale, et un texte plus petit
// qu elle n est plus lisible, c est une tache posee sur le dessin.
//
// Le flou reprend le principe de la banniere de la section 5.6, image floutee
// puis voile. Son rayon est bien plus petit, et ce n est pas un ajustement
// optique : le flou de la fiche efface une couverture de trois cents points de
// haut, celui ci efface le lettrage d une bulle qui en fait quelques dizaines.
// Un rayon de quarante y deborderait largement du cadre.
//
// Le voile reprend l opacite de celui de la fiche. C est la seule force de
// voile que le document donne, et en donner une seconde reviendrait a decider
// sans le document.
//

extension Jetons {
    /// Surimpression du texte traduit sur une bulle floutee, section 8.
    public enum Traduction {
        /// Rayon de la surimpression, celui d une couverture de carte.
        ///
        /// Une bulle de manga n a pas de forme reguliere. La surimpression
        /// n essaie pas de la suivre : elle pose un rectangle arrondi sur son
        /// cadre, ce qui se lit comme un element d interface assume plutot que
        /// comme un dessin rate.
        public static let rayon = Rayon.bouton

        /// Rayon du flou pose sur la bulle d origine.
        ///
        /// Deux crans de l echelle d espacement, soit a peu pres le corps du
        /// texte pose par dessus. Assez pour effacer le lettrage d origine,
        /// assez peu pour ne pas baver hors du cadre de la bulle.
        public static let rayonDeFlou = Espace.x2

        /// Opacite du voile pose sur la bulle floutee.
        ///
        /// Celle du voile de la banniere de la section 5.6. Le document ne
        /// donne pas d autre force de voile.
        public static let opaciteDuVoile = FicheDeSerie.opaciteDuVoile

        /// Corps le plus grand, celui du texte courant du produit.
        public static let corpsMaximal = Typo.body.taille

        /// Corps le plus petit, celui de la mention legale, plancher de
        /// lisibilite.
        public static let corpsMinimal = Typo.caption.taille

        /// Ecart entre deux corps essayes, en points.
        ///
        /// Un point. L echelle de la section 1.5 ne descend pas par paliers
        /// entre quinze et onze, et sauter directement de l un a l autre ferait
        /// perdre quatre points de lisibilite a une bulle qui n en manquait
        /// qu un.
        public static let pasDeCorps: Double = 1

        /// Marge entre le texte et le bord de la bulle, sur chaque cote.
        public static let margeInterne = Espace.x1

        /// Marque posee a la fin d un texte que la bulle ne peut pas contenir.
        ///
        /// Les trois points de suspension du produit, ceux de l espace reserve
        /// du champ de recherche au tableau 6.2. Ce n est pas un libelle, c est
        /// une marque typographique, et elle ne se traduit pas.
        public static let marqueDeTroncature = "..."

        /// Graisse du texte traduit.
        ///
        /// La graisse normale. La section 1.5 reserve la graisse 600 a cinq cas
        /// nommes, et une bulle traduite n en fait pas partie.
        public static let graisse = Graisse.normale

        /// Bornes typographiques passees au modele.
        ///
        /// C est le seul point ou les valeurs du systeme de design entrent dans
        /// le calcul de mise en page, qui vit dans le modele et ne connait
        /// aucune de ces valeurs.
        public static let gabarit = GabaritDeBulle(
            corpsMaximal: corpsMaximal,
            corpsMinimal: corpsMinimal,
            pas: pasDeCorps,
            margeInterne: margeInterne,
            marqueDeTroncature: marqueDeTroncature
        )

        /// Symbole de l action `Traduire` de la barre du lecteur.
        public static let glyphe = IconeDeReglage.pour(.traduireLesBulles)

        /// Symbole de la mention de traduction dans le nuage.
        public static let glypheDuNuage = Icone.iCloud
    }
}
