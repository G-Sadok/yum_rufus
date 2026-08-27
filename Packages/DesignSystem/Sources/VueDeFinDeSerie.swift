import SwiftUI

//
// Ecran de fin de serie, section 7.4 du cahier de developpement.
//
// Il ferme un enchainement, il ne signale pas un echec. La forme est donc celle
// de l etat vide de la section 4.10, glyphe puis titre puis phrase puis action,
// et non celle de l etat d erreur : aucun `warning`, aucun Reessayer, rien a
// reparer.
//
// Le bloc se pose sur le fond du lecteur, qu il ne peint pas. L utilisateur
// vient de lire deux mille pages sur ce fond, changer de surface au dernier
// ecran ferait un a coup pour rien.
//

/// Bloc affiche au bas du dernier chapitre d une serie.
public struct VueDeFinDeSerie: View {
    private let dernierChapitre: Double?
    private let libelles: LibellesDeFinDeSerie
    private let revenirALaFiche: () -> Void

    /// - Parameters:
    ///   - dernierChapitre: numero du dernier chapitre, nul quand la liste des
    ///     chapitres n a pas ete chargee.
    ///   - libelles: textes pris dans le catalogue de chaines.
    ///   - revenirALaFiche: sortie proposee, la fiche de la serie.
    public init(
        dernierChapitre: Double?,
        libelles: LibellesDeFinDeSerie,
        revenirALaFiche: @escaping () -> Void
    ) {
        self.dernierChapitre = dernierChapitre
        self.libelles = libelles
        self.revenirALaFiche = revenirALaFiche
    }

    public var body: some View {
        VueDEtatDeContenu(
            .vide(
                symbole: Jetons.Enchainement.glypheDeFinDeSerie,
                titre: libelles.titre,
                phrase: TexteDeFinDeSerie.phrase(dernierChapitre: dernierChapitre, libelles: libelles),
                action: ActionDEtat(libelle: libelles.revenirALaFiche, action: revenirALaFiche)
            )
        )
    }
}
