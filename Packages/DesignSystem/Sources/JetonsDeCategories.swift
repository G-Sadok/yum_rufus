//
// Barre de categories, section 5.1 de DESIGN-SPEC.md.
//
// Le document chiffre quatre valeurs : hauteur 30, rayon 8 de l onglet actif,
// marge basse 12, compteur a 7 du libelle. Les deux valeurs restantes, le
// remplissage horizontal d un onglet et l ecart entre deux onglets, sont
// relevees sur le wireframe 02 et ramenees a l echelle de 4 de la section 1.7.
//

extension Jetons {
    /// Barre de categories posee sous la barre d outils de la bibliotheque.
    public enum BarreDeCategories {
        /// Hauteur d un onglet, et donc de la barre.
        public static let hauteur: Double = 30

        /// Rayon du fond de l onglet actif. Un rayon, pas une capsule.
        public static let rayonDeLOngletActif = Rayon.ongletActif

        /// Marge entre la barre et la grille posee dessous.
        public static let margeBasse = Espace.x3

        /// Distance entre le libelle et son compteur.
        ///
        /// Sept, valeur ecrite par la section 5.1. C est une geometrie interne
        /// de composant, comme la marge de ligne de la barre laterale, elle
        /// echappe donc a l echelle de 4 de la section 1.7.
        public static let ecartDuCompteur: Double = 7

        /// Remplissage de chaque cote du libelle a l interieur de l onglet.
        ///
        /// Le wireframe 02 pose un fond de 96 sous `Tout  128`, ce qui laisse
        /// environ 17 de chaque cote. La valeur la plus proche de l echelle de
        /// 4 est retenue.
        public static let remplissageHorizontal = Espace.x4

        /// Ecart entre deux onglets.
        public static let espaceEntreOnglets = Espace.x3

        /// Libelle d un onglet, actif comme au repos.
        ///
        /// Le wireframe 02 dessine l onglet actif en graisse 600. La section
        /// 1.5 reserve cette graisse a cinq cas, dont l onglet de categorie ne
        /// fait pas partie, et la regle 0.1 rend le texte normatif. L onglet
        /// actif se distingue donc par son fond `surface.menu` et par son
        /// libelle en `text.primary`, jamais par sa graisse.
        public static let libelle = Typo.callout
    }
}
