import Core

//
// Parcours de premiere ouverture, section 5.10 de DESIGN-SPEC.md.
//
// Le document chiffre quatre choses et quatre seulement : le diametre des
// points de progression, la largeur des deux cartes de sens de lecture,
// l epaisseur du contour de la carte active, et la hauteur d une ligne de
// source. Tout le reste est emprunte a une table de jetons existante, et chaque
// emprunt porte la raison qui le justifie.
//
// Les deux boutons de la troisieme etape partagent un seul gabarit, et c est le
// point le plus important de ce fichier. La section 5.10 exige que Plus tard
// soit aussi visible que le bouton d essai, meme hauteur et meme rayon. Deux
// jeux de mesures separes finiraient par diverger a la premiere retouche, ici
// les deux boutons lisent la meme mesure ou aucun ne la lit.
//

extension Jetons {
    /// Parcours de premiere ouverture, section 5.10.
    public enum PremiereOuverture {
        /// Diametre d un point de progression, section 5.10.
        public static let diametreDuPoint: Double = 7

        /// Ecart entre deux points de progression.
        public static let ecartEntreLesPoints = Espace.x2

        /// Opacite d un point que le parcours n a pas encore atteint.
        ///
        /// La section 5.10 ne donne que l etat actif, en `accent`. Le point
        /// inactif reprend l opacite basse deja employee par les squelettes,
        /// plutot qu une couleur de plus.
        public static let opaciteDuPointInactif = Mouvement.opaciteBasseDeSquelette

        /// Largeur d une carte de sens de lecture, section 5.10.
        public static let largeurDeCarte: Double = 300

        /// Hauteur d une carte de sens de lecture.
        ///
        /// Le document ne la chiffre pas. Elle vaut la hauteur de la couverture
        /// de la fiche de serie, parce que l apercu montre exactement le meme
        /// objet, deux pages posees cote a cote.
        public static let hauteurDeCarte: Double = 278

        /// Rayon d une carte de sens de lecture, section 5.10.
        public static let rayonDeCarte = Rayon.feuille

        /// Epaisseur du contour de la carte choisie, section 5.10.
        public static let epaisseurDuContourActif: Double = 3

        /// Ecart entre les deux cartes.
        public static let ecartEntreLesCartes = Espace.x6

        /// Gouttiere entre les deux pages de l apercu d une carte.
        ///
        /// Celle de la double page de la section 5.7, puisque l apercu montre
        /// une double page.
        public static let gouttiereDeLApercu: Double = 4

        /// Rayon d une page de l apercu.
        public static let rayonDeLApercu = Rayon.bouton

        /// Numero de page pose sur l apercu.
        public static let numeroDePage = Typo.title2

        /// Hauteur d une ligne de source de la deuxieme etape, section 5.10.
        public static let hauteurDeLigneDeSource: Double = 72

        /// Rayon d une ligne de source.
        public static let rayonDeLigneDeSource = Rayon.carte

        /// Marge laterale interne d une ligne de source.
        public static let margeDeLigneDeSource = Espace.x4

        /// Taille de rendu du symbole d une ligne de source.
        public static let tailleDuSymboleDeSource = Icone.tailleEnLigneDeReglage

        /// Ecart entre le symbole et le libelle d une ligne de source.
        public static let ecartApresLeSymbole = Espace.x4

        /// Ecart entre deux lignes de source.
        public static let ecartEntreLesLignesDeSource = Espace.x3

        /// Libelle d une ligne de source.
        public static let libelleDeSource = Typo.body

        /// Sous ligne d etat d une ligne de source.
        public static let etatDeSource = Typo.footnote

        /// Titre d une etape.
        ///
        /// Le role de titre d ecran de la section 1.5, celui qu emploie deja
        /// tout etat de contenu de la section 4.10.
        public static let titre = Typo.title1

        /// Phrase posee sous le titre d une etape.
        public static let phrase = Typo.callout

        /// Mention legale posee a la deuxieme etape, tableau 6.8.
        public static let mention = Typo.footnote

        /// Ecart entre le titre et sa phrase.
        public static let ecartApresLeTitre = Espace.x2

        /// Ecart entre l en tete et le corps d une etape.
        public static let ecartAvantLeCorps = Espace.x7

        /// Ecart entre le corps et les commandes.
        public static let ecartAvantLesCommandes = Espace.x7

        /// Marge autour du contenu du parcours.
        public static let marge = Espace.x8

        /// Largeur maximale du contenu, deux cartes et leur ecart.
        public static let largeurDuContenu = largeurDeCarte * 2 + ecartEntreLesCartes

        /// Hauteur d une commande du parcours.
        ///
        /// Les trois mesures qui suivent venaient du bouton du mur premium,
        /// section 4.6, quand le parcours portait une troisieme etape d essai.
        /// Le mur a disparu avec l abonnement, les valeurs restent : elles
        /// mesuraient les commandes du parcours, pas l offre.
        public static let hauteurDuBouton: Double = 42

        /// Rayon d une commande du parcours.
        public static let rayonDuBouton = Rayon.carte

        /// Ecart entre deux commandes posees cote a cote.
        public static let ecartEntreLesBoutons = Espace.x4

        /// Largeur d une commande posee seule, comme Continuer ou Passer.
        public static let largeurDeCommandeSeule: Double = 296

        /// Symbole pose a gauche d une ligne de source.
        ///
        /// Le tableau 1.10 ne nomme aucune icone de source. Les trois lignes de
        /// la section 5.10 reprennent le symbole que le systeme emploie pour la
        /// meme notion, un dossier, un serveur et un catalogue, comme les
        /// lignes de reglages le font deja. Une source non mise en avant
        /// retombe sur le symbole de l ecran Parcourir, qui est l endroit d ou
        /// elle viendra.
        public static func symbole(de source: TypeDeSource) -> String {
            switch source {
            case .fichiersLocaux: "folder"
            case .komga: "server.rack"
            case .opds: "books.vertical"
            default: Icone.parcourir
            }
        }

        /// Gabarit d une commande du parcours.
        ///
        /// Les deux commandes rendent le meme gabarit, mesure pour mesure.
        public static func gabarit(de commande: CommandeDePremiereOuverture) -> GabaritDeCommande {
            switch commande {
            case .continuer, .passer:
                GabaritDeCommande(
                    hauteur: hauteurDuBouton,
                    rayon: rayonDuBouton,
                    largeur: largeurDeCommandeSeule
                )
            }
        }
    }
}

/// Mesures d une commande du parcours de premiere ouverture.
///
/// Sorti de la vue pour rester verifiable. Deux commandes de meme gabarit
/// pesent le meme poids a l ecran, quelle que soit la variante de bouton qui
/// les habille.
public struct GabaritDeCommande: Sendable, Equatable {
    /// Hauteur du bouton.
    public let hauteur: Double

    /// Rayon du bouton.
    public let rayon: Double

    /// Largeur du bouton.
    public let largeur: Double

    public init(hauteur: Double, rayon: Double, largeur: Double) {
        self.hauteur = hauteur
        self.rayon = rayon
        self.largeur = largeur
    }
}
