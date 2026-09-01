//
// Mesures de la feuille de configuration d une source, section 5.3.
//

extension Jetons {
    /// Feuille de configuration d une source, section 5.3.
    public enum Configuration {
        /// Largeur de la feuille, celle du menu d ajout qui l ouvre.
        public static let largeur: Double = 324

        /// Marge interne de la feuille.
        public static let marge = Espace.x5

        /// Rayon de la feuille, section 1.6.
        public static let rayon = Rayon.feuille

        /// Titre de la feuille.
        public static let titre = Typo.headline

        /// Etiquette posee au dessus d un champ.
        public static let etiquette = Typo.footnote

        /// Resultat du test de connexion.
        public static let message = Typo.footnote
    }
}
