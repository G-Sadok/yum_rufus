//
// Coquille de l application, sections 2.1, 2.2, 2.3 et 2.5 de DESIGN-SPEC.md.
//
// Ces valeurs sont celles de la mise en page chiffree. Elles vivent ici pour la
// meme raison que les couleurs : une vue qui ecrit 196 en clair fait diverger la
// barre laterale du document des la premiere retouche.
//

extension Jetons {
    /// Fenetre macOS, section 2.1.
    public enum Fenetre {
        /// Largeur minimale de la fenetre.
        public static let largeurMinimale: Double = 1024
        /// Hauteur minimale de la fenetre.
        public static let hauteurMinimale: Double = 720
        /// Largeur a la premiere ouverture.
        public static let largeurParDefaut: Double = 1280
        /// Hauteur a la premiere ouverture.
        public static let hauteurParDefaut: Double = 860
        /// Barre de titre unifiee avec la barre d outils.
        public static let hauteurDeBarreDeTitre: Double = 60
        /// Epaisseur du filet pose sous la barre de titre.
        public static let epaisseurDuFilet: Double = 1
        /// Couleur du filet sous la barre de titre, en apparence sombre.
        public static let filetSousLaBarreDeTitre = CouleurHexadecimale(0x2A2A2E)
        /// Rayon de la fenetre.
        public static let rayon = Rayon.fenetre
    }

    /// Barre laterale, section 2.2.
    ///
    /// La barre est encastree : elle flotte a 12 des quatre bords de la
    /// coquille, avec un rayon de 14. La gouttiere qui l entoure est peinte en
    /// `surface.window`, la barre elle meme en `surface.sidebar`.
    public enum BarreLaterale {
        /// Largeur deployee, fixe, non redimensionnable.
        public static let largeur: Double = 196
        /// Largeur repliee, icones seules.
        public static let largeurRepliee: Double = 56
        /// Marge d encastrement sur les quatre cotes.
        public static let margeDEncastrement = Espace.x3
        /// Rayon de la barre.
        public static let rayon = Rayon.barreLaterale
        /// Hauteur d une entree.
        public static let hauteurDeLigne: Double = 40
        /// Rayon d une entree.
        public static let rayonDeLigne = Rayon.bouton
        /// Distance entre le bord gauche de la barre et l icone.
        public static let decalageDIcone: Double = 14
        /// Taille de rendu de l icone.
        public static let tailleDIcone = Icone.tailleEnBarreLaterale
        /// Distance entre le bord gauche de la barre et le libelle.
        public static let decalageDeLibelle: Double = 40
        /// Marge entre le bord de la barre et une entree.
        ///
        /// Le document ne la chiffre pas directement. Le wireframe 01 pose la
        /// barre a 196 et ses entrees a 176, ce qui donne 10 de chaque cote.
        /// C est une geometrie de composant, pas un espacement de mise en page,
        /// elle echappe donc a l echelle de 4 de la section 1.7.
        public static let margeLateraleDeLigne: Double = 10
        /// Marge entre le haut de la barre et la premiere entree.
        public static let margeVerticale = Espace.x3
        /// Espace entre deux entrees.
        public static let espaceEntreLignes = Espace.x1
        /// Hauteur du bloc d appel premium cale en bas de la barre.
        public static let hauteurDuBlocPremium: Double = 52
        /// Rayon du bloc d appel premium.
        public static let rayonDuBlocPremium = Rayon.carte

        /// Libelle d une entree au repos.
        ///
        /// La section 2.2 fixe la taille a 14, la ou l echelle typographique de
        /// la section 1.5 place `body` a 15. La regle 0.1 du document tranche :
        /// le chiffre du texte est normatif, donc 14.
        public static let libelle = StyleTypographique(
            taille: 14,
            graisse: .normale,
            interlignage: 20,
            interlettrageEnEm: 0
        )

        /// Libelle de l entree active, en graisse 600.
        public static let libelleActif = StyleTypographique(
            taille: 14,
            graisse: .semiGrasse,
            interlignage: 20,
            interlettrageEnEm: 0
        )
    }

