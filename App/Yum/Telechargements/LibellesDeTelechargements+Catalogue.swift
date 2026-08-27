import DesignSystem

//
// Libelles de la file de telechargement, pris dans le catalogue de chaines.
//
// Meme role que `LibellesDeSignets.duCatalogue` : le paquet DesignSystem sait
// quel libelle va ou, l application sait lequel c est.
//

extension LibellesDeTelechargements {
    /// Textes de l ecran de suivi de la file.
    static var duCatalogue: LibellesDeTelechargements {
        LibellesDeTelechargements(
            titre: Chaines.Telechargements.titre,
            description: Chaines.Telechargements.description,
            chapitreNumerote: Chaines.Telechargements.chapitreNumerote,
            pagesFaites: Chaines.Telechargements.pagesFaites,
            enAttente: Chaines.Telechargements.enAttente,
            termineAvecPoids: Chaines.Telechargements.termineAvecPoids,
            termine: Chaines.Telechargements.termine,
            enPause: Chaines.Telechargements.enPause,
            annulee: Chaines.Telechargements.annulee,
            poidsEnOctets: Chaines.Telechargements.poidsEnOctets,
            poidsEnKo: Chaines.Telechargements.poidsEnKo,
            poidsEnMo: Chaines.Telechargements.poidsEnMo,
            poidsEnGo: Chaines.Telechargements.poidsEnGo,
            mettreEnPause: Chaines.Telechargements.mettreEnPause,
            reprendre: Chaines.Telechargements.reprendre,
            passerEnPremier: Chaines.Telechargements.passerEnPremier,
            annuler: Chaines.Telechargements.annuler,
            options: Chaines.Telechargements.options,
            videTitre: Chaines.Telechargements.videTitre,
            videPhrase: Chaines.Telechargements.videPhrase,
            videAction: Chaines.Telechargements.videAction
        )
    }
}
