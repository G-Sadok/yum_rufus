//
// Reglages, sections 4.1, 4.2 et 5.5 de DESIGN-SPEC.md.
//
// La ligne de reglage est le composant le plus utilise du produit. Toutes ses
// mesures sont chiffrees par le document, aucune n est deduite.
//

extension Jetons {
    /// Ligne de reglage, section 4.1.
    public enum LigneDeReglage {
        /// Hauteur de la version simple.
        public static let hauteur: Double = 52
        /// Hauteur avec description ou curseur.
        public static let hauteurAvecDescription: Double = 76
        /// Marge laterale interne.
        public static let margeLaterale: Double = 20
        /// Taille de rendu de l icone de gauche.
        public static let tailleDIcone = Icone.tailleEnLigneDeReglage
        /// Gouttiere entre l icone et le libelle.
        public static let gouttiereApresLIcone: Double = 16
        /// Distance entre le bord gauche de la carte et le debut du libelle.
        public static let debutDuLibelle: Double = 58
        /// Libelle de la ligne.
        public static let libelle = Typo.body
        /// Libelle d une ligne premium, en graisse 600.
        public static let libellePremium = Typo.body.enGraisse(.semiGrasse)
        /// Valeur affichee a droite du libelle.
        public static let valeur = Typo.body
        /// Valeur numerique d une ligne a curseur.
        public static let valeurDuCurseur = Typo.footnote

        /// Ecart entre la valeur et le chevron qui la suit.
        public static let ecartAvantLeChevron: Double = 4

        /// Decalage du controle quand la ligne passe en disposition verticale.
        ///
        /// La section 4.1 aligne alors le controle a gauche, a 58 du bord de la
        /// carte. La marge laterale en couvre deja 20.
        public static let decalageDuControleEnPile = debutDuLibelle - margeLaterale

        /// Taille de rendu d un chevron de ligne.
        ///
        /// Le document ne la chiffre pas. Le chevron est un complement de
        /// libelle et non une commande a lui seul, il prend donc la taille de
        /// rendu la plus petite du tableau 1.10, celle des menus.
        public static let tailleDuChevron = Icone.tailleEnMenu

        /// Taille de rendu de la couronne d une ligne premium.
        public static let tailleDeLaCouronne = Icone.tailleEnBarreDOutils
    }

    /// Interrupteur d une ligne de reglage, variante 1 de la section 4.1.
    public enum Interrupteur {
        /// Largeur du commutateur.
        public static let largeur: Double = 48
        /// Hauteur du commutateur.
        public static let hauteur: Double = 28
        /// Rayon du commutateur, capsule sur 28 de haut.
        public static let rayon: Double = 14
        /// Diametre de la pastille blanche.
        public static let diametreDeLaPastille: Double = 24
        /// Jeu entre la pastille et le bord du commutateur.
        public static let jeu: Double = 2
    }

    /// Compteur d une ligne de reglage, variante 5 de la section 4.1.
    public enum CompteurDeReglage {
        /// Largeur du conteneur des deux chevrons empiles.
        public static let largeur: Double = 30
        /// Hauteur du conteneur.
        public static let hauteur: Double = 28
        /// Rayon du conteneur.
        public static let rayon = Rayon.ongletActif
        /// Ecart entre la valeur et le conteneur.
        public static let ecartApresLaValeur = Espace.x2
    }

    /// Carte de section, section 4.2, et colonne de la section 5.5.
    public enum CarteDeReglages {
        /// Largeur de la colonne, contrainte stricte de la section 2.3.
        public static let largeurDeColonne = Contenu.largeurDeColonne
        /// Rayon de la carte.
        public static let rayon = Rayon.carte
        /// Epaisseur du separateur entre deux lignes.
        public static let epaisseurDuSeparateur: Double = 1
        /// Encastrement du separateur, a gauche seulement.
        public static let encastrementDuSeparateur: Double = 20

        /// En tete de section.
        public static let enTete = Typo.headline
        /// Description posee sous la carte.
        public static let description = Typo.footnote
        /// Note de fin de section, sous la carte A propos.
        public static let note = Typo.caption

        /// Distance entre l en tete et le haut de la carte.
        ///
        /// Le document chiffre 14, qui n appartient pas a l echelle de 4 de la
        /// section 1.7. C est une mesure de composant et non un espacement de
        /// mise en page, elle y echappe donc, comme la marge des entrees de
        /// barre laterale.
        public static let ecartApresLEnTete: Double = 14
        /// Distance entre le bas de la carte et sa description.
        public static let ecartAvantLaDescription = Espace.x3
        /// Espacement entre deux sections.
        public static let espaceEntreSections = Espace.x7
        /// Marge verticale entre le haut de la colonne et la premiere section.
        public static let margeVerticale = Espace.x6
    }

    /// Banniere d erreur de l ecran Reglages, section 5.5.
    ///
    /// Elle se pose en haut de colonne et laisse le reste de la colonne
    /// utilisable : une synchronisation en echec n empeche pas de changer de
    /// theme.
    public enum BanniereDeReglages {
        /// Rayon de la banniere.
        public static let rayon = Rayon.carte
        /// Epaisseur du contour.
        public static let epaisseurDuContour: Double = 1
        /// Titre de la banniere.
        public static let titre = Typo.headline
        /// Phrase de la banniere.
        public static let phrase = Typo.footnote
        /// Remplissage interne.
        public static let remplissage = Espace.x4
        /// Ecart entre le titre et la phrase.
        public static let ecartApresLeTitre = Espace.x2
        /// Ecart entre la phrase et les boutons.
        public static let ecartAvantLesBoutons = Espace.x3
        /// Ecart entre deux boutons.
        public static let ecartEntreLesBoutons = Espace.x2
    }
}
