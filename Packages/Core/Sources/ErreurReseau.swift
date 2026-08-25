import Foundation

//
// ErreurReseau
//
// Les pannes de transport d une source distante, typees et fermees. Une source
// qui parle a un serveur ne laisse jamais remonter un `URLError` ni un code
// HTTP brut : elle traduit ici, une fois, et la vue n a plus qu un message a
// afficher.
//
// Aucun cas ne porte d adresse de serveur. La regle de journalisation de la
// section 11 interdit d ecrire une adresse d hote, et ces erreurs finissent
// dans le journal autant que dans la vue. Le nom de la source, que
// l utilisateur a choisi lui meme, suffit a designer le coupable, et c est
// `ErreurDeSource` qui le porte. Le seul domaine nomme est celui qu une
// extension a tente d atteindre hors de sa liste blanche, parce que c est
// exactement ce que l utilisateur doit voir avant de decider.
//

/// Ce qui peut mal tourner sur le transport d une source distante.
///
/// Chaque cas nomme la cause et indique la sortie, comme `ErreurDeDocument` et
/// `ErreurDeSource`. Les cas se rangent en deux familles : ce qui empeche
/// d atteindre le serveur, et ce que le serveur a repondu de travers.
public enum ErreurReseau: Error, Sendable, Equatable, Hashable {
    // MARK: Atteindre le serveur

    /// L appareil n a aucune connexion utilisable.
    case horsLigne

    /// Le serveur n a rien renvoye dans le delai accorde.
    case delaiDepasse

    /// Le nom du serveur ne se resout pas.
    case serveurIntrouvable

    /// Le nom se resout mais rien n ecoute a l autre bout.
    case connexionRefusee

    /// Le certificat du serveur a ete refuse : expire, auto signe, ou emis par
    /// une autorite inconnue.
    case certificatRefuse

    /// L adresse est en clair alors que le transport chiffre est exige.
    case transportNonChiffre

    /// Une extension a tente d atteindre un domaine absent de sa liste blanche.
    ///
    /// Ce n est pas une panne mais un refus de securite, et le domaine est
    /// nomme parce que l utilisateur doit savoir ce que l extension a cherche a
    /// joindre.
    case domaineNonAutorise(domaine: String)

    /// La requete a ete annulee, par l utilisateur ou par la couche appelante.
    case annulee

    /// Panne de transport que la traduction ne sait pas nommer plus precisement.
    ///
    /// Le code est celui de `URLError.Code`, conserve pour le diagnostic. Il
    /// n identifie ni l utilisateur ni le serveur.
    case echecDeTransport(code: Int)

    // MARK: Ce que le serveur a repondu

    /// Le serveur a refuse les identifiants fournis.
    case authentificationRefusee

    /// Les identifiants sont bons mais le compte n a pas le droit demande.
    case accesRefuse

    /// Le serveur ne connait pas ce que la requete demandait.
    case ressourceIntrouvable

    /// Le serveur demande de ralentir.
    ///
    /// Le delai vient de l en tete `Retry-After` quand le serveur en envoie un.
    case tropDeRequetes(secondesAvantNouvelEssai: Int?)

    /// Le serveur est en panne de son cote, temporairement.
    case pannePassagere(code: Int)

    /// Le serveur a repondu un code que la source ne sait pas interpreter.
    case reponseInattendue(code: Int)

    /// La reponse est arrivee entiere mais ne se decode pas.
    case reponseIllisible

    /// La reponse est vide alors qu elle devait porter des donnees.
    case reponseVide

    /// La reponse s arrete avant la taille qu elle annonce.
    case reponseTronquee

    // MARK: Traduction

