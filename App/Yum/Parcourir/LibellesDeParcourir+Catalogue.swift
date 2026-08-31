import Core
import DesignSystem
import Foundation

//
// Meme role que les autres ponts de catalogue.
//
// Les douze entrees du menu tirent leur libelle du catalogue quand il en porte
// un, et du document sinon. Le document fait donc office de repli : une entree
// ajoutee au modele s affiche des le premier jour, en francais du document,
// plutot que de montrer sa cle a l ecran.
//

extension LibellesDeParcourir {
    /// Libelles tels que le catalogue de l application les porte.
    static var duCatalogue: LibellesDeParcourir {
        LibellesDeParcourir(
            ajouter: Chaines.Parcourir.ajouter,
            compteur: Chaines.Parcourir.compteur,
            videTitre: Chaines.EtatVide.parcourirTitre,
            videPhrase: Chaines.EtatVide.parcourirPhrase,
            entreesDuMenu: Dictionary(
                uniqueKeysWithValues: MenuDAjoutDeSource.entrees.map {
                    ($0.type, libelle(de: $0))
                }
            )
        )
    }

    /// Libelle d une entree, celui du document quand le catalogue est muet.
    private static func libelle(de entree: EntreeDuMenuDAjout) -> String {
        let cle = "parcourir.menu.\(entree.type.rawValue)"
        let traduit = String(localized: String.LocalizationValue(cle))

        return traduit == cle ? entree.nomDuDocument : traduit
    }
}
