import Core

//
// Statistiques de lecture, sous ecran de la section 5.5 de DESIGN-SPEC.md.
//
// Le document liste `Statistiques de lecture` parmi les sous ecrans a concevoir
// cote implementation et fixe deux choses : gabarit colonne 580, et les quatre
// etats. Tout le reste est emprunte a des composants deja chiffres, aucune
// mesure n est inventee ici.
//
// L emprunt est total, comme pour les signets et la gestion du stockage. Un
// ecran atteint depuis une ligne de reglages doit donner l impression de rester
// dans les reglages : meme colonne, meme carte, meme hauteur de ligne, meme
// filet, meme compteur.
//
// Une seule mesure ne vient pas des reglages, la hauteur de la barre de
// progression. Elle est prise au filet de progression de la section 3, seule
// barre de progression que le document chiffre.
//

extension Jetons {
    /// Ecran de statistiques de lecture, sous ecran de la section 5.5.
    public enum Statistiques {
        /// Largeur de la colonne, contrainte stricte de la section 2.3.
        public static let largeurDeColonne = CarteDeReglages.largeurDeColonne

        /// Rayon des cartes qui portent les lignes.
        public static let rayon = CarteDeReglages.rayon

        /// Epaisseur du filet entre deux lignes.
        public static let epaisseurDuSeparateur = CarteDeReglages.epaisseurDuSeparateur

        /// Encastrement du filet, a gauche seulement.
        public static let encastrementDuSeparateur = CarteDeReglages.encastrementDuSeparateur

        /// Hauteur d une ligne simple, libelle et valeur.
        public static let hauteurDeLigne = LigneDeReglage.hauteur

        /// Hauteur d une ligne qui porte une barre sous son libelle.
        ///
        /// Celle d une ligne de reglage a curseur : meme composition, un libelle
        /// et sa valeur sur la premiere ligne, un trait horizontal sur la
        /// seconde.
        public static let hauteurAvecBarre = LigneDeReglage.hauteurAvecDescription

        /// Marge laterale interne d une ligne.
        public static let margeLaterale = LigneDeReglage.margeLaterale

        /// Taille de rendu de l icone de gauche.
        public static let tailleDIcone = LigneDeReglage.tailleDIcone

        /// Gouttiere entre l icone et le libelle.
        public static let gouttiereApresLIcone = LigneDeReglage.gouttiereApresLIcone

        /// Libelle d une ligne.
        public static let libelle = LigneDeReglage.libelle

        /// Valeur affichee a droite d une ligne.
        public static let valeur = LigneDeReglage.valeur

        /// Valeur chiffree posee sous un libelle, comme celle d un curseur.
        public static let valeurSecondaire = LigneDeReglage.valeurDuCurseur

        /// Libelle d une journee de la carte des derniers jours.
        public static let libelleDeJournee = Typo.footnote

        /// En tete de section.
        public static let enTete = CarteDeReglages.enTete

        /// Description posee sous une carte.
        public static let description = CarteDeReglages.description

        /// Ecart entre l en tete et le haut de la carte.
        public static let ecartApresLEnTete = CarteDeReglages.ecartApresLEnTete

        /// Ecart entre le bas d une carte et sa description.
        public static let ecartAvantLaDescription = CarteDeReglages.ecartAvantLaDescription

        /// Espacement entre deux sections.
        public static let espaceEntreSections = CarteDeReglages.espaceEntreSections

        /// Marge verticale entre le haut de la colonne et la premiere section.
        public static let margeVerticale = CarteDeReglages.margeVerticale

        /// Ecart entre le libelle d une ligne et sa valeur.
        public static let ecartAvantLaValeur = Espace.x4

        /// Ecart entre le libelle et la barre qui le suit.
        public static let ecartAvantLaBarre = Espace.x2

        /// Ecart entre le libelle d une journee et sa barre.
        public static let ecartDansUneJournee = Espace.x3

        /// Largeur reservee au libelle d une journee.
        ///
        /// Les sept libelles sont alignes sur la meme colonne, sans quoi les
        /// barres commenceraient a sept abscisses differentes. La largeur est
        /// celle du debut de libelle de la section 4.1, deja employee pour
        /// aligner toutes les lignes de reglages du produit.
        public static let largeurDuLibelleDeJournee = LigneDeReglage.debutDuLibelle

        /// Decalage de la barre posee sous un libelle de ligne.
        ///
        /// Elle commence a l aplomb du libelle, a 58 du bord de la carte comme
        /// le curseur de la section 4.1. La marge laterale en couvre deja 20.
        public static let decalageDeLaBarre = LigneDeReglage.decalageDuControleEnPile

        /// Largeur reservee au compte d une journee.
        ///
        /// Meme raison que ci dessus, du cote droit. La mesure est celle du
        /// conteneur du compteur de la section 4.1.
        public static let largeurDuCompteDeJournee = CompteurDeReglage.largeur

        /// Hauteur d une ligne de la carte des derniers jours.
        ///
        /// Sept lignes de reglage tiendraient trois cent soixante quatre points
        /// pour sept nombres. La journee porte un libelle et un chiffre sans
        /// controle a viser, elle prend donc la hauteur de la cible de pointage
        /// au pointeur de la section 7, qui est le plancher du produit.
        public static let hauteurDeJournee = Cible.auPointeur

        /// Hauteur de la barre de progression.
        ///
        /// Celle du filet de progression de la section 3, seule barre de
        /// progression que le document chiffre.
        public static let hauteurDeLaBarre: Double = 4

        /// Nombre de squelettes affiches pendant le chargement.
        ///
        /// Le document ne le chiffre pas. Trois lignes disent qu un contenu
        /// arrive sans promettre une longueur que la base n a pas encore
        /// rendue, comme sur les signets et le stockage.
        public static let nombreDeSquelettes = 3

        /// Symbole de l ecran, celui de la ligne de reglages qui mene ici.
        public static let symbole = IconeDeReglage.pour(.statistiquesDeLecture)

        /// Symbole de la ligne d objectif.
        ///
        /// Le tableau 1.10 ne nomme pas d icone d objectif. Celle du systeme
        /// pour la meme notion est reprise, comme le fait deja la table des
        /// icones de reglages pour les lignes que le tableau ignore.
        public static let symboleDeLObjectif = "target"

        /// Symbole de la ligne de rappel, celui des notifications de la table
        /// des icones de reglages.
        public static let symboleDuRappel = IconeDeReglage.pour(.notificationsDeNouveauxChapitres)

        /// Symbole de la serie de jours consecutifs.
        public static let symboleDeLaSerie = "calendar"

        /// Symbole du compte de chapitres.
        public static let symboleDesChapitres = "book.closed"

        /// Symbole du compte de pages.
        public static let symboleDesPages = "doc.on.doc"

        /// Symbole du compte de jours de lecture.
        public static let symboleDesJours = Icone.historique
    }
}
