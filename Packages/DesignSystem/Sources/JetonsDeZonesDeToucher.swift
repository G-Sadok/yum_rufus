//
// Tutoriel des zones de toucher, section 5.7 de DESIGN-SPEC.md.
//
// Le document donne une seule phrase pour cette surimpression : les zones ne
// sont jamais visibles, sauf pendant le tutoriel de premiere ouverture ou elles
// apparaissent pendant 4 secondes, les deux zones laterales a 6 pour cent
// d accent, la zone centrale a 3 pour cent de blanc. Ces trois valeurs sont
// ici, et nulle part ailleurs.
//
// Les opacites sont volontairement basses. La these du document veut que
// l interface disparaisse devant le dessin, et cette surimpression est la seule
// du produit qui se pose sur la page elle meme : elle doit montrer le decoupage
// sans faire quitter la planche des yeux.
//

extension Jetons {
    /// Zones de toucher et leur tutoriel, section 5.7.
    public enum ZonesDeToucher {
        /// Opacite de l aplat d accent pose sur une zone qui tourne une page.
        public static let opaciteDeZoneActive: Double = 0.06

        /// Opacite du blanc pose sur la zone qui appelle les barres.
        public static let opaciteDeZoneDeMenu: Double = 0.03

        /// Couleur de la zone qui appelle les barres.
        ///
        /// Le blanc pur du document, et non un jeton de texte : la zone est un
        /// aplat de surface, pas un libelle. Il n existe pas ailleurs dans les
        /// tableaux de la section 1, il vit donc avec le composant qui
        /// l emploie, comme le voile de bas de couverture de la section 3.
        public static let couleurDeZoneDeMenu = CouleurHexadecimale(0xFFFFFF)

        /// Transition d apparition et de retrait de la surimpression.
        ///
        /// Le tableau 1.9 ne la nomme pas. Celle des barres du lecteur est la
        /// seule transition du document qui gouverne un element pose sur la
        /// page, et le tutoriel apparait au meme endroit et pour la meme
        /// raison. La translation de 8 px ne s applique pas : les zones sont
        /// calees sur les bords de la surface, les faire glisser mentirait sur
        /// leur geometrie.
        public static let apparition = Jetons.Mouvement.barresDuLecteur
    }
}
