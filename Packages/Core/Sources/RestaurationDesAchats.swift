import Foundation

//
// RestaurationDesAchats
//
// La restauration est obligatoire, et le cahier de developpement la veut
// accessible depuis le mur premium lui meme, section 10. Sans elle, un
// utilisateur qui change d appareil ou reinstalle l application perd un acces
// qu il a paye, et n a aucun moyen de le reprendre sans repayer.
//
// La restauration ne cree rien. Elle relit ce que la boutique garde du compte,
// verifie chaque transaction, et recalcule l etat. Une restauration qui ne trouve
// rien n est pas un echec : elle a repondu, et sa reponse est qu il n y a rien a
// rendre. L ecran le dit ainsi plutot que de montrer une erreur.
//

/// Ce qu une restauration a rendu.
public struct ResultatDeRestauration: Sendable, Equatable {
    /// Transactions verifiees retrouvees sur le compte.
    public let transactions: [TransactionPremium]

    /// Etat de l abonnement apres restauration.
    public let etat: EtatDePremium

    /// Transactions ecartees, avec leur cause.
    ///
    /// Elles ne debloquent rien mais sont conservees pour le journal : une
    /// restauration qui ecarte tout ce qu elle trouve doit pouvoir dire
    /// pourquoi, sans quoi le probleme est indiagnosticable a distance.
    public let refusees: [MotifDeRefusDeTransaction]

    public init(
        transactions: [TransactionPremium],
        etat: EtatDePremium,
        refusees: [MotifDeRefusDeTransaction] = []
    ) {
        self.transactions = transactions
        self.etat = etat
        self.refusees = refusees
    }

    /// Vrai quand le compte ne porte aucun achat verifie.
    public var aucunAchatTrouve: Bool {
        transactions.isEmpty
    }
}

/// Regles de la restauration des achats.
public enum RestaurationDesAchats {
    /// Resultat d une restauration, a partir des verdicts rendus.
    ///
    /// - Parameters:
    ///   - verdicts: un verdict par transaction presentee par la boutique.
    ///   - maintenant: date a laquelle l etat est recalcule.
    public static func resultat(
        pour verdicts: [VerdictDeTransaction],
        le maintenant: Date
    ) -> ResultatDeRestauration {
        let retenues = VerificationDeTransaction.retenues(dans: verdicts)

        let refusees: [MotifDeRefusDeTransaction] = verdicts.compactMap { verdict in
            guard case let .refusee(motif) = verdict else {
                return nil
            }

            return motif
        }

        return ResultatDeRestauration(
            transactions: retenues,
            etat: CalculDeLEtatDePremium.etat(pour: retenues, le: maintenant),
            refusees: refusees
        )
    }
}
