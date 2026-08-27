//
// Gestion des prereglages, sous ecran de la section 5.5 de DESIGN-SPEC.md.
//
// Le document le liste parmi les sous ecrans a concevoir cote implementation,
// et fixe deux choses : gabarit colonne 580, et les quatre etats. Tout le reste
// est emprunte, aucune mesure n est inventee ici.
//
// L emprunt est deliberatement total. Un ecran atteint depuis une ligne de
// reglages doit donner l impression de rester dans les reglages : meme colonne,
// meme carte, meme hauteur de ligne, meme filet. Une geometrie propre a ce sous
// ecran se verrait, et se verrait comme une incoherence.
//

extension Jetons {
    /// Ecran de gestion des prereglages de lecture.
    public enum Prereglages {
        /// Largeur de la colonne, contrainte stricte de la section 2.3.
        public static let largeurDeColonne = CarteDeReglages.largeurDeColonne

        /// Rayon de la carte qui porte la liste.
        public static let rayon = CarteDeReglages.rayon

        /// Epaisseur du filet entre deux prereglages.
        public static let epaisseurDuSeparateur = CarteDeReglages.epaisseurDuSeparateur

        /// Encastrement du filet, a gauche seulement.
        public static let encastrementDuSeparateur = CarteDeReglages.encastrementDuSeparateur

        /// Hauteur d une ligne de prereglage.
        ///
        /// La ligne porte un nom et un resume, elle prend donc la hauteur d une
        /// ligne de reglage a description et non celle d une ligne simple.
        public static let hauteurDeLigne = LigneDeReglage.hauteurAvecDescription

        /// Marge laterale interne d une ligne.
        public static let margeLaterale = LigneDeReglage.margeLaterale

        /// Nom du prereglage.
        public static let nom = LigneDeReglage.libelle

        /// Resume de ce que le prereglage capture, pose sous le nom.
        public static let resume = LigneDeReglage.valeurDuCurseur

        /// Ecart entre le nom et son resume.
        public static let ecartApresLeNom = Espace.x1

        /// Ecart entre le texte de la ligne et le bouton d options.
        public static let ecartAvantLesOptions = Espace.x3

        /// Cote de la cible du bouton d options.
        ///
        /// La cible au doigt de la section 7 s applique, parce que l ecran est
        /// le meme sur iPhone et sur macOS. Le symbole, lui, garde la taille de
        /// rendu des barres d outils.
        public static let coteDuBoutonDOptions = Cible.auDoigt

        /// Taille de rendu du symbole d options.
        public static let tailleDuSymboleDOptions = Icone.tailleEnBarreDOutils

        /// Nombre de squelettes affiches pendant le chargement.
        ///
        /// Le document ne le chiffre pas. Trois lignes disent qu une liste
        /// arrive sans promettre une longueur que la base n a pas encore
        /// rendue, et l etat vide qui suit ne parait pas ampute pour autant.
        public static let nombreDeSquelettes = 3

        /// Symbole de l etat vide et de l en tete, celui de la ligne de
        /// reglages qui mene ici.
        public static let symbole = IconeDeReglage.pour(.prereglages)

        /// Symbole du bouton d options d une ligne.
        public static let symboleDOptions = "ellipsis.circle"
    }
}
