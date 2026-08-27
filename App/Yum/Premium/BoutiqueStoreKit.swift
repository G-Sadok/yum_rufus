import Core
import Foundation
import StoreKit

//
// Acces reel a la boutique du systeme, StoreKit 2.
//
// C est le seul fichier du projet qui importe StoreKit. Il ne decide de rien : il
// traduit ce que la boutique rend vers les types de `Core`, et laisse le domaine
// dire ce que cela vaut. Toute regle ecrite ici serait une regle non testee,
// puisque StoreKit ne se rejoue pas sous `swift test`.
//
// La traduction est volontairement etroite. Un produit dont l identifiant n est
// pas au catalogue est ecarte, une transaction qui n a pas passe la verification
// du systeme est refusee avec sa cause, et rien d autre ne franchit la frontiere.
//
// Le fichier de configuration `App/Yum.storekit`, charge par le schema Xcode,
// permet de derouler ces parcours a la main sur un poste de developpement. La
// suite automatique, elle, rejoue les memes regles sur `BoutiqueDeTest`, qui lit
// ce meme fichier.
//

/// Boutique du systeme, derriere le protocole du domaine.
actor BoutiqueStoreKit: Boutique {
    /// Identifiants demandes a la boutique.
    private let identifiants: [String]

    /// Identifiant de cette application, compare a celui des transactions.
    private let identifiantDeLApplication: String?

    /// Calendrier employe par le repli de detection d essai.
    private let calendrier: Calendar

    init(
        identifiants: [String] = CataloguePremium.identifiants,
        identifiantDeLApplication: String? = Bundle.main.bundleIdentifier,
        calendrier: Calendar = .current
    ) {
        self.identifiants = identifiants
        self.identifiantDeLApplication = identifiantDeLApplication
        self.calendrier = calendrier
    }

    // MARK: Boutique

    func produits() async throws -> [ProduitPremium] {
        do {
            let articles = try await Product.products(for: identifiants)

            return articles.compactMap { traduire($0) }
        } catch {
            throw ErreurDeBoutique.boutiqueInjoignable
        }
    }

    func acheter(_ produit: ProduitPremium) async throws -> ResultatDAchat {
        guard let article = try await article(de: produit) else {
            throw ErreurDeBoutique.produitIntrouvable(identifiant: produit.identifiant)
        }

        let resultat: Product.PurchaseResult

        do {
            resultat = try await article.purchase()
        } catch {
            throw ErreurDeBoutique.depuis(error)
        }

        switch resultat {
        case let .success(verification):
            return try await .reussi(retenir(verification))

        case .pending:
            return .enAttenteDeValidation

        case .userCancelled:
            return .annuleParLUtilisateur

        @unknown default:
            // Un cas ajoute par une version future n ouvre rien. Refuser
            // l inconnu est la seule reponse sure quand il s agit d un acces
            // paye.
            return .enAttenteDeValidation
        }
    }

    func restaurer() async throws -> ResultatDeRestauration {
        do {
            try await AppStore.sync()
        } catch {
            throw ErreurDeBoutique.depuis(error)
        }

        return await RestaurationDesAchats.resultat(pour: verdicts(), le: Date())
    }

    func etatCourant() async -> EtatDePremium {
        let transactions = await VerificationDeTransaction.retenues(dans: verdicts())

        return CalculDeLEtatDePremium.etat(pour: transactions, le: Date())
    }

    func essaiDisponible() async -> Bool {
        guard let articles = try? await Product.products(for: [CataloguePremium.mensuel]),
              let abonnement = articles.first?.subscription
        else {
            return false
        }

        return await abonnement.isEligibleForIntroOffer
    }

    // MARK: Surveillance

    /// Suit les transactions qui arrivent pendant que l application tourne.
    ///
    /// Un renouvellement, un remboursement ou un achat fait sur un autre appareil
    /// arrivent par ce flux. Chaque transaction verifiee est close, sans quoi la
    /// boutique la represente indefiniment.
    ///
    /// - Parameter changement: appele apres chaque transaction retenue, avec
    ///   l etat recalcule.
    func surveiller(_ changement: @Sendable @escaping (EtatDePremium) async -> Void) async {
        for await verification in Transaction.updates {
            guard case let .verified(transaction) = verification else {
                continue
            }

            await transaction.finish()
            await changement(etatCourant())
        }
    }

    // MARK: Traduction

    /// Article de la boutique correspondant a un produit du domaine.
    private func article(de produit: ProduitPremium) async throws -> Product? {
        do {
            return try await Product.products(for: [produit.identifiant]).first
        } catch {
            throw ErreurDeBoutique.boutiqueInjoignable
        }
    }

    /// Verdicts rendus sur ce que le compte porte aujourd hui.
    private func verdicts() async -> [VerdictDeTransaction] {
        var rendus: [VerdictDeTransaction] = []

        for await verification in Transaction.currentEntitlements {
            rendus.append(verdict(pour: verification))
        }

        return rendus
    }

    /// Retient une transaction achetee, ou leve l erreur qui dit pourquoi non.
    private func retenir(
        _ verification: VerificationResult<StoreKit.Transaction>
    ) async throws -> TransactionPremium {
        switch verdict(pour: verification) {
        case let .verifiee(transaction):
            if case let .verified(brute) = verification {
                await brute.finish()
            }

            return transaction

        case let .refusee(motif):
            throw ErreurDeBoutique.transactionNonVerifiee(motif: motif)
        }
    }

    /// Verdict du domaine sur une transaction rendue par la boutique.
    ///
    /// La signature est celle du systeme, la regle metier est celle de `Core`.
    /// Les deux verifications restent distinctes, comme le demande la frontiere.
    private func verdict(
        pour verification: VerificationResult<StoreKit.Transaction>
    ) -> VerdictDeTransaction {
        switch verification {
        case let .verified(brute):
            guard let traduite = traduire(brute) else {
                return .refusee(.produitInconnu)
            }

            return VerificationDeTransaction.verdict(
                pour: traduite,
                signatureValide: true,
                identifiantDApplication: brute.appBundleID,
                identifiantAttendu: identifiantDeLApplication
            )

        case .unverified:
            return .refusee(.signatureInvalide)
        }
    }

    /// Produit du domaine correspondant a un article de la boutique.
    private func traduire(_ article: Product) -> ProduitPremium? {
        guard let genre = CataloguePremium.genre(de: article.id) else {
            return nil
        }

        return ProduitPremium(
            identifiant: article.id,
            genre: genre,
            prixAffiche: article.displayPrice,
            essai: essai(de: article)
        )
    }

    /// Transaction du domaine correspondant a une transaction de la boutique.
    private func traduire(_ transaction: StoreKit.Transaction) -> TransactionPremium? {
        guard let genre = CataloguePremium.genre(de: transaction.productID) else {
            return nil
        }

        return TransactionPremium(
            identifiant: transaction.id,
            identifiantDeProduit: transaction.productID,
            genre: genre,
            acheteeLe: transaction.purchaseDate,
            expireLe: transaction.expirationDate,
            revoqueeLe: transaction.revocationDate,
            estUneOffreDEssai: estUnEssai(transaction)
        )
    }

    /// Periode d essai declaree par un article, nulle quand il n en offre pas.
    ///
    /// Seule une offre entierement gratuite est un essai. Une offre a prix reduit
    /// est une remise, et l annoncer comme sept jours offerts serait faux.
    private func essai(de article: Product) -> PeriodeDEssai? {
        guard let offre = article.subscription?.introductoryOffer,
              offre.paymentMode == .freeTrial
        else {
            return nil
        }

        return PeriodeDEssai(jours: jours(de: offre.period))
    }

    /// Duree d une periode d abonnement en jours.
    private func jours(de periode: Product.SubscriptionPeriod) -> Int {
        switch periode.unit {
        case .day: periode.value
        case .week: periode.value * 7
        case .month: periode.value * 30
        case .year: periode.value * 365
        @unknown default: periode.value
        }
    }

    /// Vrai quand la transaction consomme l offre d essai.
    ///
    /// Les systemes recents nomment l offre qui a produit la transaction. Les
    /// plus anciens ne l exposent pas, et le repli compare alors la duree de la
    /// periode a celle de l essai, regle qui vit dans `Core` et s y teste.
    private func estUnEssai(_ transaction: StoreKit.Transaction) -> Bool {
        if #available(macOS 14.2, iOS 17.2, *) {
            return transaction.offer?.type == .introductory
        }

        return EssaiPremium.correspondALEssai(
            debut: transaction.purchaseDate,
            fin: transaction.expirationDate,
            calendrier: calendrier
        )
    }
}