    /// Message destine a l utilisateur, qui nomme la cause et indique la sortie.
    ///
    /// Il ne nomme pas la source : c est `ErreurDeSource.reseau` qui la place en
    /// tete, parce qu une meme panne de transport peut frapper n importe
    /// laquelle et que le message n a pas a etre duplique par source.
    public var messageUtilisateur: String {
        switch self {
        case .horsLigne:
            "L appareil n est connecte a aucun reseau."
                + " Retablis la connexion, puis relance la verification."
        case .delaiDepasse:
            "Le serveur n a pas repondu dans le delai accorde."
                + " Verifie qu il est allume et joignable, puis reessaie."
        case .serveurIntrouvable:
            "Le nom du serveur ne correspond a aucune machine."
                + " Corrige l adresse dans la configuration de la source."
        case .connexionRefusee:
            "Le serveur existe mais refuse la connexion."
                + " Verifie le port et que le service est demarre."
        case .certificatRefuse:
            "Le certificat du serveur a ete refuse."
                + " Renouvelle le, ou passe par une adresse dont le certificat est valide."
        case .transportNonChiffre:
            "Cette adresse n est pas chiffree."
                + " Passe l adresse en HTTPS pour que les identifiants ne circulent pas en clair."
        case let .domaineNonAutorise(domaine):
            "L extension a tente de joindre \(domaine), qui ne figure pas dans sa liste de domaines."
                + " La requete a ete bloquee. Desinstalle l extension si ce domaine te surprend."
        case .annulee:
            "La requete a ete interrompue."
                + " Relance la si le resultat t interesse toujours."
        case .echecDeTransport:
            "La connexion au serveur a echoue."
                + " Verifie le reseau et l adresse de la source, puis reessaie."
        case .authentificationRefusee:
            "Le serveur a refuse les identifiants."
                + " Corrige les dans la configuration de la source."
        case .accesRefuse:
            "Ce compte n a pas le droit d acceder a ce contenu."
                + " Demande l autorisation a l administrateur du serveur."
        case .ressourceIntrouvable:
            "Le serveur ne connait pas ce que la source lui a demande."
                + " Actualise la source, le contenu a sans doute ete supprime."
        case let .tropDeRequetes(secondes):
            "Le serveur demande de ralentir."
                + Self.suiteDeLAttente(secondes)
        case .pannePassagere:
            "Le serveur est en panne de son cote."
                + " Reessaie dans quelques minutes."
        case let .reponseInattendue(code):
            "Le serveur a repondu un code \(code) que la source ne sait pas interpreter."
                + " Verifie que la source pointe bien vers ce type de serveur."
        case .reponseIllisible:
            "La reponse du serveur ne se decode pas."
                + " Verifie que l adresse pointe vers le bon service et non vers une page web."
        case .reponseVide:
            "Le serveur a repondu sans aucune donnee."
                + " Reessaie, et verifie la configuration de la source si cela se repete."
        case .reponseTronquee:
            "La reponse du serveur s est arretee en cours de route."
                + " Reessaie, la connexion a probablement ete coupee."
        }
    }

    /// Fin de phrase du cas `tropDeRequetes`, selon que le serveur a dit
    /// combien de temps attendre ou non.
    private static func suiteDeLAttente(_ secondes: Int?) -> String {
        guard let secondes, secondes > 0 else {
            return " Attends une minute avant de relancer."
        }

        return " Attends \(secondes) secondes avant de relancer."
    }

    /// Vrai quand relancer la meme requete a une chance d aboutir sans que
    /// l utilisateur change quoi que ce soit.
    ///
    /// Sert a la file de telechargement et a la precharge, qui reessaient les
    /// pannes passageres et abandonnent les refus definitifs. Un refus
    /// d identifiants relance a l infini serait une facon efficace de faire
    /// bloquer le compte de l utilisateur.
    public var estTemporaire: Bool {
        switch self {
        case .horsLigne, .delaiDepasse, .connexionRefusee, .tropDeRequetes,
             .pannePassagere, .reponseVide, .reponseTronquee:
            true
        default:
            false
        }
    }

    /// Etat de connexion a retenir pour la source quand cette erreur survient.
    ///
    /// La distinction compte pour l interface : une source aux identifiants
    /// invalides ouvre sa feuille de configuration, une source injoignable
    /// propose de relancer le test.
    public var etatDeConnexion: EtatConnexion {
        switch self {
        case .authentificationRefusee:
            .identifiantsInvalides
        case .horsLigne, .delaiDepasse, .serveurIntrouvable, .connexionRefusee:
            .injoignable
        default:
            .erreur
        }
    }

    /// Identifiant stable pour le journal, sans aucune donnee personnelle.
    ///
    /// Le journal ne recoit jamais `messageUtilisateur` : celui du domaine
    /// bloque nommerait un domaine. Ce code, lui, se compte et se compare sans
    /// rien reveler.
    public var codeDeJournal: String {
        switch self {
        case .horsLigne: "reseau.horsLigne"
        case .delaiDepasse: "reseau.delaiDepasse"
        case .serveurIntrouvable: "reseau.serveurIntrouvable"
        case .connexionRefusee: "reseau.connexionRefusee"
        case .certificatRefuse: "reseau.certificatRefuse"
        case .transportNonChiffre: "reseau.transportNonChiffre"
        case .domaineNonAutorise: "reseau.domaineNonAutorise"
        case .annulee: "reseau.annulee"
        case let .echecDeTransport(code): "reseau.transport.\(code)"
        case .authentificationRefusee: "reseau.authentificationRefusee"
        case .accesRefuse: "reseau.accesRefuse"
        case .ressourceIntrouvable: "reseau.ressourceIntrouvable"
        case .tropDeRequetes: "reseau.tropDeRequetes"
        case let .pannePassagere(code): "reseau.panne.\(code)"
        case let .reponseInattendue(code): "reseau.inattendue.\(code)"
        case .reponseIllisible: "reseau.reponseIllisible"
        case .reponseVide: "reseau.reponseVide"
        case .reponseTronquee: "reseau.reponseTronquee"
        }
    }
}

// MARK: - Traduction des erreurs du systeme

