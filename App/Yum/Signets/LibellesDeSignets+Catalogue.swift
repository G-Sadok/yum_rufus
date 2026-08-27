import DesignSystem

//
// Libelles de l ecran Signets, pris dans le catalogue de chaines.
//
// Meme role que `LibellesDePrereglages.duCatalogue` : le paquet DesignSystem
// sait quel libelle va ou, l application sait lequel c est.
//

extension LibellesDeSignets {
    /// Textes de l ecran de consultation des signets.
    static var duCatalogue: LibellesDeSignets {
        LibellesDeSignets(
            titre: Chaines.Signets.titre,
            description: Chaines.Signets.description,
            chapitreNumerote: Chaines.Signets.chapitreNumerote,
            pageNumerotee: Chaines.Signets.pageNumerotee,
            options: Chaines.Signets.options,
            ouvrirLaPage: Chaines.Signets.ouvrirLaPage,
            supprimer: Chaines.Signets.supprimer,
            videTitre: Chaines.Signets.videTitre,
            videPhrase: Chaines.Signets.videPhrase,
            videAction: Chaines.Signets.videAction
        )
    }
}
