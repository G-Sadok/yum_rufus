//
// Fiche de serie, sections 5.6 et 4.5 de DESIGN-SPEC.md.
//
// La banniere est le seul endroit du produit ou du texte se pose sur une image
// plutot que sur une surface du systeme. Ses couleurs sont donc ecrites en dur
// par le document, et non prises dans la palette : la couverture floutee et son
// voile restent sombres dans les deux apparences, un texte qui suivrait la
// variante claire y deviendrait illisible.
//

extension Jetons {
    /// En tete de la fiche de serie, section 5.6.
    public enum FicheDeSerie {
        /// Hauteur de la banniere sur macOS et iPad paysage.
        public static let hauteurDeBanniere: Double = 300
        /// Hauteur de la banniere sur iPad portrait.
        public static let hauteurDeBanniereEnPortrait: Double = 260
        /// Hauteur de la banniere sur iPhone, ou l en tete passe en pile.
        public static let hauteurDeBanniereCompacte: Double = 400

        /// Rayon de flou applique a la couverture posee en banniere.
        public static let rayonDeFlou: Double = 40
        /// Voile pose sur la couverture floutee.
        public static let voile = CouleurHexadecimale(0x131315, opacite: 0.55)
        /// Opacite de la barre de titre au dessus de la banniere.
        public static let opaciteDeLaBarreDeTitre: Double = 0.6

        /// Largeur de la couverture nette.
        public static let largeurDeCouverture: Double = 188
        /// Hauteur de la couverture nette.
        public static let hauteurDeCouverture: Double = 278
        /// Largeur de la couverture sur iPad portrait.
        public static let largeurDeCouvertureEnPortrait: Double = 156
        /// Hauteur de la couverture sur iPad portrait.
        public static let hauteurDeCouvertureEnPortrait: Double = 231
        /// Largeur de la couverture sur iPhone.
        public static let largeurDeCouvertureCompacte: Double = 120
        /// Hauteur de la couverture sur iPhone.
        public static let hauteurDeCouvertureCompacte: Double = 178
        /// Rayon de la couverture heros, seule couverture du produit a 12.
        public static let rayonDeCouverture = Rayon.carte
        /// Distance entre le bord gauche du contenu et la couverture.
        public static let margeDeCouverture = Espace.x8
        /// Distance entre la couverture et le bloc de metadonnees.
        public static let ecartApresLaCouverture = Espace.x7

        /// Titre de la serie.
        public static let titre = Typo.display
        /// Titre de la serie sur iPhone.
        public static let titreCompact = Typo.title1
        /// Auteurs, sous le titre.
        public static let auteurs = Typo.callout
        /// Ligne d etat, sous les auteurs.
        public static let ligneDEtat = Typo.callout
        /// Couleur du titre sur la banniere assombrie.
        public static let couleurDuTitre = CouleurHexadecimale(0xF2F2F7)
        /// Couleur des auteurs sur la banniere assombrie.
        public static let couleurDesAuteurs = CouleurHexadecimale(0xC7C7CC)
        /// Couleur de la ligne d etat sur la banniere assombrie.
        public static let couleurDeLaLigneDEtat = CouleurHexadecimale(0x8E8E93)

        /// Hauteur d une pastille de genre.
        public static let hauteurDeGenre: Double = 26
        /// Rayon d une pastille de genre, capsule sur 26 de haut.
        public static let rayonDeGenre: Double = 13
        /// Fond d une pastille de genre, pose sur la banniere.
        public static let fondDeGenre = CouleurHexadecimale(0xFFFFFF, opacite: 0.14)
        /// Libelle d une pastille de genre.
        public static let libelleDeGenre = Typo.footnote
        /// Remplissage horizontal d une pastille de genre.
        public static let remplissageDeGenre = Espace.x3

