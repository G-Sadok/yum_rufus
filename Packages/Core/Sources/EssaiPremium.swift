import Foundation

//
// EssaiPremium
//
// L essai de sept jours, sa condition d ouverture et sa fin.
//
// Trois regles gouvernent l essai, et les trois viennent du produit, pas de la
// boutique.
//
// Il dure sept jours. La section 0.1 du DESIGN-SPEC tranche ce point contre un
// cahier des charges qui ne le chiffrait pas, et le fichier de configuration
// StoreKit du depot porte la meme duree.
//
// Il ne s offre qu une fois. La boutique le sait aussi de son cote, mais
// l application doit le savoir avant d afficher un bouton : promettre sept jours
// offerts a quelqu un qui les a deja pris est un mensonge que la feuille de
// paiement corrigerait a sa place.
//
// Il ne presse personne. Aucun compte a rebours n est expose, la section 5.9
// l interdit explicitement. La date de fin existe pour dire quand l acces
// s arrete, pas pour la faire defiler a l ecran.
//

/// Regles de l essai de sept jours.
public enum EssaiPremium {
    /// Duree offerte a la premiere souscription.
    public static let periode = PeriodeDEssai.septJours

    /// Vrai quand l essai peut encore etre propose.
    ///
    /// Toute transaction d abonnement deja portee par le compte ferme l essai,
    /// qu elle soit active, expiree ou revoquee. Un remboursement ne redonne pas
    /// droit a une seconde periode gratuite.
    public static func estEligible(historique: [TransactionPremium]) -> Bool {
        historique.contains { $0.genre.estUnAbonnement } == false
    }

    /// Instant ou l essai commence a ce moment se terminerait.
    public static func fin(depuis debut: Date, calendrier: Calendar = .current) -> Date {
        periode.fin(depuis: debut, calendrier: calendrier)
    }

    /// Transaction telle que la boutique la rend pour un essai qui demarre.
    ///
    /// Sert a l adaptateur, qui construit la meme forme depuis StoreKit, et aux
    /// tests, qui rejouent le parcours sans boutique. La transaction porte bien
    /// le genre de son produit : un essai est un abonnement qui n est pas encore
    /// facture, jamais un quatrieme genre de produit.
    public static func transaction(
        pour produit: ProduitPremium,
        identifiant: UInt64,
        debut: Date,
        calendrier: Calendar = .current
    ) -> TransactionPremium {
        TransactionPremium(
            identifiant: identifiant,
            identifiantDeProduit: produit.identifiant,
            genre: produit.genre,
            acheteeLe: debut,
            expireLe: fin(depuis: debut, calendrier: calendrier),
            estUneOffreDEssai: true
        )
    }

    /// Vrai quand la duree d une transaction est celle de l essai.
    ///
    /// Sert de repli a l adaptateur sur les systemes ou la boutique ne dit pas
    /// encore quelle offre a produit une transaction. Une premiere periode qui
    /// dure exactement sept jours la ou l abonnement en dure trente ou trois cent
    /// soixante cinq ne peut etre qu un essai.
    ///
    /// La tolerance couvre l ecart d une seconde entre l horodatage de la
    /// boutique et le calcul local. Elle reste tres inferieure a l ecart entre
    /// sept jours et la plus courte des periodes facturees, un mois, ce qui
    /// interdit toute confusion entre les deux.
    ///
    /// - Parameters:
    ///   - debut: date d achat portee par la transaction.
    ///   - fin: date d expiration portee par la transaction.
    ///   - periode: essai declare par le produit.
    public static func correspondALEssai(
        debut: Date,
        fin: Date?,
        periode: PeriodeDEssai = periode,
        calendrier: Calendar = .current
    ) -> Bool {
        guard let fin else {
            return false
        }

        let attendue = periode.fin(depuis: debut, calendrier: calendrier)
        let tolerance: TimeInterval = 60

        return abs(fin.timeIntervalSince(attendue)) <= tolerance
    }

    /// Etat de l abonnement pendant et apres un essai commence a une date.
    ///
    /// Le calcul passe par `CalculDeLEtatDePremium` plutot que de decider seul :
    /// un essai n est pas un etat a part, c est un abonnement dont la premiere
    /// periode est offerte, et les deux doivent expirer de la meme facon.
    public static func etat(
        pourUnEssaiCommenceLe debut: Date,
        produit: ProduitPremium,
        maintenant: Date,
        calendrier: Calendar = .current
    ) -> EtatDePremium {
        let transaction = transaction(
            pour: produit,
            identifiant: 0,
            debut: debut,
            calendrier: calendrier
        )

        return CalculDeLEtatDePremium.etat(pour: [transaction], le: maintenant)
    }
}
