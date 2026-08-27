//
// Jetons de la confidentialite : banniere du mode incognito et ecran de
// verrouillage, section 11 du cahier de developpement.
//
// DESIGN-SPEC.md ne dessine ni l une ni l autre. Il ne nomme que leurs deux
// glyphes, au tableau 1.10, `eye.slash` et `lock`. Aucune valeur nouvelle n est
// donc inventee ici : tout est repris de jetons deja poses ailleurs, comme
// l impose la regle 4 de la section 0, composer avant de creer.
//
// La banniere emprunte son gabarit a la seule banniere que le document dessine,
// celle de la section 5.5 : meme rayon, meme epaisseur de contour, meme role de
// texte pour le titre et pour la phrase. Une seconde forme de banniere dans un
// produit dont la these veut que l interface disparaisse en ferait une de trop.
//
// Une difference, et elle est voulue. La banniere de reactivation annonce une
// panne d abonnement et porte donc un contour `warning`. Le mode incognito n est
// pas une panne, c est un etat que l utilisateur a choisi et qu il peut arreter
// quand il veut. Son contour est `border`, celui de tous les contenants neutres
// du produit. La section 3 interdit d ailleurs toute couleur saturee dans le
// champ de vision pendant la lecture, et cette banniere y reste toute la session.
//

extension Jetons {
    /// Banniere permanente du mode incognito, section 11.
    public enum BanniereDIncognito {
        /// Rayon, celui de la banniere de la section 5.5.
        public static let rayon = Rayon.carte
        /// Epaisseur du contour, celle de la banniere de la section 5.5.
        public static let epaisseurDuContour: Double = 1
        /// Titre, meme role de texte que la banniere de la section 5.5.
        public static let titre = Typo.headline
        /// Phrase, meme role de texte que la banniere de la section 5.5.
        public static let phrase = Typo.footnote
        /// Remplissage interne.
        ///
        /// Plus serre que la banniere des reglages, qui est un bloc de colonne.
        /// Celle ci reste a l ecran toute la session, jusque sur une page de
        /// manga : elle occupe le moins de hauteur possible.
        public static let remplissage = Espace.x3
        /// Ecart entre le glyphe, le titre et la phrase.
        public static let ecartInterne = Espace.x2
        /// Marge autour de la banniere, celle du contenu.
        public static let marge = Espace.x4
        /// Taille de rendu du glyphe, celle des barres d outils.
        public static let tailleDuGlyphe = Icone.tailleEnBarreDOutils
    }

    /// Ecran de verrouillage de l application, section 11.
    public enum EcranDeVerrouillage {
        /// Symbole du verrou, tableau 1.10.
        public static let glyphe = Icone.verrouillage
        /// Glyphe de l echec, celui de l etat d erreur de la section 4.10.
        public static let glypheDEchec = Icone.erreurDeContenu
    }
}
