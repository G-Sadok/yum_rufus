import Core
import DesignSystem
import Foundation

//
// Meme role que les autres ponts de catalogue.
//
// Le titre de la feuille reprend le libelle de l entree qui l a ouverte. Un
// titre generique obligerait l utilisateur a se souvenir de ce qu il a clique.
//

extension LibellesDeConfiguration {
    /// Libelles de la feuille, pour le type de source choisi.
    static func duCatalogue(pour type: TypeDeSource) -> LibellesDeConfiguration {
        LibellesDeConfiguration(
            titre: titre(de: type),
            adresse: Chaines.Configuration.adresse,
            compte: Chaines.Configuration.compte,
            motDePasse: Chaines.Configuration.motDePasse,
            tester: Chaines.Configuration.tester,
            enregistrer: Chaines.Configuration.enregistrer,
            annuler: Chaines.Configuration.annuler,
            reussite: Chaines.Configuration.reussite
        )
    }

    /// Titre repris de l entree du menu, celui que l utilisateur vient de lire.
    private static func titre(de type: TypeDeSource) -> String {
        LibellesDeParcourir.duCatalogue.entreesDuMenu[type] ?? type.rawValue
    }
}
