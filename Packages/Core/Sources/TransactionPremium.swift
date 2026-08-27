import Foundation

//
// TransactionPremium
//
// Une transaction telle que l application la retient, et la seule porte par
// laquelle un achat ouvre les fonctions premium.
//
// Deux verifications distinctes se jouent ici, et les confondre est l erreur qui
// laisse passer un faux achat.
//
// La premiere est cryptographique : la boutique signe ce qu elle rend, et une
// signature que le systeme ne valide pas rend la transaction inutilisable. Elle
// appartient a l adaptateur, qui seul voit la signature.
//
// La seconde est metier : une transaction correctement signee peut porter un
// produit qui n est pas des notres, ou avoir ete revoquee apres un
// remboursement. Elle appartient a ce fichier, et c est elle qui decide qu une
// transaction compte.
//

/// Ce que l application retient d un achat.
public struct TransactionPremium: Sendable, Equatable, Hashable {
    /// Identifiant de la transaction chez la boutique.
    public let identifiant: UInt64

    /// Identifiant du produit achete.
    public let identifiantDeProduit: String

    /// Genre du produit achete.
    public let genre: GenreDeProduitPremium

    /// Instant de l achat.
    public let acheteeLe: Date

    /// Instant ou l acces s arrete, nul pour un achat definitif.
    public let expireLe: Date?

    /// Instant ou la boutique a revoque la transaction, nul sinon.
    ///
    /// Un remboursement ou une contestation revoque. La transaction reste
    /// parfaitement signee, elle cesse simplement de donner droit a quoi que ce
    /// soit.
    public let revoqueeLe: Date?

    /// Vrai quand l achat consomme l offre d essai.
    public let estUneOffreDEssai: Bool

    public init(
        identifiant: UInt64,
        identifiantDeProduit: String,
        genre: GenreDeProduitPremium,
        acheteeLe: Date,
        expireLe: Date? = nil,
        revoqueeLe: Date? = nil,
        estUneOffreDEssai: Bool = false
    ) {
        self.identifiant = identifiant
        self.identifiantDeProduit = identifiantDeProduit
        self.genre = genre
        self.acheteeLe = acheteeLe
        self.expireLe = expireLe
        self.revoqueeLe = revoqueeLe
        self.estUneOffreDEssai = estUneOffreDEssai
    }

    /// Vrai quand la transaction a ete revoquee a la date consideree.
    public func estRevoquee(le maintenant: Date) -> Bool {
        guard let revoqueeLe else {
            return false
        }

        return revoqueeLe <= maintenant
    }

    /// Vrai quand la transaction ouvre encore l acces a la date consideree.
    ///
    /// Un achat definitif n expire pas. Un abonnement ouvre l acces tant que son
    /// echeance est devant lui.
    public func estActive(le maintenant: Date) -> Bool {
        guard estRevoquee(le: maintenant) == false else {
            return false
        }

        guard let expireLe else {
            return true
        }

        return expireLe > maintenant
    }
}

/// Pourquoi une transaction est ecartee.
public enum MotifDeRefusDeTransaction: String, Sendable, Equatable, CaseIterable {
    /// La boutique n a pas pu prouver que la transaction vient bien d elle.
    case signatureInvalide

    /// La transaction porte un produit que cette application ne vend pas.
    case produitInconnu

    /// La transaction vient d une autre application.
    case applicationDifferente
}

/// Verdict rendu sur une transaction presentee par la boutique.
public enum VerdictDeTransaction: Sendable, Equatable {
    /// La transaction est authentique et concerne bien Premium.
    case verifiee(TransactionPremium)

    /// La transaction est ecartee, avec sa cause.
    case refusee(MotifDeRefusDeTransaction)

    /// Transaction retenue, nulle quand le verdict est un refus.
    public var transaction: TransactionPremium? {
        guard case let .verifiee(transaction) = self else {
            return nil
        }

        return transaction
    }
}

/// Verification metier d une transaction.
public enum VerificationDeTransaction {
    /// Verdict rendu sur une transaction.
    ///
    /// - Parameters:
    ///   - transaction: ce que la boutique a rendu, deja traduit.
    ///   - signatureValide: resultat de la verification cryptographique du
    ///     systeme, que seul l adaptateur peut connaitre.
    ///   - identifiantDApplication: identifiant porte par la transaction.
    ///   - identifiantAttendu: identifiant de cette application.
    ///
    /// La revocation n apparait pas parmi les motifs de refus, et ce n est pas
    /// un oubli. Une transaction revoquee est authentique, elle a simplement
    /// cesse de donner droit. La distinguer permet a l ecran de dire ce qui s est
    /// passe au lieu d annoncer une fraude.
    public static func verdict(
        pour transaction: TransactionPremium,
        signatureValide: Bool,
        identifiantDApplication: String? = nil,
        identifiantAttendu: String? = nil
    ) -> VerdictDeTransaction {
        guard signatureValide else {
            return .refusee(.signatureInvalide)
        }

        if vientDUneAutreApplication(identifiantDApplication, attendu: identifiantAttendu) {
            return .refusee(.applicationDifferente)
        }

        guard let genre = CataloguePremium.genre(de: transaction.identifiantDeProduit),
              genre == transaction.genre
        else {
            return .refusee(.produitInconnu)
        }

        return .verifiee(transaction)
    }

    /// Transactions retenues parmi une suite de verdicts.
    public static func retenues(dans verdicts: [VerdictDeTransaction]) -> [TransactionPremium] {
        verdicts.compactMap(\.transaction)
    }

    /// Vrai quand la transaction porte l identifiant d une autre application.
    ///
    /// Deux identifiants absents ne prouvent rien et ne refusent rien : les
    /// systemes qui ne nomment pas l application dans leurs transactions ne
    /// doivent pas voir tous leurs achats ecartes.
    private static func vientDUneAutreApplication(
        _ porte: String?,
        attendu: String?
    ) -> Bool {
        guard let porte, let attendu else {
            return false
        }

        return porte != attendu
    }
}
