//
// Panneau de filtres du lecteur, section 5.7 de DESIGN-SPEC.md.
//
// Le document chiffre trois mesures pour ce panneau : une largeur de 300, un
// rayon de 14 et une elevation de niveau 1. Elles sont ici, et elles sont les
// seules qui lui appartiennent en propre.
//
// Tout le reste est emprunte, et volontairement. Le panneau empile cinq lignes a
// curseur et trois lignes a interrupteur, c est a dire les variantes 4 et 1 de
// la section 4.1. Leur geometrie est deja chiffree la bas, hauteur, marge
// laterale, filet de separation comprise. Redefinir ces mesures ici donnerait
// deux lignes de reglage differentes dans le meme produit selon l ecran ouvert,
// et la section 4.1 dit que c est le composant le plus utilise, pas qu il en
// existe deux variantes concurrentes.
//
// Le panneau ne pose aucune icone a gauche de ses libelles. Le tableau 1.10 ne
// nomme de symbole que pour la luminosite, la chaleur et les deux traitements
// par IA. En inventer pour la nettete, le contraste, le gamma et la reduction du
// bruit reviendrait a poser des valeurs visuelles que le document ne justifie
// pas, ce que la regle 4 du projet interdit. La colonne d icones tombe donc en
// entier, plutot que d etre a moitie vraie.
//

extension Jetons {
    /// Panneau de filtres du lecteur, section 5.7.
    public enum PanneauDeFiltres {
        /// Largeur du popover, chiffree par la section 5.7.
        public static let largeur: Double = 300

        /// Rayon du popover, chiffre par la section 5.7.
        public static let rayon = Rayon.barreLaterale

        /// Elevation du popover, chiffree par la section 5.7.
        ///
        /// Le niveau 1 ajoute son ombre et le contour `border` que le tableau
        /// 1.8 lui associe.
        public static let elevation = NiveauDElevation.flottant

        /// Marge verticale entre le bord du panneau et sa premiere ligne.
        ///
        /// Le popover n est pas une carte de reglages : il n a ni en tete ni
        /// description, et ses lignes portent deja leur propre marge laterale.
        /// Seule la marge haute et basse reste a poser.
        public static let margeVerticale = Espace.x3

        /// Hauteur d une ligne a interrupteur, variante 1 de la section 4.1.
        public static let hauteurDInterrupteur = LigneDeReglage.hauteur

        /// Hauteur d une ligne a curseur, variante 4 de la section 4.1.
        public static let hauteurDeCurseur = LigneDeReglage.hauteurAvecDescription

        /// Marge laterale d une ligne, section 4.1.
        public static let margeLaterale = LigneDeReglage.margeLaterale

        /// Ecart entre le libelle et le curseur qui le suit.
        public static let ecartAvantLeControle = Espace.x2

        /// Filet pose entre les curseurs et les interrupteurs, section 5.7.
        ///
        /// C est le seul separateur du panneau, et il porte l epaisseur et la
        /// couleur de celui des cartes de la section 4.2. Il traverse en
        /// revanche toute la largeur : il separe deux groupes de lignes, pas
        /// deux lignes d un meme groupe, et un filet encastre laisserait croire
        /// a une simple suite.
        public static let epaisseurDuSeparateur = CarteDeReglages.epaisseurDuSeparateur

        /// Libelle d une ligne du panneau.
        public static let libelle = LigneDeReglage.libelle

        /// Valeur numerique posee a droite d un curseur.
        public static let valeur = LigneDeReglage.valeurDuCurseur

        /// Taille de rendu de la couronne d un traitement verrouille.
        public static let tailleDeLaCouronne = LigneDeReglage.tailleDeLaCouronne
    }
}
