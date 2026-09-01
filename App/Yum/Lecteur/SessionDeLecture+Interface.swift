import Core
import DesignSystem
import Foundation
import ReaderEngine

//
// Ce que la vue du lecteur lit et declenche.
//
// La session tient l etat, cette extension expose le contrat que la vue
// consomme : ses commandes, ses libelles, et la traduction d un appui en
// intention de navigation.
//
// Les deux vivent a part parce que ce sont deux sujets. Ce qui decide quelle
// page s affiche n a pas a etre lu au milieu de ce que la vue en tire.
//

extension SessionDeLecture {
    var commandes: CommandesDeLecteur {
        CommandesDeLecteur(
            pageSuivante: { [weak self] in
                self?.deplacer(.pageSuivante)
            },
            pagePrecedente: { [weak self] in
                self?.deplacer(.pagePrecedente)
            },
            fermer: { [weak self] in
                self?.fermer()
            },
            appuyer: { [weak self] abscisse, ordonnee in
                self?.appuyer(abscisse: abscisse, ordonnee: ordonnee) ?? false
            }
        )
    }

    // MARK: Zones de toucher

    /// Traite un appui, et dit s il a tourne une page.
    ///
    /// Rend faux en defilement continu : le doigt y sert a faire glisser le
    /// ruban, et tourner une page sous un doigt qui defile serait un saut que
    /// personne n a demande.
    var libelles: LibellesDeLecteur {
        LibellesDeLecteur(
            titre: titre,
            sousTitre: sousTitre,
            fermer: Chaines.Lecteur.fermer,
            pagePrecedente: Chaines.Lecteur.pagePrecedente,
            pageSuivante: Chaines.Lecteur.pageSuivante
        )
    }
}
