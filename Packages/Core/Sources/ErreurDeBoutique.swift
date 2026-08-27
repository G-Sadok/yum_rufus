import Foundation

//
// ErreurDeBoutique
//
// Erreurs de la couche achat. Comme pour `ErreurDeSource`, chaque cas nomme la
// cause et indique la sortie, et aucune erreur opaque du systeme ne remonte
// jusqu a la vue.
//
// Ces messages ne sont pas ceux du mur premium. Le mur porte le texte exact du
// tableau 6.4, pris dans le catalogue de chaines, parce que c est un ecran
// dessine. Ceux d ici servent aux journaux et aux surfaces qui n ont pas de texte
// propre, exactement comme pour les sources.
//
// Aucun de ces messages ne nomme un identifiant de compte, un jeton, ni un
// numero de transaction. La regle de journalisation de la section 11 vaut ici
// comme ailleurs.
//

/// Ce qui peut mal tourner quand la boutique est interrogee.
public enum ErreurDeBoutique: Error, Sendable, Equatable {
    /// La boutique n a pas repondu, ou l appareil n a pas de reseau.
    case boutiqueInjoignable

    /// La boutique ne connait pas ce produit.
    ///
    /// En production, c est une erreur de configuration de la fiche produit. En
    /// developpement, c est un fichier de configuration StoreKit absent du
    /// schema.
    case produitIntrouvable(identifiant: String)

    /// La transaction n a pas passe la verification, avec sa cause.
    case transactionNonVerifiee(motif: MotifDeRefusDeTransaction)

    /// La boutique a refuse l achat.
    case achatRefuse

    /// Echec qu aucun cas ne nomme, ce qui est toujours un defaut a corriger.
    ///
    /// La raison ne porte que le nom du type d erreur, jamais sa description :
    /// celle du systeme peut contenir un identifiant de compte.
    case echecInattendu(raison: String)

    /// Message destine a l utilisateur, qui nomme la cause et indique la sortie.
    public var messageUtilisateur: String {
        switch self {
        case .boutiqueInjoignable:
            "La boutique ne repond pas."
                + " Votre abonnement actuel, s il existe, reste actif. Reessayez dans un moment."
        case .produitIntrouvable:
            "Cette offre n est pas disponible sur ce compte."
                + " Verifiez la region de votre compte, puis reessayez."
        case let .transactionNonVerifiee(motif):
            Self.explication(de: motif)
        case .achatRefuse:
            "La boutique a refuse le paiement."
                + " Verifiez votre moyen de paiement dans les reglages du systeme."
        case .echecInattendu:
            "L achat a echoue pour une raison que l application ne sait pas nommer."
                + " Reessayez, et signalez le probleme si il se repete."
        }
    }

    /// Identifiant stable pour le journal, sans aucune donnee personnelle.
    public var codeDeJournal: String {
        switch self {
        case .boutiqueInjoignable: "boutique.injoignable"
        case .produitIntrouvable: "boutique.produitIntrouvable"
        case let .transactionNonVerifiee(motif): "boutique.nonVerifiee.\(motif.rawValue)"
        case .achatRefuse: "boutique.achatRefuse"
        case let .echecInattendu(raison): "boutique.echecInattendu.\(raison)"
        }
    }

    /// Traduit une erreur quelconque levee par la couche achat.
    ///
    /// Une erreur deja typee traverse sans etre deguisee, et ce qui reste devient
    /// `echecInattendu` avec le seul nom de son type.
    public static func depuis(_ erreur: any Error) -> ErreurDeBoutique {
        if let deja = erreur as? ErreurDeBoutique {
            return deja
        }

        return .echecInattendu(raison: String(describing: type(of: erreur)))
    }

    /// Phrase d un refus de verification.
    private static func explication(de motif: MotifDeRefusDeTransaction) -> String {
        switch motif {
        case .signatureInvalide:
            "Cet achat n a pas pu etre authentifie par la boutique."
                + " Restaurez vos achats, ou reessayez plus tard."
        case .produitInconnu:
            "Cet achat ne correspond a aucune offre de cette application."
                + " Restaurez vos achats pour retrouver votre abonnement."
        case .applicationDifferente:
            "Cet achat a ete fait dans une autre application."
                + " Restaurez vos achats depuis le compte qui a souscrit."
        }
    }
}
