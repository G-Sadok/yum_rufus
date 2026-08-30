//
// Ecran Rechercher, section 5.4 de DESIGN-SPEC.md.
//
// Le tableau de la section chiffre la rangee d une source : les trois roles de
// texte de son en tete, la vignette, la gouttiere entre deux vignettes et
// l espacement entre deux groupes. La phrase qui suit le tableau chiffre la
// ligne d erreur qui prend la place d une source muette.
//
// Deux valeurs sortent de l echelle de la section 1.7, et c est le document qui
// le veut. L espacement entre deux groupes vaut 28, la gouttiere entre la
// vignette et son titre vaut 10 dans le tableau de la section 4.3. La regle 0.1
// tranche : le texte du cahier des charges est normatif pour toute valeur
// chiffree. Elles sont donc reprises telles quelles, et nommees ici pour que
// personne n aille les reecrire en clair dans une vue.
//

extension Jetons {
    /// Ecran Rechercher, section 5.4.
    public enum Recherche {
        /// Largeur du champ de la barre d outils, sur macOS et sur iPad.
        public static let largeurDuChamp: Double = 440
        /// Hauteur du champ, comme toute commande de barre d outils.
        public static let hauteurDuChamp = BarreDOutils.hauteurDeBouton
        /// Rayon du champ de saisie, section 1.6.
        public static let rayonDuChamp = Rayon.champ
        /// Remplissage horizontal du champ, de part et d autre du texte.
        public static let remplissageDuChamp = Espace.x2
        /// Ecart entre la loupe et le texte saisi.
        public static let ecartDansLeChamp = Espace.x2
        /// Taille de rendu de la loupe et du bouton d effacement.
        public static let tailleDesSymbolesDuChamp = Icone.tailleEnMenu

        /// Nom de la source, en tete de sa rangee.
        public static let nomDeSource = Typo.headline
        /// Compteur de resultats, a cote du nom.
        public static let compteurDeResultats = Typo.footnote
        /// Lien Tout voir, aligne a droite de l en tete.
        public static let lienToutVoir = Typo.callout

        /// Largeur d une vignette de resultat.
        public static let largeurDeVignette: Double = 132
        /// Hauteur d une vignette de resultat, ratio 2:3.
        public static let hauteurDeVignette: Double = 198
        /// Rayon d une vignette, comme toute couverture de carte, section 4.3.
        public static let rayonDeVignette = Rayon.bouton
        /// Gouttiere entre deux vignettes d une meme rangee.
        public static let gouttiereEntreVignettes = Espace.x4
        /// Espacement entre deux groupes de sources.
        ///
        /// Le seul espacement du produit hors de l echelle de la section 1.7,
        /// impose par le tableau de la section 5.4. Voir l en tete de fichier.
        public static let ecartEntreGroupes: Double = 28
        /// Gouttiere entre la vignette et le titre, tableau de la section 4.3.
        public static let gouttiereApresLaVignette: Double = 10
        /// Ecart entre l en tete d une rangee et ses vignettes.
        public static let ecartApresLEnTete = Espace.x3
        /// Ecart entre le nom de la source et son compteur.
        ///
        /// La section 5.4 ne le chiffre pas. Il reprend celui du compteur de la
        /// barre de categories, seule autre paire libelle et compteur du
        /// produit, plutot que d en inventer un second.
        public static let ecartAvantLeCompteur = BarreDeCategories.ecartDuCompteur

        /// Titre d un resultat, sous sa vignette, tableau de la section 4.3.
        public static let titreDeResultat = Typo.callout.enGraisse(.semiGrasse)
        /// Nombre de lignes du titre, tableau de la section 4.3.
        public static let lignesDeTitre = 2

        /// Hauteur reservee au titre, deux interlignes de son role de texte.
        ///
        /// Elle n existe que pour le squelette, qui doit occuper les dimensions
        /// exactes du contenu attendu sans connaitre le texte a venir.
        public static let hauteurDuTitreDeResultat = titreDeResultat.interlignage
            * Double(lignesDeTitre)

        /// Hauteur de la ligne d erreur qui remplace une rangee.
        public static let hauteurDeLigneDErreur: Double = 52
        /// Rayon de la ligne d erreur.
        public static let rayonDeLigneDErreur = Rayon.carte
        /// Marge laterale interne de la ligne d erreur, comme une ligne de
        /// source de la section 4.4.
        public static let margeDeLigneDErreur = Espace.x4
        /// Ecart entre le glyphe d avertissement et le texte de la ligne.
        public static let ecartDansLaLigneDErreur = Espace.x3
        /// Taille de rendu du glyphe d avertissement de la ligne d erreur.
        public static let tailleDuGlypheDErreur = Icone.tailleEnBarreDOutils
        /// Texte de la ligne d erreur, qui nomme la source et le delai.
        public static let texteDeLigneDErreur = Typo.footnote

        /// Nombre de vignettes en squelette pendant qu une source repond.
        ///
        /// Le document ne le chiffre pas. Cinq vignettes de 132 plus leurs
        /// gouttieres occupent la largeur utile d une fenetre de reference sans
        /// promettre un nombre de resultats que la source n a pas rendu.
        public static let nombreDeSquelettesParRangee = 5

        /// Nombre de rangees en squelette avant la premiere reponse.
        public static let nombreDeRangeesEnSquelette = 2
    }

    /// Symboles de l ecran Rechercher absents du tableau 1.10.
    ///
    /// Le tableau nomme la loupe et le glyphe d erreur de contenu, qui servent
    /// ici tels quels. Les deux commandes ci dessous ne sont pas dessinees par
    /// le document, elles reprennent le symbole que le systeme emploie pour la
    /// meme action.
    public enum IconeDeRecherche {
        /// Bouton qui vide le champ de recherche.
        public static let effacerLeChamp = "xmark.circle.fill"

        /// Retour depuis la liste complete d une source vers les rangees.
        ///
        /// La variante directionnelle et non `chevron.left` : elle se retourne
        /// d elle meme dans une interface de droite a gauche, section 13 du
        /// cahier de developpement.
        public static let retour = "chevron.backward"
    }
}
