import Foundation

//
// ErreurDeSuivi
//
// Ce qui peut mal tourner entre l application et un service de suivi.
//
// Le domaine est separe d `ErreurReseau` parce que les deux se reparent
// differemment. Une panne de transport se retente, un refus d autorisation
// non : il demande a l utilisateur de recommencer la connexion, ou de
// corriger une liaison. Les melanger produirait un ecran qui propose de
// reessayer la ou reessayer ne peut rien donner.
//
// Aucun cas ne porte de jeton, de mot de passe ni de titre de serie. La regle
// de journalisation de la section 11 interdit d ecrire un identifiant, et ces
// erreurs finissent dans le journal autant que dans la vue.
//

/// Ce qui peut mal tourner du cote d un service de suivi.
public enum ErreurDeSuivi: Error, Sendable, Equatable, Hashable {
    /// La version installee ne porte pas les cles de ce service.
    case serviceNonConfigure(service: ServiceDeSuivi)

    /// L utilisateur a referme la page d autorisation sans autoriser.
    case autorisationAbandonnee(service: ServiceDeSuivi)

    /// Le service a refuse la demande d autorisation.
    ///
    /// Le motif est celui que la norme fait porter a la redirection, un mot
    /// court comme `access_denied`. Il ne designe ni le compte ni l appareil.
    case autorisationRefusee(service: ServiceDeSuivi, motif: String)

    /// La redirection ne porte pas l etat envoye avec la demande.
    ///
    /// C est la protection contre une redirection fabriquee par un tiers. Elle
    /// est traitee comme une attaque, pas comme une panne : la connexion est
    /// abandonnee sans nouvel essai automatique.
    case etatDeRedirectionInattendu(service: ServiceDeSuivi)

    /// Le service a repondu autre chose qu un jeton exploitable.
    case reponseIllisible(service: ServiceDeSuivi)

    /// L operation demande une connexion que ce service n a pas.
    case serviceDeconnecte(service: ServiceDeSuivi)

    /// Le jeton a expire et le service n en emet pas de renouvellement.
    case reconnexionNecessaire(service: ServiceDeSuivi)

    /// La serie locale n est liee a aucune entree de ce service.
    case liaisonAbsente(service: ServiceDeSuivi)

    /// Service concerne par l erreur.
    public var service: ServiceDeSuivi {
        switch self {
        case let .serviceNonConfigure(service),
             let .autorisationAbandonnee(service),
             let .autorisationRefusee(service, _),
             let .etatDeRedirectionInattendu(service),
             let .reponseIllisible(service),
             let .serviceDeconnecte(service),
             let .reconnexionNecessaire(service),
             let .liaisonAbsente(service):
            service
        }
    }

    /// Message destine a l utilisateur, qui nomme la cause et indique la sortie.
    ///
    /// Le nom du service y figure : c est celui que l utilisateur a choisi de
    /// connecter, il l attend dans le message, et ce n est pas une donnee
    /// personnelle.
    public var messageUtilisateur: String {
        let nom = service.descriptif.nomDuDocument

        switch self {
        case .serviceNonConfigure:
            return "Cette version de l application ne peut pas se connecter a \(nom)."
                + " Choisis un autre service de suivi."
        case .autorisationAbandonnee:
            return "La connexion a \(nom) a ete abandonnee."
                + " Relance la depuis la ligne du service."
        case let .autorisationRefusee(_, motif):
            return "\(nom) a refuse la connexion (\(motif))."
                + " Verifie que le compte existe encore, puis relance la connexion."
        case .etatDeRedirectionInattendu:
            return "La reponse de \(nom) ne correspond pas a la demande envoyee."
                + " La connexion a ete interrompue par securite, relance la."
        case .reponseIllisible:
            return "\(nom) a repondu quelque chose d inattendu."
                + " Reessaie dans un moment."
        case .serviceDeconnecte:
            return "Aucun compte \(nom) n est connecte."
                + " Connecte toi au service avant de lier une serie."
        case .reconnexionNecessaire:
            return "La session \(nom) a expire."
                + " Connecte toi a nouveau au service."
        case .liaisonAbsente:
            return "Cette serie n est liee a aucune entree sur \(nom)."
                + " Lie la depuis sa fiche avant d envoyer la progression."
        }
    }

    /// Code court pour le journal, sans donnee personnelle.
    public var codeDeJournal: String {
        let famille = switch self {
        case .serviceNonConfigure: "non-configure"
        case .autorisationAbandonnee: "abandonnee"
        case .autorisationRefusee: "refusee"
        case .etatDeRedirectionInattendu: "etat-inattendu"
        case .reponseIllisible: "reponse-illisible"
        case .serviceDeconnecte: "deconnecte"
        case .reconnexionNecessaire: "reconnexion"
        case .liaisonAbsente: "liaison-absente"
        }

        return "suivi.\(service.rawValue).\(famille)"
    }
}
