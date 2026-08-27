import Foundation

//
// EtatDePremium
//
// L etat de l abonnement, calcule a partir des seules transactions verifiees.
//
// Il n existe aucun interrupteur `premiumActif` persiste quelque part. L etat se
// recalcule depuis les transactions, parce qu une valeur ecrite dans un fichier
// de reglages se modifie de l exterieur, et parce qu un abonnement expire pendant
// que l application est fermee sans que personne ne pense a mettre l interrupteur
// a jour.
//
// L expiration ne supprime rien. Elle change ce que l ecran montre, jamais ce que
// la bibliotheque contient, conformement a la regle de degradation de la section
// 10 du cahier de developpement.
//

/// Etat de l abonnement a un instant donne.
public enum EtatDePremium: Sendable, Equatable {
    /// Aucun achat. Les fonctions premium restent verrouillees.
    case gratuit

    /// Essai en cours, avec sa date de fin.
    case essai(finLe: Date)

    /// Abonnement en cours, avec son genre et sa prochaine echeance.
    case abonne(genre: GenreDeProduitPremium, renouvelleLe: Date)

    /// Achat definitif. Rien n expire.
    case definitif

    /// Abonnement termine, avec la date a laquelle il s est arrete.
    ///
    /// Distinct de `gratuit` : l utilisateur a paye, ses donnees restent
    /// intactes, et la banniere de reactivation n a de sens que dans ce cas.
    case expire(le: Date)

    /// Vrai quand les fonctions de la matrice premium sont ouvertes.
    public var donneAccesAuxFonctionsPremium: Bool {
        switch self {
        case .essai, .abonne, .definitif: true
        case .gratuit, .expire: false
        }
    }

    /// Vrai quand l utilisateur a deja paye ou essaye, meme si c est termine.
    ///
    /// L essai ne se propose plus dans ce cas, et le mur cesse d annoncer sept
    /// jours offerts a quelqu un qui les a deja pris.
    public var aDejaSouscrit: Bool {
        switch self {
        case .gratuit: false
        case .essai, .abonne, .definitif, .expire: true
        }
    }
}

/// Calcul de l etat a partir des transactions.
public enum CalculDeLEtatDePremium {
    /// Etat de l abonnement a la date consideree.
    ///
    /// Les transactions revoquees sont ecartees d abord : un remboursement rend
    /// l acces, il ne le laisse pas courir jusqu a l echeance payee.
    ///
    /// L achat definitif l emporte sur tout le reste. Un abonnement expire ne
    /// doit jamais fermer un acces achete une fois pour toutes.
    ///
    /// - Parameters:
    ///   - transactions: transactions deja verifiees, dans n importe quel ordre.
    ///   - maintenant: date a laquelle l etat est demande.
    public static func etat(
        pour transactions: [TransactionPremium],
        le maintenant: Date
    ) -> EtatDePremium {
        let valides = transactions.filter { $0.estRevoquee(le: maintenant) == false }

        if valides.contains(where: { $0.genre == .definitif }) {
            return .definitif
        }

        let abonnements = valides.filter(\.genre.estUnAbonnement)

        if let courante = plusLointaine(parmi: abonnements.filter { $0.estActive(le: maintenant) }) {
            let echeance = courante.expireLe ?? maintenant

            return courante.estUneOffreDEssai
                ? .essai(finLe: echeance)
                : .abonne(genre: courante.genre, renouvelleLe: echeance)
        }

        if let derniere = plusLointaine(parmi: abonnements), let finie = derniere.expireLe {
            return .expire(le: finie)
        }

        return .gratuit
    }

    /// Transaction dont l echeance est la plus lointaine.
    ///
    /// Un utilisateur qui passe du mensuel a l annuel porte deux transactions a
    /// la fois. Celle qui compte est celle qui court le plus loin, sans quoi le
    /// passage a l annuel afficherait une expiration le mois suivant.
    private static func plusLointaine(
        parmi transactions: [TransactionPremium]
    ) -> TransactionPremium? {
        transactions.max { premiere, seconde in
            (premiere.expireLe ?? .distantPast) < (seconde.expireLe ?? .distantPast)
        }
    }
}
