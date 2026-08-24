//
// Rayons et espacements, sections 1.6 et 1.7 de DESIGN-SPEC.md.
//

extension Jetons {
    /// Rayons de coin, section 1.6.
    ///
    /// Chaque valeur porte le nom de ce qu elle arrondit. Un rayon ecrit en
    /// clair dans une vue est une infraction, meme s il tombe juste.
    public enum Rayon {
        /// Pastille de non lus dans une liste, vignette d historique.
        public static let pastille: Double = 6
        /// Onglet de categorie actif, bouton de barre d outils.
        public static let ongletActif: Double = 8
        /// Champ de saisie, bouton d etat vide.
        public static let champ: Double = 9
        /// Bouton, conteneur d icone, couverture de carte, ligne de chapitre.
        public static let bouton: Double = 10
        /// Carte, bouton principal du mur premium.
        public static let carte: Double = 12
        /// Barre laterale, menu contextuel, carte d etat de contenu.
        public static let barreLaterale: Double = 14
        /// Feuille de configuration, mur premium.
        public static let feuille: Double = 16
        /// Fenetre.
        public static let fenetre: Double = 18
        /// Modale courte.
        public static let modale: Double = 20
        /// Capsule des boutons de modale et de feuille, hauteur 34.
        ///
        /// Aussi le rayon de la pastille de non lus posee sur une couverture.
        public static let capsule: Double = 17

        /// Rayons du tableau 1.6, hors capsule, dans l ordre croissant.
        public static let echelle: [Double] = [
            pastille,
            ongletActif,
            champ,
            bouton,
            carte,
            barreLaterale,
            feuille,
            fenetre,
            modale,
        ]
    }

    /// Espacements, section 1.7.
    ///
    /// Echelle de 4. Aucune autre valeur, y compris pour un ajustement optique.
    public enum Espace {
        public static let x1: Double = 4
        public static let x2: Double = 8
        public static let x3: Double = 12
        public static let x4: Double = 16
        public static let x5: Double = 20
        public static let x6: Double = 24
        public static let x7: Double = 32
        public static let x8: Double = 40
        public static let x9: Double = 56
        public static let x10: Double = 72

        /// Les dix seules valeurs d espacement autorisees.
        public static let echelle: [Double] = [x1, x2, x3, x4, x5, x6, x7, x8, x9, x10]
    }
}
