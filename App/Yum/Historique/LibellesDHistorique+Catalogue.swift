import DesignSystem

//
// Libelles de l historique, pris dans le catalogue de chaines.
//
// Meme role que `LibellesDeFicheDeSerie.duCatalogue` : le paquet DesignSystem
// sait quel libelle va ou, l application sait lequel c est.
//

extension LibellesDHistorique {
    /// Libelles de l ecran Historique, sections 5.2, 6.3, 6.4 et 6.5.
    static var duCatalogue: LibellesDHistorique {
        LibellesDHistorique(
            chapitreNumerote: Chaines.Chapitre.numerote,
            aujourdHui: Chaines.Historique.aujourdHui,
            hier: Chaines.Historique.hier,
            supprimerLEntree: Chaines.Historique.supprimerLEntree,
            effacerLHistorique: Chaines.Historique.effacer,
            confirmationTitre: Chaines.Historique.confirmationTitre,
            confirmationDescription: Chaines.Historique.confirmationDescription,
            confirmationAnnuler: Chaines.Historique.confirmationAnnuler,
            confirmationEffacer: Chaines.Historique.confirmationEffacer
        )
    }
}
