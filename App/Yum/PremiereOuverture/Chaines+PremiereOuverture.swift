import Foundation

//
// Libelles du parcours de premiere ouverture, sortis du catalogue principal.
//
// Le decoupage suit le produit, comme pour l abonnement : tout ce qui parle du
// premier lancement vit ici, y compris la ligne de reglages qui rejoue le
// parcours.
//
// Trois familles de libelles sont empruntees plutot que reecrites. Les deux
// sens de lecture reprennent les valeurs du menu de reglages du tableau 6.7,
// les trois sources reprennent les entrees du menu d ajout de la section 5.3,
// et la mention de la deuxieme etape est celle du tableau 6.8. Le meme mot pour
// la meme chose d un bout a l autre du produit.
//

extension Chaines {
    /// Parcours de premiere ouverture, section 5.10 et tableaux 6.5 et 6.8.
    enum PremiereOuverture {
        static let sensDeLectureTitre = String(
            localized: "premiereOuverture.etape.sensDeLecture.titre"
        )
        static let sensDeLecturePhrase = String(
            localized: "premiereOuverture.etape.sensDeLecture.phrase"
        )
        static let premiereSourceTitre = String(
            localized: "premiereOuverture.etape.premiereSource.titre"
        )
        static let premiereSourcePhrase = String(
            localized: "premiereOuverture.etape.premiereSource.phrase"
        )
        static let essaiPremiumTitre = String(
            localized: "premiereOuverture.etape.essaiPremium.titre"
        )
        static let essaiPremiumPhrase = String(
            localized: "premiereOuverture.etape.essaiPremium.phrase"
        )

        static let continuer = String(localized: "premiereOuverture.commande.continuer")
        static let passer = String(localized: "premiereOuverture.commande.passer")
        static let commencerLEssai = String(
            localized: "premiereOuverture.commande.commencerLEssai"
        )
        static let plusTard = String(localized: "premiereOuverture.commande.plusTard")

        static let sourceFichiersLocaux = String(
            localized: "premiereOuverture.source.fichiersLocaux"
        )
        static let sourceKomga = String(localized: "premiereOuverture.source.komga")
        static let sourceOpds = String(localized: "premiereOuverture.source.opds")

        static let voirToutesLesSources = String(
            localized: "premiereOuverture.voirToutesLesSources"
        )
        static let mention = String(localized: "premiereOuverture.mention")
        static let connexionEnCours = String(localized: "premiereOuverture.connexionEnCours")
        static let seriesTrouvees = String(localized: "premiereOuverture.seriesTrouvees")
        static let adresseInjoignable = String(
            localized: "premiereOuverture.adresseInjoignable"
        )
        static let progression = String(localized: "premiereOuverture.progression")
        static let apercuDuSens = String(localized: "premiereOuverture.apercuDuSens")

        /// Sens de lecture, libelles du menu de reglages du tableau 6.7.
        static let sensDroiteGauche = String(localized: "reglages.valeur.droiteGauche")
        static let sensGaucheDroite = String(localized: "reglages.valeur.gaucheDroite")
    }
}
