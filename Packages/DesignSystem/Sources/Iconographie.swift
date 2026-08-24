//
// Iconographie, section 1.10 de DESIGN-SPEC.md.
//
// SF Symbols exclusivement, graisse regular, echelle medium.
//

extension Jetons {
    /// Symboles et tailles de rendu, section 1.10.
    ///
    /// Chaque icone sans libelle porte une etiquette d accessibilite, prise
    /// dans le catalogue de chaines et jamais ecrite ici.
    public enum Icone {
        public static let bibliotheque = "books.vertical"
        public static let historique = "clock"
        public static let parcourir = "safari"
        public static let rechercher = "magnifyingglass"
        public static let reglages = "gearshape"
        public static let premium = "crown"
        public static let incognito = "eye.slash"
        public static let verrouillage = "lock"
        public static let sensDeLecture = "text.book.closed"
        public static let miseEnPage = "rectangle.split.2x1"
        public static let rognerLesBords = "crop"
        public static let luminosite = "sun.max"
        public static let chaleur = "thermometer.medium"
        public static let ameliorationIA = "wand.and.stars"
        public static let colorisationIA = "paintbrush"
        public static let telechargement = "arrow.down.circle"
        public static let sauvegarde = "externaldrive"
        public static let iCloud = "icloud"
        public static let aide = "questionmark.circle"
        public static let signalerUnBug = "ladybug"
        public static let erreurDeContenu = "exclamationmark.circle"

        /// Taille de rendu dans une ligne de reglages.
        public static let tailleEnLigneDeReglage: Double = 22
        /// Taille de rendu dans la barre laterale.
        public static let tailleEnBarreLaterale: Double = 20
        /// Taille de rendu dans une barre d outils.
        public static let tailleEnBarreDOutils: Double = 18
        /// Taille de rendu dans un menu.
        public static let tailleEnMenu: Double = 16

        /// Symboles indexes par le nom d element du tableau 1.10.
        public static let parElement: [String: String] = [
            "Bibliotheque": bibliotheque,
            "Historique": historique,
            "Parcourir": parcourir,
            "Rechercher": rechercher,
            "Reglages": reglages,
            "Premium": premium,
            "Incognito": incognito,
            "Verrouillage": verrouillage,
            "Sens de lecture": sensDeLecture,
            "Mise en page": miseEnPage,
            "Rogner les bords": rognerLesBords,
            "Luminosite": luminosite,
            "Chaleur": chaleur,
            "Amelioration IA": ameliorationIA,
            "Colorisation IA": colorisationIA,
            "Telechargement": telechargement,
            "Sauvegarde": sauvegarde,
            "iCloud": iCloud,
            "Aide": aide,
            "Signaler un bug": signalerUnBug,
            "Erreur de contenu": erreurDeContenu,
        ]
    }
}
