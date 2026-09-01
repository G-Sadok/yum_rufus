import Foundation

//
// Libelles de l ecran Rechercher, section 5.4.
//
// Ils vivent a part du catalogue central, qui depassait sa longueur maximale.
// Le decoupage suit celui des autres ecrans qui ont deja leur fichier.
//

extension Chaines {
    /// Ecran Rechercher, section 5.4.
    enum Recherche {
        static let espaceReserve = String(localized: "recherche.espaceReserve")
        static let etiquetteDuChamp = String(localized: "recherche.etiquetteDuChamp")
        static let effacer = String(localized: "recherche.effacer")
        static let compteur = String(localized: "recherche.compteur")
        static let compteurPartiel = String(localized: "recherche.compteurPartiel")
        static let toutVoir = String(localized: "recherche.toutVoir")
        static let retour = String(localized: "recherche.retour")
        static let ligneDelaiDepasse = String(localized: "recherche.ligne.delaiDepasse")
        static let ligneInjoignable = String(localized: "recherche.ligne.injoignable")
        static let ligneAccesRefuse = String(localized: "recherche.ligne.accesRefuse")
        static let ligneEchec = String(localized: "recherche.ligne.echec")
        static let aucunResultatTitre = String(localized: "recherche.aucunResultat.titre")
        static let aucunResultatPhrase = String(localized: "recherche.aucunResultat.phrase")
        static let aucuneSourceTitre = String(localized: "recherche.aucuneSource.titre")
        static let aucuneSourcePhrase = String(localized: "recherche.aucuneSource.phrase")
        static let toutesLesSourcesTitre = String(
            localized: "recherche.toutesLesSources.titre"
        )
        static let toutesLesSourcesPhrase = String(
            localized: "recherche.toutesLesSources.phrase"
        )
    }
}
