import SwiftUI

//
// Texte dynamique, sections 4.1 et 7 de DESIGN-SPEC.md.
//
// La section 7 fixe la prise en charge jusqu a la taille accessibilite extra
// extra large, `accessibility4` cote systeme. La section 4.1 fixe le point de
// bascule des lignes de reglages : au dela de `large`, la ligne passe en
// disposition verticale.
//
// Les deux valeurs vivent ici, et non dans la vue qui les applique. La regle de
// bascule est une fonction pure, ce qui permet de la mesurer sans monter une
// vue, et de la reutiliser dans tout composant qui devra plus tard se replier
// pour la meme raison.
//

extension Jetons {
    /// Bornes du texte dynamique, section 7.
    public enum TexteDynamique {
        /// Plus grande taille prise en charge, accessibilite extra extra large.
        ///
        /// La coquille borne l environnement a cette taille. Au dela, le
        /// systeme continuerait d agrandir alors que les gabarits chiffres des
        /// sections 2 et 4 ne sont plus tenables, et des libelles seraient
        /// tronques sans que rien ne le signale.
        public static let tailleMaximale = DynamicTypeSize.accessibility4

        /// Derniere taille qui garde la disposition horizontale, section 4.1.
        public static let derniereTailleEnLigne = DynamicTypeSize.large

        /// Vrai quand la taille demandee impose la disposition verticale.
        public static func passeEnPile(_ taille: DynamicTypeSize) -> Bool {
            taille > derniereTailleEnLigne
        }
    }
}