        /// Fond des trois actions secondaires, posees sur la banniere.
        public static let fondDActionSecondaire = CouleurHexadecimale(0xFFFFFF, opacite: 0.16)
        /// Largeur du bouton d options.
        public static let largeurDuBoutonDOptions: Double = 48
        /// Hauteur des actions de l en tete, bouton principal compris.
        public static let hauteurDAction = Bouton.hauteurEnContenu
        /// Hauteur des actions au doigt, sur iPhone.
        public static let hauteurDActionAuDoigt = Bouton.hauteurAuDoigt
        /// Ecart entre deux actions.
        public static let ecartEntreActions = Espace.x3

        /// Resume de la serie.
        public static let resume = Typo.callout
        /// Nombre de lignes du resume replie.
        public static let lignesDeResume = 3
        /// Bascule d affichage du resume.
        public static let basculeDuResume = Typo.callout

        /// En tete de la liste de chapitres, compteur `N chapitres`.
        public static let compteurDeChapitres = Typo.title2
        /// Actions de l en tete de liste, Filtrer, Trier, Tout marquer lu.
        public static let actionDeListe = Typo.callout

        /// Ecart vertical entre deux blocs du corps.
        public static let ecartDansLeCorps = Espace.x5
        /// Ecart vertical entre deux lignes de metadonnees.
        public static let ecartEntreMetadonnees = Espace.x2
    }

    /// Symboles de la fiche de serie absents du tableau 1.10.
    ///
    /// Le tableau ne liste que les icones nommees par un ecran de reglages ou
    /// par la barre du lecteur. Les deux commandes ci dessous sont dessinees par
    /// le wireframe 04 sans etre nommees, elles reprennent donc le symbole que
    /// le systeme emploie pour la meme action.
    public enum IconeDeFicheDeSerie {
        /// Bouton d options de la serie, trois points du wireframe 04.
        public static let options = "ellipsis"
        /// Retour vers la bibliotheque, chevron de la section 5.6.
        public static let retour = "chevron.left"
    }

    /// Ligne de chapitre, section 4.5.
    public enum LigneDeChapitre {
        /// Hauteur d une ligne.
        public static let hauteur: Double = 56
        /// Rayon d une ligne.
        public static let rayon = Rayon.bouton
        /// Marge laterale interne.
        public static let margeLaterale: Double = 18
        /// Ecart entre deux lignes.
        public static let ecartEntreLignes = Espace.x1

        /// Titre, format `Chapitre N` suivi du titre du chapitre.
        public static let titre = Typo.body
        /// Sous ligne, jamais vide.
        public static let sousLigne = Typo.footnote

        /// Diametre de la pastille pleine d un chapitre non lu.
        public static let diametreDeLaPastille: Double = 12
        /// Epaisseur du filet de progression d un chapitre en cours.
        public static let epaisseurDuFilet: Double = 3
        /// Opacite du filet de progression.
        public static let opaciteDuFilet: Double = 0.6
        /// Taille de rendu de l icone de telechargement.
        public static let tailleDeLIconeDeTelechargement: Double = 22
        /// Ecart entre deux marques de droite.
        public static let ecartEntreMarques = Espace.x3

        /// Epaisseur du contour de selection multiple.
        ///
        /// La section 4.3 pose ce contour de 3 en accent pour la carte de
        /// serie. La ligne de chapitre n a pas de valeur propre dans le
        /// document, et deux contours de selection differents dans le meme
        /// produit ne se justifieraient pas.
        public static let epaisseurDuContourDeSelection: Double = 3
    }

    /// Barre d actions de selection multiple, section 4.5.
    public enum BarreDeSelection {
        /// Hauteur de la barre.
        public static let hauteur: Double = 52
        /// Rayon de la barre.
        public static let rayon = Rayon.carte
        /// Elevation de la barre.
        public static let elevation = Elevation.flottant
        /// Compteur `N selectionnes`, a gauche.
        public static let compteur = Typo.callout.enGraisse(.grasse)
        /// Marge laterale interne.
        public static let margeLaterale = Espace.x5
        /// Ecart entre deux actions.
        public static let ecartEntreActions = Espace.x4
        /// Marge entre la barre et le bas de la zone de liste.
        public static let margeBasse = Espace.x4
    }
}
