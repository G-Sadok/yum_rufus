import Foundation

//
// Libelles de l ecran Statistiques de lecture, sous ecran de la section 5.5 de
// DESIGN-SPEC.md et fonctionnalite F059.
//
// La section 6 ne dessine pas cet ecran. Les libelles suivent donc ses regles
// d ecriture : voix active, le meme mot pour la meme chose d un bout a l autre
// du parcours, aucun point d exclamation, aucun tiret cadratin.
//
// S y ajoute le troisieme critere de F059, aucune formulation culpabilisante.
// Il n est pas une intention mais une liste, celle de
// `Core.FormulationBienveillante`, et la suite de tests confronte chacun des
// textes ci dessous a cette liste. Deux consequences visibles :
//
// - la serie a zero ne se dit pas `0 jours`, qui se lit comme un score, mais
//   `La serie commence a la prochaine lecture` ;
// - la description du rappel dit que le rappel se tait quand l objectif est
//   atteint, et non ce qui arrive quand il ne l est pas.
//
// Cinq libelles sont empruntes plutot que reecrits. Le titre est celui de la
// ligne de reglages qui mene ici, les deux etiquettes de chevron sont celles du
// compteur de la section 4.1, et l action de l etat vide est celle de
// l historique, qui mene au meme endroit.
//

extension Chaines {
    /// Statistiques de lecture, sous ecran de la section 5.5.
    enum Statistiques {
        static let titre = String(localized: "reglages.ligne.assistance.statistiquesDeLecture")
        static let sectionAujourdHui = String(localized: "statistiques.section.aujourdHui")
        static let sectionSerie = String(localized: "statistiques.section.serie")
        static let sectionDerniersJours = String(localized: "statistiques.section.derniersJours")
        static let sectionTotaux = String(localized: "statistiques.section.totaux")
        static let lectureDuJour = String(localized: "statistiques.lectureDuJour")
        static let objectif = String(localized: "statistiques.objectif")
        static let objectifDesactive = String(localized: "statistiques.objectifDesactive")
        static let objectifEnChapitres = String(localized: "statistiques.objectifEnChapitres")
        static let augmenter = String(localized: "reglages.augmenter")
        static let diminuer = String(localized: "reglages.diminuer")
        static let rappel = String(localized: "statistiques.rappel")
        static let descriptionDuRappel = String(localized: "statistiques.description.rappel")
        static let comptePartiel = String(localized: "statistiques.comptePartiel")
        static let compteSimple = String(localized: "statistiques.compteSimple")
        static let serie = String(localized: "statistiques.serie")
        static let serieEnJours = String(localized: "statistiques.serieEnJours")
        static let serieVide = String(localized: "statistiques.serieVide")
        static let descriptionDeLaSerie = String(localized: "statistiques.description.serie")
        static let joursDeLecture = String(localized: "statistiques.joursDeLecture")
        static let compteEnJours = String(localized: "statistiques.compteEnJours")
        static let chapitresLus = String(localized: "statistiques.chapitresLus")
        static let pagesLues = String(localized: "statistiques.pagesLues")
        static let compteEnPages = String(localized: "statistiques.compteEnPages")
        static let videTitre = String(localized: "etatVide.statistiques.titre")
        static let videPhrase = String(localized: "etatVide.statistiques.phrase")
        static let videAction = String(localized: "etatVide.statistiques.action")
    }
}
