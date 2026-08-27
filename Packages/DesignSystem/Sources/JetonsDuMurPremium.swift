//
// Mur premium, section 5.9 de DESIGN-SPEC.md.
//
// La feuille porte deux couleurs qui ne figurent dans aucune table de jetons de
// la section 1 : son fond et son contour. Elles sont chiffrees par la section 5.9
// elle meme, comme les quatre fonds du lecteur le sont par la section 1.4, et
// vivent donc ici, avec la mention de la ligne qui les impose. C est la seule
// facon de tenir la regle : une valeur visuelle existe dans DesignSystem, ou elle
// n existe pas.
//
// Elles ne varient pas avec l apparence, pour la meme raison que les fonds du
// lecteur : le document ne donne qu une valeur, et en inventer une seconde pour
// la variante claire reviendrait a decider a la place du design.
//

extension Jetons {
    /// Feuille du mur premium, section 5.9.
    public enum MurPremium {
        /// Largeur de la feuille.
        public static let largeur: Double = 360

        /// Hauteur du cas de reference, cinq avantages et un bouton.
        public static let hauteurDeReference: Double = 420

        /// Rayon de la feuille.
        public static let rayon = Rayon.feuille

        /// Fond de la feuille, chiffre par la section 5.9.
        public static let fond = CouleurHexadecimale(0x141A28)

        /// Contour de la feuille, chiffre par la section 5.9.
        public static let contour = CouleurHexadecimale(0x24344F)

        /// Epaisseur du contour.
        public static let epaisseurDuContour = Fenetre.epaisseurDuFilet

        /// Elevation de la feuille, sur voile.
        public static let elevation = NiveauDElevation.modal

        /// Symbole de la couronne, tableau 1.10.
        public static let couronne = Icone.premium

        /// Largeur de la couronne.
        public static let largeurDeLaCouronne: Double = 56

        /// Hauteur de la couronne, qui vaut sa taille de rendu.
        public static let hauteurDeLaCouronne: Double = 40

        /// Titre `Premium`, seul role de texte a 20 du produit.
        ///
        /// La section 5.9 chiffre 20 en graisse 700, la ou l echelle de la
        /// section 1.5 place `title1` a 22 et `title2` a 17. La regle 0.1
        /// tranche, le chiffre du texte est normatif, et le role emprunte
        /// l interlignage et l interlettrage du cran voisin de l echelle,
        /// exactement comme le titre de modale de la section 4.8.
        public static let titre = StyleTypographique(
            taille: 20,
            graisse: .grasse,
            interlignage: 28,
            interlettrageEnEm: -0.01
        )

        /// Sous titre pose sous le titre.
        public static let sousTitre = Typo.footnote

        /// Ligne d avantage.
        public static let avantage = Typo.callout

        /// Taille de rendu de la coche d un avantage.
        public static let tailleDeLaCoche: Double = 14

        /// Symbole de la coche d un avantage.
        public static let coche = "checkmark"

        /// Gouttiere entre la coche et son libelle.
        public static let gouttiereApresLaCoche = Espace.x3

        /// Interligne entre deux avantages.
        ///
        /// La section 5.9 ecrit 14, valeur de composant et non d espacement de
        /// mise en page, elle echappe donc a l echelle de la section 1.7 comme
        /// la marge des entrees de la barre laterale.
        public static let interligneDesAvantages: Double = 14

        /// Largeur du bouton principal.
        public static let largeurDuBouton: Double = 296

        /// Hauteur du bouton principal, tableau des contextes de la section 4.6.
        public static let hauteurDuBouton: Double = 42

        /// Rayon du bouton principal.
        public static let rayonDuBouton = Rayon.carte

        /// Mention de prix posee sous le bouton.
        public static let mentionDePrix = Typo.caption

        /// Marge interieure de la feuille.
        public static let marge = Espace.x6

        /// Ecart entre la couronne et le titre.
        public static let ecartApresLaCouronne = Espace.x4

        /// Ecart entre le titre et le sous titre.
        public static let ecartApresLeTitre = Espace.x2

        /// Ecart entre le sous titre et la liste des avantages.
        public static let ecartAvantLesAvantages = Espace.x6

        /// Ecart entre la liste des avantages et le bouton.
        public static let ecartAvantLeBouton = Espace.x6

        /// Ecart entre le bouton et la mention de prix.
        public static let ecartApresLeBouton = Espace.x3

        /// Ecart entre la mention de prix et les commandes de pied.
        public static let ecartAvantLePied = Espace.x4

        /// Ecart entre les deux commandes de pied.
        public static let ecartEntreLesCommandesDePied = Espace.x4

        /// Hauteur des capsules de l etat d erreur, section 4.6.
        public static let hauteurDeCapsule = Bouton.hauteurEnModale

        /// Rayon des capsules de l etat d erreur.
        public static let rayonDeCapsule = Bouton.rayonEnModale

        /// Largeur d une capsule de l etat d erreur.
        ///
        /// La feuille est plus etroite qu une modale courte, ses deux capsules
        /// se partagent donc la largeur du bouton principal plutot que de
        /// reprendre les 150 de la section 4.8.
        public static let largeurDeCapsule = (largeurDuBouton - Espace.x4) / 2

        /// Hauteur du bloc de squelettes des etats vide et chargement.
        ///
        /// La section 5.9 demande la meme feuille en squelettes. Le bloc prend
        /// donc la hauteur du contenu attendu, marges retirees.
        public static let hauteurDesSquelettes = hauteurDeReference - marge * 2
    }
}
