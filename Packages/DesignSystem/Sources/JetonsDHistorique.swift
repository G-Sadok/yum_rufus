//
// Historique, section 5.2 de DESIGN-SPEC.md, et modale courte, section 4.8.
//
// La section 5.2 chiffre l entree, la vignette et les trois roles de texte.
// Tout ce qu elle ne chiffre pas, ecarts et marges, sort de l echelle de la
// section 1.7, jamais d un ajustement optique invente sur place.
//

extension Jetons {
    /// Liste de l historique, section 5.2.
    public enum Historique {
        /// Hauteur d une entree.
        public static let hauteurDEntree: Double = 80
        /// Largeur de la vignette.
        public static let largeurDeVignette: Double = 44
        /// Hauteur de la vignette.
        public static let hauteurDeVignette: Double = 66
        /// Rayon de la vignette, seule autre valeur a 6 avec la pastille.
        public static let rayonDeVignette = Rayon.pastille

        /// Titre de la serie, premiere ligne de l entree.
        public static let titreDeSerie = Typo.body.enGraisse(.semiGrasse)
        /// Chapitre lu, seconde ligne de l entree.
        public static let chapitre = Typo.footnote
        /// Heure de la lecture, alignee a droite.
        public static let heure = Typo.footnote
        /// En tete collant qui porte le jour.
        public static let enTeteDeJour = Typo.headline

        /// Cote du bouton de suppression, qui apparait au survol.
        public static let coteDuBoutonDeSuppression: Double = 26
        /// Taille de rendu du symbole de suppression.
        ///
        /// Le document ne la chiffre pas. Elle reprend la taille de rendu des
        /// barres d outils de la section 1.10, la seule qui tienne dans une
        /// cible de 26 sans la remplir jusqu au bord.
        public static let tailleDuSymboleDeSuppression = Icone.tailleEnBarreDOutils

        /// Rayon d une entree, comme toute ligne cliquable du produit.
        public static let rayonDEntree = Rayon.bouton
        /// Marge laterale interne d une entree.
        public static let margeLaterale = Espace.x4
        /// Ecart entre la vignette et les textes.
        public static let ecartApresLaVignette = Espace.x3
        /// Ecart entre deux entrees.
        public static let ecartEntreEntrees = Espace.x1
        /// Hauteur de l en tete collant.
        public static let hauteurDEnTete: Double = 40
        /// Marge au dessus d un en tete, hors premier.
        public static let margeAvantEnTete = Espace.x5
        /// Marge basse de la liste, sous la derniere entree.
        public static let margeBasse = Espace.x6
    }

    /// Symboles de l historique absents du tableau 1.10.
    ///
    /// Le tableau ne nomme que les icones des ecrans de reglages et de la barre
    /// du lecteur. Les deux commandes ci dessous sont decrites par la section
    /// 5.2 sans etre nommees, elles reprennent donc le symbole que le systeme
    /// emploie pour la meme action.
    public enum IconeDHistorique {
        /// Suppression d une entree, bouton de 26 apparaissant au survol.
        public static let supprimer = "trash"
        /// Effacement global, bouton de la barre d outils.
        public static let effacer = "trash"
    }

    /// Modale courte, section 4.8.
    public enum Modale {
        /// Largeur de la modale.
        public static let largeur: Double = 380
        /// Hauteur du cas de reference.
        public static let hauteurDeReference: Double = 196
        /// Rayon de la modale.
        public static let rayon = Rayon.modale
        /// Elevation de la modale.
        public static let elevation = Elevation.modal
        /// Marge interieure en haut et sur les cotes.
        public static let margeHaute = Espace.x7
        /// Marge interieure en bas.
        public static let margeBasse = Espace.x6
        /// Largeur d un bouton de pied.
        public static let largeurDeBouton: Double = 150
        /// Hauteur d un bouton de pied.
        public static let hauteurDeBouton = Bouton.hauteurEnModale
        /// Rayon capsule d un bouton de pied.
        public static let rayonDeBouton = Bouton.rayonEnModale
        /// Gouttiere entre les deux boutons de pied.
        public static let gouttiereEntreBoutons = Espace.x4

        /// Titre de la modale, seul role de texte a 16 du produit.
        ///
        /// La section 4.8 chiffre 16 en graisse 700, la ou l echelle de la
        /// section 1.5 n a que 17 en `title2` et 15 en `headline`. La regle 0.1
        /// tranche : le chiffre du texte est normatif.
        public static let titre = StyleTypographique(
            taille: 16,
            graisse: .grasse,
            interlignage: 22,
            interlettrageEnEm: 0
        )

        /// Description, deux lignes maximum.
        public static let description = Typo.callout
        /// Nombre de lignes de la description.
        public static let lignesDeDescription = 2
        /// Ecart entre le titre et la description.
        public static let ecartApresLeTitre = Espace.x2
        /// Ecart entre la description et les boutons.
        public static let ecartAvantLesBoutons = Espace.x6
    }
}
