//
// Mesures de la carte de serie, section 4.3.
//

extension Jetons {
    /// Carte de serie de la grille, section 4.3.
    public enum CarteDeSerie {
        /// Largeur minimale d une carte, bas de la fourchette du document.
        public static let largeurMinimale: Double = 150

        /// Largeur maximale d une carte, haut de la fourchette.
        public static let largeurMaximale: Double = 200

        /// Ratio de la couverture, deux tiers.
        public static let ratio: Double = 2.0 / 3.0

        /// Rayon de la couverture.
        public static let rayon: Double = 10

        /// Gouttiere entre le titre et la couverture, et entre les cartes.
        public static let gouttiereDuTitre: Double = 10

        /// Gouttiere de la grille, celle de la section 2.4.
        public static let gouttiere = Espace.x4

        /// Nombre de lignes du titre avant troncature.
        public static let lignesDuTitre = 2

        /// Titre de la carte, `callout` en graisse 600.
        public static let titre = StyleTypographique(
            taille: Typo.callout.taille,
            graisse: .semiGrasse,
            interlignage: Typo.callout.interlignage,
            interlettrageEnEm: Typo.callout.interlettrageEnEm
        )

        /// Compteur de chapitres non lus.
        public static let pastille = Typo.caption
    }
}
