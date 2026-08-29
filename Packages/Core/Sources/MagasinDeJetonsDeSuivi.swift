import Foundation

//
// MagasinDeJetonsDeSuivi
//
// Ou vivent les jetons des services de suivi. Une seule reponse possible, le
// trousseau, et un seul contrat pour y arriver.
//
// Le protocole est distinct de `MagasinDIdentifiants` alors que les deux
// rangent la meme chose au meme endroit. La raison est la cle. Les identifiants
// de source sont ranges sous l identifiant de la source, qui est un UUID tire
// au moment ou l utilisateur ajoute la source. Un service de suivi n est pas
// une source : il n en existe que quatre, ils ne s ajoutent pas, et leur cle est
// leur nom. Faire passer les quatre par `SourceID` demanderait d inventer quatre
// UUID stables, de les persister quelque part, et de les retrouver au prochain
// lancement. La cle est deja stable, c est la valeur brute de l enumeration.
//
// La charge rangee est `IdentifiantsDeSource`, elle, reutilisee telle quelle.
// Elle porte deja le cas `jeton` avec son rafraichissement et son echeance,
// elle est deja privee de `Codable` pour ne pas pouvoir atterrir ailleurs que
// dans le trousseau, et elle est deja caviardee a l affichage. La recopier sous
// un autre nom rouvrirait ces trois garanties une par une.
//

/// Ou vivent les jetons des services de suivi.
///
/// L implementation livree est `TrousseauDesSuivis`. Les tests en fournissent
/// une autre, en memoire, parce qu un binaire de test non signe ne dispose
/// d aucun droit de trousseau.
public protocol MagasinDeJetonsDeSuivi: Sendable {
    /// Range le jeton d un service, en remplacant celui qui y etait.
    ///
    /// Enregistrer `IdentifiantsDeSource.aucun` efface la ligne : c est
    /// exactement ce que fait une deconnexion, et la lui faire passer par la
    /// suppression evite deux chemins pour un seul effet.
    func enregistrer(_ identifiants: IdentifiantsDeSource, pour service: ServiceDeSuivi) async throws

    /// Relit le jeton d un service.
    ///
    /// Rend `IdentifiantsDeSource.aucun` quand le service n est pas connecte,
    /// ce qui est un etat normal et non une erreur.
    func identifiants(pour service: ServiceDeSuivi) async throws -> IdentifiantsDeSource

    /// Efface le jeton d un service.
    ///
    /// Ne leve pas quand il n y en avait pas : la deconnexion est idempotente,
    /// et une purge de tous les services passe par les quatre sans savoir
    /// lesquels etaient connectes.
    func supprimer(pour service: ServiceDeSuivi) async throws
}

extension MagasinDeJetonsDeSuivi {
    /// Efface les jetons des quatre services.
    ///
    /// Sert a la remise a zero de l application et a la fin d un abonnement
    /// refuse : ce qui n a plus le droit de partir n a plus de raison d etre
    /// garde.
    public func toutSupprimer() async throws {
        for service in ServiceDeSuivi.allCases {
            try await supprimer(pour: service)
        }
    }
}

/// Range les jetons des services de suivi dans le trousseau du systeme.
///
/// Chaque service occupe une ligne de classe mot de passe generique, accessible
/// apres premier deverrouillage, comme l impose la section 11. Les lignes sont
/// rangees sous un service de trousseau distinct de celui des sources, pour
/// qu une purge des sources n emporte pas les connexions de suivi, et
/// reciproquement.
public struct TrousseauDesSuivis: MagasinDeJetonsDeSuivi {
    private let requetes: RequeteDeTrousseau

    public init(requetes: RequeteDeTrousseau = RequeteDeTrousseau(service: RequeteDeTrousseau.serviceDesSuivis)) {
        self.requetes = requetes
    }

    public func enregistrer(_ identifiants: IdentifiantsDeSource, pour service: ServiceDeSuivi) throws {
        try LigneDeTrousseau(requetes: requetes, cle: Self.cle(de: service)).ecrire(identifiants)
    }

    public func identifiants(pour service: ServiceDeSuivi) throws -> IdentifiantsDeSource {
        try LigneDeTrousseau(requetes: requetes, cle: Self.cle(de: service)).lire()
    }

    public func supprimer(pour service: ServiceDeSuivi) throws {
        try LigneDeTrousseau(requetes: requetes, cle: Self.cle(de: service)).effacer()
    }

    /// Cle de la ligne de trousseau d un service.
    ///
    /// La valeur brute de l enumeration, prefixee pour qu une ligne de suivi ne
    /// puisse jamais etre confondue avec autre chose si les deux services de
    /// trousseau venaient a etre fusionnes un jour.
    static func cle(de service: ServiceDeSuivi) -> String {
        "suivi." + service.rawValue
    }
}

/// Jetons volatils, pour les tests et les apercus.
///
/// Rien de ce qui y est ecrit ne survit au processus, pour la meme raison que
/// `MagasinDIdentifiantsEnMemoire` : un binaire de test lance par SwiftPM n est
/// pas signe et ne porte aucun droit de trousseau.
public actor MagasinDeJetonsDeSuiviEnMemoire: MagasinDeJetonsDeSuivi {
    private var lignes: [ServiceDeSuivi: IdentifiantsDeSource] = [:]

    public init() {}

    /// Les services qui portent une ligne, pour les verifications.
    public var servicesConnus: Set<ServiceDeSuivi> {
        Set(lignes.keys)
    }

    public func enregistrer(_ identifiants: IdentifiantsDeSource, pour service: ServiceDeSuivi) {
        guard identifiants.estVide == false else {
            lignes[service] = nil

            return
        }

        lignes[service] = identifiants
    }

    public func identifiants(pour service: ServiceDeSuivi) -> IdentifiantsDeSource {
        lignes[service] ?? .aucun
    }

    public func supprimer(pour service: ServiceDeSuivi) {
        lignes[service] = nil
    }
}
