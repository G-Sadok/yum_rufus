import Core

//
// Gestion du stockage, sous ecran de la section 5.5 de DESIGN-SPEC.md.
//
// Le document liste `Detail du stockage` parmi les sous ecrans a concevoir cote
// implementation et fixe deux choses : gabarit colonne 580, et les quatre etats.
// Tout le reste est emprunte a des composants deja chiffres, aucune mesure n est
// inventee ici.
//
// L emprunt est deliberement total, comme pour la gestion des prereglages. Un
// ecran atteint depuis une ligne de reglages doit donner l impression de rester
// dans les reglages : meme colonne, meme carte, meme hauteur de ligne, meme
// filet. Une geometrie propre a ce sous ecran se verrait, et se verrait comme
// une incoherence.
//

extension Jetons {
    /// Ecrans de gestion du stockage, section 15 de la section 5.5.
    public enum Stockage {
        /// Largeur de la colonne, contrainte stricte de la section 2.3.
        public static let largeurDeColonne = CarteDeReglages.largeurDeColonne

        /// Rayon de la carte qui porte les lignes.
        public static let rayon = CarteDeReglages.rayon

        /// Epaisseur du filet entre deux lignes.
        public static let epaisseurDuSeparateur = CarteDeReglages.epaisseurDuSeparateur

        /// Encastrement du filet, a gauche seulement.
        public static let encastrementDuSeparateur = CarteDeReglages.encastrementDuSeparateur

        /// Hauteur d une ligne de categorie, sur l ecran d ensemble.
        ///
        /// La ligne porte un libelle, une taille et un chevron, sans sous ligne.
        /// C est la ligne de reglage simple de la section 4.1.
        public static let hauteurDeCategorie = LigneDeReglage.hauteur

        /// Hauteur d une ligne de poste, sur un ecran de detail.
        ///
        /// Le poste porte un titre et une sous ligne, il prend donc la hauteur
        /// d une ligne de reglage a description.
        public static let hauteurDePoste = LigneDeReglage.hauteurAvecDescription

        /// Marge laterale interne d une ligne.
        public static let margeLaterale = LigneDeReglage.margeLaterale

        /// Taille de rendu de l icone de gauche.
        public static let tailleDIcone = LigneDeReglage.tailleDIcone

        /// Gouttiere entre l icone et le libelle.
        public static let gouttiereApresLIcone = LigneDeReglage.gouttiereApresLIcone

        /// Libelle d une categorie.
        public static let libelle = LigneDeReglage.libelle

        /// Titre d un poste, en graisse 600 comme un titre de carte de serie.
        public static let titreDePoste = LigneDeReglage.libelle.enGraisse(.semiGrasse)

        /// Sous ligne d un poste.
        public static let sousLigneDePoste = Typo.footnote

        /// Taille affichee a droite d une ligne.
        public static let taille = LigneDeReglage.valeur

        /// Ecart entre la taille et le chevron qui la suit.
        public static let ecartAvantLeChevron = LigneDeReglage.ecartAvantLeChevron

        /// Taille de rendu du chevron d une ligne de navigation.
        public static let tailleDuChevron = LigneDeReglage.tailleDuChevron

        /// Ecart entre le titre d un poste et sa sous ligne.
        public static let ecartApresLeTitre = Espace.x1

        /// Ecart entre le texte d un poste et sa taille.
        public static let ecartAvantLaTaille = Espace.x4

        /// Ecart entre la liste et la barre de selection.
        public static let ecartAvantLaBarre = Espace.x3

        /// Cote de la cible de la case de selection d un poste.
        public static let coteDeLaSelection = Cible.auDoigt

        /// Taille de rendu du symbole de selection.
        public static let tailleDuSymboleDeSelection = Icone.tailleEnBarreDOutils

        /// Nombre de squelettes affiches pendant le chargement.
        ///
        /// Le document ne le chiffre pas. Trois lignes disent qu une liste
        /// arrive sans promettre une longueur que le disque n a pas encore
        /// rendue, et l etat vide qui suit ne parait pas ampute pour autant.
        public static let nombreDeSquelettes = 3

        /// Symbole de l ecran d ensemble, celui de la ligne de reglages qui mene
        /// ici.
        public static let symbole = IconeDeReglage.pour(.detailDuStockage)

        /// Symbole de la case cochee d un poste retenu.
        public static let symboleCoche = "checkmark.circle.fill"

        /// Symbole de la case vide d un poste non retenu.
        public static let symboleNonCoche = "circle"

        /// Symbole d une categorie.
        ///
        /// Les trois reprennent le symbole de la ligne de reglages la plus
        /// proche, ou celui du tableau 1.10 quand il en nomme un. Aucun n est
        /// invente, aucun n est pris hors de SF Symbols.
        public static func symbole(de categorie: CategorieDeStockage) -> String {
            switch categorie {
            case .chapitresTelecharges: Icone.telechargement
            case .cacheDeChapitres: "archivebox"
            case .cacheDImages: IconeDeReglage.pour(.viderLeCacheDImages)
            }
        }
    }
}
