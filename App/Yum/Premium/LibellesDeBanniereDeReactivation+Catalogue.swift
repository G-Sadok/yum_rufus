import DesignSystem

//
// Libelles de la banniere de reactivation, pris dans le catalogue de chaines.
//
// Meme role que `LibellesDuMurPremium.duCatalogue` : le paquet DesignSystem
// sait quel libelle va ou, l application sait lequel c est.
//

extension LibellesDeBanniereDeReactivation {
    /// Textes de la banniere de reactivation.
    static var duCatalogue: LibellesDeBanniereDeReactivation {
        LibellesDeBanniereDeReactivation(
            titre: Chaines.BanniereDeReactivation.titre,
            phraseApresExpiration: Chaines.BanniereDeReactivation.apresExpiration,
            phraseSansAbonnement: Chaines.BanniereDeReactivation.sansAbonnement,
            passerAPremium: Chaines.BanniereDeReactivation.passerAPremium
        )
    }
}
