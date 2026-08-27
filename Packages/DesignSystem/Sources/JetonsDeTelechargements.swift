//
// File de telechargement, section 4.11 de DESIGN-SPEC.md.
//
// Le document chiffre tout ce qui est propre a ce composant : la largeur du
// panneau, la ligne, l indicateur, ses deux epaisseurs d anneau et son motif de
// tirets, et les deux roles de texte. Ils sont repris tels quels.
//
// Ce qu il ne chiffre pas, ecarts et marges, sort de l echelle de la section
// 1.7. Aucun ajustement optique n est invente ici.
//

extension Jetons {
    /// File de telechargement, section 4.11.
    public enum Telechargements {
        /// Largeur du panneau qui porte la file.
        public static let largeurDuPanneau: Double = 324

        /// Largeur d une ligne.
        public static let largeurDeLigne: Double = 268

        /// Hauteur d une ligne.
        public static let hauteurDeLigne: Double = 52

        /// Rayon d une ligne.
        ///
        /// Le document chiffre 10, qui est aussi le rayon de toute ligne
        /// cliquable du produit, section 1.6.
        public static let rayonDeLigne = Rayon.bouton

        /// Retrait lateral d une ligne dans le panneau.
        ///
        /// Deduit des deux largeurs du document, non invente : le panneau fait
        /// 324, la ligne 268, il reste 56 a partager de part et d autre.
        public static let retraitDeLigne = (largeurDuPanneau - largeurDeLigne) / 2

        /// Diametre de l indicateur d etat.
        public static let diametreDeLIndicateur: Double = 24

        /// Distance du bord gauche au centre de l indicateur.
        public static let centreDeLIndicateur: Double = 26

        /// Marge a gauche de l indicateur, pour que son centre tombe a 26.
        public static let margeAvantLIndicateur = centreDeLIndicateur - diametreDeLIndicateur / 2

        /// Epaisseur de l anneau d une tache en cours.
        public static let epaisseurEnCours: Double = 2.5

        /// Epaisseur de l anneau d une tache en attente.
        public static let epaisseurEnAttente: Double = 2

        /// Longueur d un tiret de l anneau en cours.
        public static let tiret: Double = 50

        /// Longueur d un vide entre deux tirets de l anneau en cours.
        public static let videEntreTirets: Double = 25

        /// Titre d une ligne.
        public static let titre = Typo.callout

        /// Sous ligne, qui porte l avancement ou l etat.
        public static let sousLigne = Typo.caption

        /// Ecart entre l indicateur et les textes.
        public static let ecartApresLIndicateur = Espace.x3

        /// Ecart entre le titre et la sous ligne.
        public static let ecartEntreLesTextes = Espace.x1

        /// Ecart entre les textes et le bouton de commande.
        public static let ecartAvantLaCommande = Espace.x2

        /// Ecart entre deux lignes de la file.
        public static let ecartEntreLignes = Espace.x1

        /// Marge interieure du panneau, en haut et en bas.
        public static let margeVerticale = Espace.x5

        /// Cote de la cible du bouton de commande d une ligne.
        public static let coteDeLaCommande = Cible.auDoigt

        /// Taille de rendu des symboles de commande.
        public static let tailleDuSymbole = Icone.tailleEnBarreDOutils

        /// Nombre de squelettes affiches pendant le chargement.
        ///
        /// Le document ne le chiffre pas. Trois lignes disent qu une file arrive
        /// sans promettre une longueur que la base n a pas encore rendue.
        public static let nombreDeSquelettes = 3

        /// Base de conversion des poids affiches.
        ///
        /// Mille et non mille vingt quatre. Le document ecrit `32 Mo`, unite du
        /// systeme international, qui est aussi celle que le Finder affiche.
        public static let baseDesPoids = 1000
    }

    /// Symboles de la file de telechargement.
    ///
    /// Le tableau 1.10 nomme l icone de telechargement. Les deux commandes de
    /// ligne de la section 4.11, pause et reprise, n y figurent pas et
    /// reprennent le symbole que le systeme emploie pour les memes actions.
    public enum IconeDeTelechargement {
        /// Icone de la section, tableau 1.10.
        public static let telechargement = "arrow.down.circle"

        /// Mise en pause d une ligne.
        public static let pause = "pause.circle"

        /// Reprise d une ligne.
        public static let reprendre = "play.circle"

        /// Menu des commandes d une ligne.
        public static let options = "ellipsis.circle"
    }
}
