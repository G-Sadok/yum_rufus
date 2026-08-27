import Foundation

//
// ProtocoleDeBoutique
//
// La frontiere entre le produit et StoreKit.
//
// Tout ce qui parle a la boutique du systeme se tient derriere ce protocole.
// L implementation reelle vit dans la couche application, seule a importer
// StoreKit, et une implementation de test rejoue les memes parcours sans reseau
// ni compte de test. Les regles, elles, restent ici, ou elles se verifient.
//
// Le protocole ne rend jamais une transaction brute. Il rend ce que
// l application peut utiliser : des produits, un resultat d achat, un etat. Une
// transaction qui n a pas passe la verification ne franchit pas cette frontiere.
//

/// Ce qu un achat a produit.
public enum ResultatDAchat: Sendable, Equatable {
    /// La transaction est passee et a ete verifiee.
    case reussi(TransactionPremium)

    /// La boutique attend une validation exterieure, celle d un parent par
    /// exemple. Rien n est ouvert pour l instant, et rien n est perdu.
    case enAttenteDeValidation

    /// L utilisateur a referme la feuille de paiement.
    ///
    /// Ce n est pas une erreur et l ecran ne dit rien. Un renoncement suivi d un
    /// message d echec se lit comme une insistance.
    case annuleParLUtilisateur
}

/// Acces a la boutique du systeme.
public protocol Boutique: Sendable {
    /// Produits Premium, tels que la boutique les tarife pour ce compte.
    func produits() async throws -> [ProduitPremium]

    /// Lance l achat d un produit et rend ce qu il a produit.
    func acheter(_ produit: ProduitPremium) async throws -> ResultatDAchat

    /// Relit le compte et recalcule l etat, sans rien acheter.
    func restaurer() async throws -> ResultatDeRestauration

    /// Etat courant, calcule depuis les transactions que la boutique garde.
    func etatCourant() async -> EtatDePremium

    /// Vrai quand l essai peut encore etre propose sur ce compte.
    ///
    /// La question se pose a la boutique et non a l historique local : un compte
    /// qui a deja essaye sur un autre appareil n a pas droit a une seconde
    /// periode gratuite, et l appareil courant peut n en rien savoir.
    func essaiDisponible() async -> Bool
}
