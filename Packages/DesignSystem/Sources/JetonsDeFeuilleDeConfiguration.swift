//
// Feuille de configuration, section 4.9 de DESIGN-SPEC.md.
//
// Le tableau de la section chiffre la feuille que chaque entree du menu plus de
// l ecran Parcourir ouvre, section 5.3. La feuille d installation d une
// extension en est une, et c est pour cela que ses valeurs sont ici plutot que
// dans un jeu de jetons qui lui serait propre : deux feuilles differentes
// donneraient deux largeurs, et le document n en donne qu une.
//
// Trois valeurs sortent de l echelle de la section 1.7, et c est le document
// qui le veut. L etiquette de champ est a 10 au dessus du champ, l ecart entre
// deux champs vaut 26, et la pastille de retour de test vaut 12. La regle 0.1
// tranche : le texte du cahier des charges est normatif pour toute valeur
// chiffree. Elles sont donc reprises telles quelles, et nommees ici pour que
// personne n aille les reecrire en clair dans une vue.
//

extension Jetons {
    /// Feuille de configuration, section 4.9.
    public enum Feuille {
        /// Largeur de la feuille.
        public static let largeur: Double = 440
        /// Hauteur du cas de reference.
        public static let hauteurDeReference: Double = 420
        /// Rayon de la feuille.
        public static let rayon = Rayon.feuille
        /// Elevation de la feuille.
        public static let elevation = Elevation.modal

        /// Marge interieure en haut et sur les cotes, comme la modale 4.8.
        ///
        /// La section 4.9 ne la chiffre pas. Elle reprend celle de la modale
        /// plutot que d en inventer une seconde : les deux surfaces sont la
        /// meme, `surface.sheet` a l elevation 2.
        public static let margeHaute = Espace.x7
        /// Marge interieure en bas.
        public static let margeBasse = Espace.x6

        /// Titre de la feuille.
        public static let titre = Typo.title2
        /// Phrase d explication sous le titre.
        public static let explication = Typo.footnote
        /// Etiquette posee au dessus d un champ ou d une section.
        public static let etiquette = Typo.footnote

        /// Ecart entre l etiquette et ce qu elle nomme.
        ///
        /// Hors de l echelle de la section 1.7, impose par le tableau 4.9.
        public static let ecartApresLEtiquette: Double = 10

        /// Ecart entre deux champs.
        ///
        /// Hors de l echelle de la section 1.7, impose par le tableau 4.9.
        public static let ecartEntreChamps: Double = 26

        /// Largeur d un champ de saisie.
        public static let largeurDeChamp: Double = 384
        /// Hauteur d un champ de saisie en feuille.
        public static let hauteurDeChamp: Double = 34
        /// Rayon d un champ de saisie.
        public static let rayonDeChamp = Rayon.champ

        /// Largeur du bouton de test de connexion.
        public static let largeurDuBoutonDeTest: Double = 180

        /// Diametre de la pastille de retour de test.
        ///
        /// Hors de l echelle de la section 1.7, impose par le tableau 4.9.
        public static let pastilleDeRetour: Double = 12

        /// Texte du retour de test, a cote de la pastille.
        public static let retourDeTest = Typo.footnote

        /// Largeur d un bouton de pied.
        public static let largeurDeBouton: Double = 120
        /// Hauteur d un bouton de pied.
        public static let hauteurDeBouton = Bouton.hauteurEnModale
        /// Rayon capsule d un bouton de pied.
        public static let rayonDeBouton = Bouton.rayonEnModale
        /// Gouttiere entre les deux boutons de pied, comme la modale 4.8.
        public static let gouttiereEntreBoutons = Espace.x4
        /// Ecart entre le contenu et les boutons de pied.
        public static let ecartAvantLesBoutons = Espace.x6
    }

    /// Feuille d installation d une extension, entree 12 du menu 5.3.
    ///
    /// Elle n ajoute aucune valeur chiffree a la section 4.9. Ce qui lui est
    /// propre, la liste des domaines, se compose des roles de texte de la
    /// section 1.5 et des espacements de la section 1.7, parce que le document
    /// ne chiffre pas cette liste et qu inventer un chiffre serait pire que
    /// reutiliser l echelle.
    public enum InstallationDExtension {
        /// Un domaine de la liste que l utilisateur relit avant de confirmer.
        public static let domaine = Typo.callout
        /// Ecart entre deux domaines.
        public static let ecartEntreDomaines = Espace.x2
        /// Ecart entre le glyphe d un domaine et son nom.
        public static let ecartApresLeGlyphe = Espace.x2
        /// Taille de rendu du glyphe d un domaine.
        public static let tailleDuGlyphe = Icone.tailleEnMenu
        /// Avertissement de responsabilite et mention des sous domaines.
        public static let avertissement = Typo.footnote
        /// Ecart entre deux blocs de la feuille.
        public static let ecartEntreBlocs = Espace.x5
    }

    /// Symboles de la feuille d installation, section 1.10.
    public enum IconeDExtension {
        /// Domaine que l extension pourra joindre.
        public static let domaine = "globe"
        /// Domaine couvrant des sous domaines, et mention de responsabilite.
        public static let avertissement = "exclamationmark.triangle"
        /// Case de lecture de la liste, cochee.
        public static let listeLue = "checkmark.square"
        /// Case de lecture de la liste, non cochee.
        public static let listeNonLue = "square"
    }
}
