//
// Signets, sous ecran de la section 5.5 de DESIGN-SPEC.md.
//
// Le document le liste parmi les sous ecrans a concevoir cote implementation, et
// fixe deux choses : gabarit colonne 580, et les quatre etats. Tout le reste est
// emprunte, aucune mesure n est inventee ici.
//
// L emprunt vient de deux endroits, et chacun a sa raison. La colonne, la carte
// et le filet viennent des reglages, comme pour la gestion des prereglages : un
// sous ecran doit donner l impression de rester dans l ecran qui l ouvre. La
// ligne, elle, emprunte a l entree d historique de la section 5.2, parce qu elle
// pose exactement le meme objet : une vignette de 44 par 66, deux lignes de
// texte, et une commande a droite.
//

extension Jetons {
    /// Ecran de consultation des signets.
    public enum Signets {
        /// Largeur de la colonne, contrainte stricte de la section 2.3.
        public static let largeurDeColonne = CarteDeReglages.largeurDeColonne

        /// Rayon de la carte qui porte la liste.
        public static let rayon = CarteDeReglages.rayon

        /// Epaisseur du filet entre deux signets.
        public static let epaisseurDuSeparateur = CarteDeReglages.epaisseurDuSeparateur

        /// Encastrement du filet, a gauche seulement.
        public static let encastrementDuSeparateur = CarteDeReglages.encastrementDuSeparateur

        /// Hauteur d une ligne de signet.
        ///
        /// Celle d une entree d historique : meme vignette, meme nombre de
        /// lignes de texte. Une hauteur propre a cet ecran se verrait comme un
        /// ecart, pas comme une intention.
        public static let hauteurDeLigne = Historique.hauteurDEntree

        /// Marge laterale interne d une ligne.
        public static let margeLaterale = LigneDeReglage.margeLaterale

        /// Largeur de la vignette de la page marquee.
        public static let largeurDeVignette = Historique.largeurDeVignette

        /// Hauteur de la vignette de la page marquee.
        public static let hauteurDeVignette = Historique.hauteurDeVignette

        /// Rayon de la vignette.
        public static let rayonDeVignette = Historique.rayonDeVignette

        /// Titre de la serie, premiere ligne d une entree.
        public static let titreDeSerie = Historique.titreDeSerie

        /// Chapitre et page, seconde ligne d une entree.
        public static let chapitreEtPage = Historique.chapitre

        /// Note laissee par l utilisateur, troisieme ligne quand elle existe.
        public static let note = Typo.footnote

        /// Ecart entre la vignette et les textes.
        public static let ecartApresLaVignette = Historique.ecartApresLaVignette

        /// Ecart entre deux lignes de texte d une entree.
        public static let ecartEntreLesTextes = Espace.x1

        /// Ecart entre le texte de la ligne et le bouton d options.
        public static let ecartAvantLesOptions = Espace.x3

        /// Cote de la cible du bouton d options.
        public static let coteDuBoutonDOptions = Cible.auDoigt

        /// Taille de rendu du symbole d options.
        public static let tailleDuSymboleDOptions = Icone.tailleEnBarreDOutils

        /// Nombre de squelettes affiches pendant le chargement.
        ///
        /// Le document ne le chiffre pas. Trois lignes disent qu une liste
        /// arrive sans promettre une longueur que la base n a pas encore rendue.
        public static let nombreDeSquelettes = 3

        /// Symbole de l ecran et de son etat vide.
        ///
        /// Le tableau 1.10 ne nomme pas d icone de signet. Celle du systeme pour
        /// la meme notion est reprise, comme les commandes de l historique
        /// reprennent la corbeille.
        public static let symbole = "bookmark"

        /// Symbole du bouton d options d une ligne.
        public static let symboleDOptions = "ellipsis.circle"
    }
}