extension ErreurReseau {
    /// Traduit une erreur quelconque, quand elle vient du transport.
    ///
    /// Rend nul quand l erreur n a rien a voir avec le reseau, pour que
    /// l appelant garde son erreur d origine plutot que de la deguiser.
    public static func depuis(_ erreur: any Error) -> ErreurReseau? {
        if let deja = erreur as? ErreurReseau {
            return deja
        }
        if erreur is CancellationError {
            return .annulee
        }
        guard let erreurDURL = erreur as? URLError else {
            return nil
        }

        return depuis(erreurDURL)
    }

    /// Traduit une erreur d URLSession.
    ///
    /// La correspondance est une table et non une suite de `case` : elle se lit
    /// d un coup d oeil, et un code non liste tombe dans `echecDeTransport`
    /// avec son numero, ce qui vaut mieux qu un cas fourre tout muet.
    public static func depuis(_ erreur: URLError) -> ErreurReseau {
        correspondances[erreur.code] ?? .echecDeTransport(code: erreur.code.rawValue)
    }

    /// Traduit un code de statut HTTP.
    ///
    /// Rend nul pour la famille 2xx : une reponse acceptee n est pas une
    /// erreur, et rendre un cas neutre obligerait chaque appelant a le filtrer.
    public static func depuis(codeHttp code: Int, nouvelEssaiApres secondes: Int? = nil) -> ErreurReseau? {
        switch code {
        case 200..<300: nil
        case 401, 407: .authentificationRefusee
        case 403: .accesRefuse
        case 404, 410: .ressourceIntrouvable
        case 408, 504: .delaiDepasse
        case 429: .tropDeRequetes(secondesAvantNouvelEssai: secondes)
        case 500..<600: .pannePassagere(code: code)
        default: .reponseInattendue(code: code)
        }
    }

    /// Lit l en tete `Retry-After`, dans ses deux formes.
    ///
    /// La norme autorise un nombre de secondes ou une date HTTP. Les serveurs
    /// utilisent les deux, et ne traiter que la premiere ferait perdre le delai
    /// exactement chez ceux qui prennent la peine de l annoncer.
    ///
    /// - Parameter maintenant: instant de reference, passe explicitement pour
    ///   que la lecture d une date soit testable.
    public static func secondesAvantNouvelEssai(_ entete: String?, maintenant: Date) -> Int? {
        guard let entete = entete?.trimmingCharacters(in: .whitespaces), entete.isEmpty == false else {
            return nil
        }
        if let secondes = Int(entete) {
            return max(0, secondes)
        }
        guard let date = formateurDeDateHttp.date(from: entete) else {
            return nil
        }

        return max(0, Int(date.timeIntervalSince(maintenant).rounded(.up)))
    }

    /// Correspondance entre les codes d URLSession et les cas du domaine.
    private static let correspondances: [URLError.Code: ErreurReseau] = [
        .notConnectedToInternet: .horsLigne,
        .networkConnectionLost: .horsLigne,
        .dataNotAllowed: .horsLigne,
        .internationalRoamingOff: .horsLigne,
        .timedOut: .delaiDepasse,
        .cannotFindHost: .serveurIntrouvable,
        .dnsLookupFailed: .serveurIntrouvable,
        .cannotConnectToHost: .connexionRefusee,
        .resourceUnavailable: .connexionRefusee,
        .secureConnectionFailed: .certificatRefuse,
        .serverCertificateHasBadDate: .certificatRefuse,
        .serverCertificateUntrusted: .certificatRefuse,
        .serverCertificateHasUnknownRoot: .certificatRefuse,
        .serverCertificateNotYetValid: .certificatRefuse,
        .clientCertificateRejected: .certificatRefuse,
        .clientCertificateRequired: .certificatRefuse,
        .appTransportSecurityRequiresSecureConnection: .transportNonChiffre,
        .userAuthenticationRequired: .authentificationRefusee,
        .userCancelledAuthentication: .authentificationRefusee,
        .noPermissionsToReadFile: .accesRefuse,
        .fileDoesNotExist: .ressourceIntrouvable,
        .fileIsDirectory: .ressourceIntrouvable,
        .badServerResponse: .reponseIllisible,
        .cannotParseResponse: .reponseIllisible,
        .cannotDecodeContentData: .reponseIllisible,
        .cannotDecodeRawData: .reponseIllisible,
        .zeroByteResource: .reponseVide,
        .cancelled: .annulee,
    ]

    /// Lecteur des dates HTTP, au format impose par la norme.
    ///
    /// Le fuseau et la locale sont fixes : une date HTTP est toujours en GMT et
    /// en anglais, et laisser la locale de l utilisateur decider ferait echouer
    /// la lecture sur un appareil configure en francais.
    private static let formateurDeDateHttp: DateFormatter = {
        let formateur = DateFormatter()
        formateur.locale = Locale(identifier: "en_US_POSIX")
        formateur.timeZone = TimeZone(secondsFromGMT: 0)
        formateur.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"

        return formateur
    }()
}
