//
// Mesures du lecteur pagine, section 5.7.
//
// Les barres se retirent apres trois secondes et reviennent au tap central.
// Leur fond n est pas opaque : la planche continue de se deviner derriere,
// ce qui rappelle qu elles sont posees dessus et non a cote.
//

extension Jetons {
    /// Lecteur pagine, section 5.7.
    public enum Lecteur {
        /// Hauteur de la barre superieure.
        public static let hauteurDeLaBarreSuperieure: Double = 72

        /// Hauteur de la barre inferieure.
        public static let hauteurDeLaBarreInferieure: Double = 64

        /// Opacite du fond des deux barres, `surface.window` a 94 pour cent.
        public static let opaciteDesBarres: Double = 0.94

        /// Chevron de retour, 12 par 20 dans le document.
        public static let tailleDuChevron: Double = 20

        /// Distance du compteur au bord gauche.
        public static let margeDuCompteur: Double = 40

        /// Duree de la transition des barres, 200 ms.
        public static let dureeDeTransition: Double = 0.2

        /// Distance minimale d un balayage avant qu il tourne la page.
        ///
        /// Assez longue pour qu un doigt pose et retire ne tourne rien, assez
        /// courte pour qu un geste franc reponde du premier coup.
        public static let distanceDeBalayage: Double = 24

        /// Titre de la serie, `body` en graisse 600 comme le document l ecrit.
        public static let titre = StyleTypographique(
            taille: Typo.body.taille,
            graisse: .semiGrasse,
            interlignage: Typo.body.interlignage,
            interlettrageEnEm: Typo.body.interlettrageEnEm
        )

        /// Chapitre, en `footnote`.
        public static let sousTitre = Typo.footnote

        /// Compteur de pages, en `callout`, chiffres tabulaires.
        public static let compteur = Typo.callout
    }
}
