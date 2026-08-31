import DesignSystem
import Foundation

//
// Meme role que les autres ponts de catalogue.
//

extension LibellesDeBibliotheque {
    /// Libelles tels que le catalogue de l application les porte.
    static var duCatalogue: LibellesDeBibliotheque {
        LibellesDeBibliotheque(
            videTitre: Chaines.EtatVide.bibliothequeTitre,
            videPhrase: Chaines.EtatVide.bibliothequePhrase,
            ajouterUneSource: Chaines.EtatVide.bibliothequeAction
        )
    }
}
