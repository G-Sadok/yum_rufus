import Core
import DesignSystem

//
// Libelles des ecrans de stockage, pris dans le catalogue de chaines.
//
// Meme role que `LibellesDeTelechargements.duCatalogue` : le paquet DesignSystem
// sait quel libelle va ou, l application sait lequel c est.
//
// Les deux tables sont indexees par la representation persistee de la
// categorie, celle que `CategorieDeStockage` ecrit. Passer par elle plutot que
// par le cas Swift garde le catalogue lisible sans le lier a l ordre de
// l enumeration.
//

extension LibellesDeStockage {
    /// Textes des ecrans de gestion du stockage.
    static var duCatalogue: LibellesDeStockage {
        LibellesDeStockage(
            titre: Chaines.Stockage.titre,
            description: Chaines.Stockage.description,
            categories: categoriesDuCatalogue,
            chapitreNumerote: Chaines.Stockage.chapitreNumerote,
            chapitreLu: Chaines.Stockage.chapitreLu,
            chapitreNonLu: Chaines.Stockage.chapitreNonLu,
            cacheDUneSource: Chaines.Stockage.cacheDUneSource,
            elementsAnonymes: Chaines.Stockage.elementsAnonymes,
            titresAnonymes: titresAnonymesDuCatalogue,
            poids: LibellesDeTelechargements.duCatalogue.motifsDePoids,
            supprimer: Chaines.Stockage.supprimer,
            toutSupprimer: Chaines.Stockage.toutSupprimer,
            compteurDeSelection: Chaines.Stockage.compteurDeSelection,
            fermerLaSelection: Chaines.Stockage.fermerLaSelection,
            selectionner: Chaines.Stockage.selectionner,
            confirmationTitre: Chaines.Stockage.confirmationTitre,
            confirmationDescription: Chaines.Stockage.confirmationDescription,
            confirmationAnnuler: Chaines.Stockage.confirmationAnnuler,
            confirmationSupprimer: Chaines.Stockage.supprimer,
            videTitre: Chaines.Stockage.videTitre,
            videPhrase: Chaines.Stockage.videPhrase
        )
    }

    /// Libelle de chaque categorie, inventaire de la section 9.
    private static var categoriesDuCatalogue: [String: String] {
        [
            CategorieDeStockage.chapitresTelecharges.rawValue:
                Chaines.Stockage.categorieChapitresTelecharges,
            CategorieDeStockage.cacheDeChapitres.rawValue:
                Chaines.Stockage.categorieCacheDeChapitres,
            CategorieDeStockage.cacheDImages.rawValue:
                Chaines.Stockage.categorieCacheDImages,
        ]
    }

    /// Titre du poste groupe de chaque categorie.
    private static var titresAnonymesDuCatalogue: [String: String] {
        [
            CategorieDeStockage.chapitresTelecharges.rawValue:
                Chaines.Stockage.anonymesChapitresTelecharges,
            CategorieDeStockage.cacheDeChapitres.rawValue:
                Chaines.Stockage.anonymesCacheDeChapitres,
            CategorieDeStockage.cacheDImages.rawValue:
                Chaines.Stockage.anonymesCacheDImages,
        ]
    }
}