    /// Barre d outils, sections 2.1 et 5.1.
    public enum BarreDOutils {
        /// Hauteur, unifiee avec la barre de titre.
        public static let hauteur = Fenetre.hauteurDeBarreDeTitre
        /// Distance entre le bord de la fenetre et le titre de l ecran.
        public static let decalageDuTitre: Double = 172
        /// Hauteur d un bouton de barre d outils, section 4.6.
        public static let hauteurDeBouton: Double = 28
        /// Rayon d un bouton de barre d outils, section 4.6.
        public static let rayonDeBouton = Rayon.ongletActif
    }

    /// Zone de contenu, sections 2.3 et 2.5.
    public enum Contenu {
        /// Marge laterale du gabarit large, macOS et iPad.
        public static let margeLaterale = Espace.x6
        /// Marge laterale sur iPhone.
        public static let margeLateraleCompacte = Espace.x4
        /// Largeur au dela de laquelle le gabarit large se centre.
        public static let largeurMaximale: Double = 1600
        /// Largeur du gabarit colonne, contrainte stricte.
        public static let largeurDeColonne: Double = 580
    }

    /// Boutons, section 4.6.
    public enum Bouton {
        /// Hauteur d un bouton pose dans le contenu.
        public static let hauteurEnContenu: Double = 38
        /// Rayon d un bouton pose dans le contenu.
        public static let rayonEnContenu = Rayon.bouton
        /// Hauteur d un bouton de modale ou de feuille.
        public static let hauteurEnModale: Double = 34
        /// Rayon capsule d un bouton de modale ou de feuille.
        public static let rayonEnModale = Rayon.capsule
        /// Hauteur d un bouton d etat vide ou d etat d erreur.
        public static let hauteurEnEtat: Double = 32
        /// Rayon d un bouton d etat vide ou d etat d erreur.
        public static let rayonEnEtat = Rayon.champ
        /// Largeur du bouton d un etat vide, section 4.10.
        public static let largeurEnEtat: Double = 120
        /// Hauteur de l action principale sur iPhone.
        public static let hauteurAuDoigt: Double = 44
        /// Remplissage horizontal d un bouton a largeur libre.
        public static let remplissageHorizontal = Espace.x4
    }

    /// Etats de contenu, section 4.10.
    public enum EtatDeContenu {
        /// Taille du glyphe.
        public static let tailleDuGlyphe: Double = 52
        /// Epaisseur du trait du glyphe.
        public static let epaisseurDuTrait: Double = 3
        /// Largeur maximale du bloc centre.
        public static let largeurMaximale: Double = 420
        /// Ecart entre le glyphe et le titre.
        public static let ecartApresLeGlyphe = Espace.x5
        /// Ecart entre le titre et la phrase.
        public static let ecartApresLeTitre = Espace.x2
        /// Ecart entre la phrase et l action.
        public static let ecartAvantLAction = Espace.x6
    }

    /// Symboles de la coquille absents du tableau 1.10.
    public enum IconeDeCoquille {
        /// Bascule de repli de la barre laterale.
        ///
        /// Le tableau 1.10 ne liste que les icones des ecrans. La bascule de
        /// repli est une commande de coquille, et reprend le symbole que le
        /// systeme emploie pour la meme action.
        public static let replierLaBarreLaterale = "sidebar.leading"
    }

    /// Contour de focus clavier, section 7.
    ///
    /// Jamais supprime. La couleur vient du jeton `focusRing` de la palette.
    public enum Focus {
        /// Epaisseur du contour.
        public static let epaisseur: Double = 2
        /// Decalage du contour vers l exterieur de l element.
        public static let decalage: Double = 2
    }

    /// Cibles de pointage minimales, section 7.
    public enum Cible {
        /// Cible minimale au doigt, iOS et iPadOS.
        public static let auDoigt: Double = 44
        /// Cible minimale au pointeur, macOS.
        public static let auPointeur: Double = 28
    }
}
