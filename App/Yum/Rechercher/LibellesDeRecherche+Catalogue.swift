import DesignSystem

//
// Libelles de l ecran Rechercher, pris dans le catalogue de chaines.
//

extension LibellesDeRecherche {
    static var duCatalogue: LibellesDeRecherche {
        LibellesDeRecherche(
            espaceReserve: Chaines.Recherche.espaceReserve,
            etiquetteDuChamp: Chaines.Recherche.etiquetteDuChamp,
            effacerLaRecherche: Chaines.Recherche.effacer,
            compteurDeResultats: Chaines.Recherche.compteur,
            compteurDeResultatsPartiel: Chaines.Recherche.compteurPartiel,
            toutVoir: Chaines.Recherche.toutVoir,
            retourAuxResultats: Chaines.Recherche.retour,
            reessayer: Chaines.Erreur.reessayer,
            ligneDelaiDepasse: Chaines.Recherche.ligneDelaiDepasse,
            ligneInjoignable: Chaines.Recherche.ligneInjoignable,
            ligneAccesRefuse: Chaines.Recherche.ligneAccesRefuse,
            ligneEchec: Chaines.Recherche.ligneEchec,
            aucunResultatTitre: Chaines.Recherche.aucunResultatTitre,
            aucunResultatPhrase: Chaines.Recherche.aucunResultatPhrase,
            aucuneSourceTitre: Chaines.Recherche.aucuneSourceTitre,
            aucuneSourcePhrase: Chaines.Recherche.aucuneSourcePhrase,
            toutesLesSourcesTitre: Chaines.Recherche.toutesLesSourcesTitre,
            toutesLesSourcesPhrase: Chaines.Recherche.toutesLesSourcesPhrase
        )
    }
}
