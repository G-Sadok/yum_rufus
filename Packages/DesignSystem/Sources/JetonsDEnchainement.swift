//
// Enchainement de chapitres, section 5.8 de DESIGN-SPEC.md.
//
// Le document donne une seule ligne pour le separateur de chapitre : filet de
// 1 px a 30 pour cent d opacite, numero du chapitre entrant en `footnote`
// `text.tertiary`, marges verticales de 32. Ces quatre valeurs sont ici, et la
// hauteur totale de l intercalaire s en deduit plutot que d etre ecrite une
// seconde fois : c est elle que le moteur de lecture recoit pour poser sa
// geometrie, et deux ecritures de la meme hauteur finiraient par diverger.
//
// L ecran de fin de serie n est pas dessine par le document. Il reprend donc
// l etat vide de la section 4.10 sans rien inventer : meme glyphe de 52, meme
// `title1`, meme phrase en `callout`, meme bouton d etat. La section 0.1
// reserve le wireframe a ce que le texte ne fixe pas, et aucun des deux ne
// dessine cet ecran.
//

extension Jetons {
    /// Enchainement automatique des chapitres, section 5.8.
    public enum Enchainement {
        /// Epaisseur du filet qui separe deux chapitres.
        public static let epaisseurDuFilet: Double = 1

        /// Opacite du filet, la seule du produit a 30 pour cent.
        public static let opaciteDuFilet: Double = 0.3

        /// Marge verticale posee de part et d autre du numero.
        public static let margeVerticale = Espace.x7

        /// Style du numero du chapitre entrant.
        public static let numero = Typo.footnote

        /// Hauteur totale de l intercalaire, telle que le moteur la recoit.
        ///
        /// Les deux marges encadrent la ligne du numero, et le filet se pose
        /// dans la marge haute sans rien ajouter a la hauteur. C est cette
        /// valeur que `RubanDeChapitres` intercale entre deux chapitres : la
        /// hauteur est une donnee de la vue, la geometrie appartient au moteur.
        public static let hauteurDeLIntercalaire = 2 * margeVerticale + numero.interlignage

        /// Glyphe de l ecran de fin de serie.
        ///
        /// Le document ne le nomme pas. Le livre ferme est le seul glyphe du
        /// systeme qui dise une fin sans dire un echec, la ou la coche dirait
        /// une tache accomplie et le cercle barre une erreur.
        public static let glypheDeFinDeSerie = "book.closed"
    }
}
