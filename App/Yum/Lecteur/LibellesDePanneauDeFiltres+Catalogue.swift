import Core
import DesignSystem

//
// Libelles du panneau de filtres, pris dans le catalogue de chaines.
//
// Meme role que `LibellesDHistorique.duCatalogue` : le paquet DesignSystem sait
// quel libelle va ou, l application sait lequel c est.
//
// Les deux tables couvrent tous les cas de `FiltreDImage` et de
// `TraitementDImage`. Un cas ajoute au modele sans son libelle laisserait une
// ligne muette dans le panneau, et la suite de tests le detecte avant l ecran.
//

extension LibellesDePanneauDeFiltres {
    /// Textes du panneau de filtres, section 5.7 et tableau 6.5.
    static var duCatalogue: LibellesDePanneauDeFiltres {
        LibellesDePanneauDeFiltres(
            titre: Chaines.Filtres.titre,
            libellesDeFiltre: [
                .luminosite: Chaines.Filtres.luminosite,
                .chaleur: Chaines.Filtres.chaleur,
                .nettete: Chaines.Filtres.nettete,
                .contraste: Chaines.Filtres.contraste,
                .gamma: Chaines.Filtres.gamma,
            ],
            libellesDeTraitement: [
                .reductionDuBruit: Chaines.Filtres.reductionDuBruit,
                .ameliorationIA: Chaines.Filtres.ameliorationIA,
                .colorisationIA: Chaines.Filtres.colorisationIA,
            ],
            etiquetteDeLaCouronne: Chaines.Filtres.couronne
        )
    }
}
