import DesignSystem

//
// Libelles de l ecran Statistiques de lecture, pris dans le catalogue de
// chaines.
//
// Meme role que `LibellesDeSignets.duCatalogue` : le paquet DesignSystem sait
// quel libelle va ou, l application sait lequel c est.
//

extension LibellesDeStatistiques {
    /// Textes de l ecran de statistiques de lecture.
    static var duCatalogue: LibellesDeStatistiques {
        LibellesDeStatistiques(
            titre: Chaines.Statistiques.titre,
            sectionAujourdHui: Chaines.Statistiques.sectionAujourdHui,
            sectionSerie: Chaines.Statistiques.sectionSerie,
            sectionDerniersJours: Chaines.Statistiques.sectionDerniersJours,
            sectionTotaux: Chaines.Statistiques.sectionTotaux,
            lectureDuJour: Chaines.Statistiques.lectureDuJour,
            objectif: Chaines.Statistiques.objectif,
            objectifDesactive: Chaines.Statistiques.objectifDesactive,
            objectifEnChapitres: Chaines.Statistiques.objectifEnChapitres,
            augmenter: Chaines.Statistiques.augmenter,
            diminuer: Chaines.Statistiques.diminuer,
            rappel: Chaines.Statistiques.rappel,
            descriptionDuRappel: Chaines.Statistiques.descriptionDuRappel,
            comptePartiel: Chaines.Statistiques.comptePartiel,
            compteSimple: Chaines.Statistiques.compteSimple,
            serie: Chaines.Statistiques.serie,
            serieEnJours: Chaines.Statistiques.serieEnJours,
            serieVide: Chaines.Statistiques.serieVide,
            descriptionDeLaSerie: Chaines.Statistiques.descriptionDeLaSerie,
            joursDeLecture: Chaines.Statistiques.joursDeLecture,
            compteEnJours: Chaines.Statistiques.compteEnJours,
            chapitresLus: Chaines.Statistiques.chapitresLus,
            pagesLues: Chaines.Statistiques.pagesLues,
            compteEnPages: Chaines.Statistiques.compteEnPages,
            videTitre: Chaines.Statistiques.videTitre,
            videPhrase: Chaines.Statistiques.videPhrase,
            videAction: Chaines.Statistiques.videAction
        )
    }
}
