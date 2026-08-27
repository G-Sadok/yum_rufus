import Core
import Foundation

//
// Boutique de test, alimentee par le fichier de configuration StoreKit.
//
// Elle rejoue les parcours d achat sans StoreKit et sans reseau : les produits
// viennent de `App/Yum.storekit`, l horloge est fournie par le test, et les
// pannes sont demandees explicitement. Ce que StoreKit fait de son cote,
// signature et facturation, est represente par un interrupteur, parce que c est
// exactement ce que l adaptateur observe de lui.
//
// La regle de l essai est appliquee ici comme la boutique du systeme l applique :
// une seule periode gratuite par compte, quel que soit le produit choisi dans le
// groupe d abonnement.
//

/// Ce que la boutique simulee doit faire de la prochaine demande.
enum ComportementDeBoutique {
    /// Tout se passe bien.
    case normale

    /// La boutique ne repond pas.
    case injoignable

    /// L utilisateur referme la feuille de paiement.
    case annulation

    /// La boutique attend une validation exterieure.
    case attenteDeValidation

    /// La transaction rendue n est pas authentifiable.
    case signatureInvalide
}

/// Boutique simulee, conforme au meme protocole que l adaptateur StoreKit.
actor BoutiqueDeTest: Boutique {
    private let catalogue: [ProduitPremium]

    /// Ce que l appareil connait, et que la restauration recompose.
    private var transactions: [TransactionPremium]

    /// Ce que le compte garde, quoi qu il arrive a l appareil.
    ///
    /// La boutique du systeme ne perd pas un achat parce que l application a ete
    /// desinstallee, et elle n oublie pas un essai deja consomme. Les deux
    /// registres sont donc distincts.
    private var compte: [TransactionPremium]

    private var maintenant: Date
    private var comportement: ComportementDeBoutique
    private var prochainIdentifiant: UInt64
    private let calendrier: Calendar

    init(
        catalogue: [ProduitPremium],
        maintenant: Date,
        transactions: [TransactionPremium] = [],
        comportement: ComportementDeBoutique = .normale,
        calendrier: Calendar = Calendar(identifier: .gregorian)
    ) {
        self.catalogue = catalogue
        self.transactions = transactions
        compte = transactions
        self.maintenant = maintenant
        self.comportement = comportement
        self.calendrier = calendrier
        prochainIdentifiant = UInt64(transactions.count) + 1
    }

    /// Boutique construite depuis le fichier de configuration du depot.
    static func depuisLaConfiguration(
        maintenant: Date,
        comportement: ComportementDeBoutique = .normale
    ) throws -> BoutiqueDeTest {
        let configuration = try ConfigurationStoreKit.charger()

        return BoutiqueDeTest(
            catalogue: configuration.produits,
            maintenant: maintenant,
            comportement: comportement
        )
    }

    // MARK: Horloge et pannes

    /// Avance l horloge de la boutique.
    func avancerDe(jours: Int) {
        maintenant = calendrier.date(byAdding: .day, value: jours, to: maintenant)
            ?? maintenant.addingTimeInterval(Double(jours) * 24 * 60 * 60)
    }

    /// Change ce que la boutique fera de la prochaine demande.
    func adopter(_ nouveau: ComportementDeBoutique) {
        comportement = nouveau
    }

    /// Revoque tout ce que le compte porte, comme le fait un remboursement.
    func revoquerTout() {
        compte = compte.map(revoquee(_:))
        transactions = transactions.map(revoquee(_:))
    }

    /// Vide l appareil sans vider le compte, comme une reinstallation.
    ///
    /// La restauration doit tout retrouver ensuite, c est le seul interet de la
    /// manoeuvre.
    func oublierLesTransactionsLocales() {
        transactions = []
    }

    // MARK: Boutique

    func produits() async throws -> [ProduitPremium] {
        guard comportement != .injoignable else {
            throw ErreurDeBoutique.boutiqueInjoignable
        }

        return catalogue
    }

    func acheter(_ produit: ProduitPremium) async throws -> ResultatDAchat {
        switch comportement {
        case .injoignable:
            throw ErreurDeBoutique.boutiqueInjoignable
        case .annulation:
            return .annuleParLUtilisateur
        case .attenteDeValidation:
            return .enAttenteDeValidation
        case .normale, .signatureInvalide:
            break
        }

        guard catalogue.contains(produit) else {
            throw ErreurDeBoutique.produitIntrouvable(identifiant: produit.identifiant)
        }

        let transaction = fabriquer(pour: produit)

        switch VerificationDeTransaction.verdict(
            pour: transaction,
            signatureValide: comportement != .signatureInvalide
        ) {
        case let .verifiee(verifiee):
            transactions.append(verifiee)
            prochainIdentifiant += 1

            return .reussi(verifiee)

        case let .refusee(motif):
            throw ErreurDeBoutique.transactionNonVerifiee(motif: motif)
        }
    }

    func restaurer() async throws -> ResultatDeRestauration {
        guard comportement != .injoignable else {
            throw ErreurDeBoutique.boutiqueInjoignable
        }

        let verdicts = compte.map { transaction in
            VerificationDeTransaction.verdict(
                pour: transaction,
                signatureValide: comportement != .signatureInvalide
            )
        }

        let resultat = RestaurationDesAchats.resultat(pour: verdicts, le: maintenant)
        transactions = resultat.transactions

        return resultat
    }

    func etatCourant() async -> EtatDePremium {
        CalculDeLEtatDePremium.etat(pour: transactions, le: maintenant)
    }

    /// Vrai quand l essai est encore ouvert sur ce compte.
    func essaiDisponible() async -> Bool {
        EssaiPremium.estEligible(historique: compte)
    }

    // MARK: Interieur

    /// La meme transaction, revoquee a l instant courant.
    private func revoquee(_ transaction: TransactionPremium) -> TransactionPremium {
        TransactionPremium(
            identifiant: transaction.identifiant,
            identifiantDeProduit: transaction.identifiantDeProduit,
            genre: transaction.genre,
            acheteeLe: transaction.acheteeLe,
            expireLe: transaction.expireLe,
            revoqueeLe: maintenant,
            estUneOffreDEssai: transaction.estUneOffreDEssai
        )
    }

    /// Transaction telle que la boutique la rendrait pour cet achat.
    private func fabriquer(pour produit: ProduitPremium) -> TransactionPremium {
        let identifiant = prochainIdentifiant

        if let essai = produit.essai, EssaiPremium.estEligible(historique: compte) {
            let transaction = TransactionPremium(
                identifiant: identifiant,
                identifiantDeProduit: produit.identifiant,
                genre: produit.genre,
                acheteeLe: maintenant,
                expireLe: essai.fin(depuis: maintenant, calendrier: calendrier),
                estUneOffreDEssai: true
            )
            compte.append(transaction)

            return transaction
        }

        let transaction = TransactionPremium(
            identifiant: identifiant,
            identifiantDeProduit: produit.identifiant,
            genre: produit.genre,
            acheteeLe: maintenant,
            expireLe: echeance(de: produit.genre)
        )
        compte.append(transaction)

        return transaction
    }

    /// Echeance d un abonnement, nulle pour un achat definitif.
    private func echeance(de genre: GenreDeProduitPremium) -> Date? {
        switch genre {
        case .mensuel:
            calendrier.date(byAdding: .month, value: 1, to: maintenant)
        case .annuel:
            calendrier.date(byAdding: .year, value: 1, to: maintenant)
        case .definitif:
            nil
        }
    }
}
