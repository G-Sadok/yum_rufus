import Foundation

//
// ConnexionDeSuivi
//
// L etat de connexion des quatre services, et ce que connecter et deconnecter
// veulent dire exactement.
//
// Le premier critere de la fonctionnalite tient en un mot, proprement. Il ne
// se verifie pas sur un booleen. Une connexion propre veut dire que le compte
// est connu et que le jeton est range dans le trousseau. Une deconnexion propre
// veut dire l inverse, et surtout qu il ne reste rien : ni jeton, ni compte
// affiche, ni liaison qui continuerait d envoyer. C est cette derniere partie
// qui se rate le plus souvent, parce qu elle demande d effacer a trois endroits
// alors que connecter n en demandait qu un.
//
// L etat vit ici, en valeur, et non dans un acteur : l ecran des reglages le
// lit a chaque affichage, la synchronisation le lit avant chaque envoi, et une
// valeur se copie sans attendre personne.
//

/// Le compte connecte chez un service, tel que le service le nomme.
///
/// L identifiant est conserve parce que deux services sur quatre en ont besoin
/// pour publier : la mise a jour d une entree de bibliotheque y est rangee sous
/// le compte, pas sous la serie seule.
public struct CompteDeSuivi: Sendable, Hashable, Codable {
    /// Identifiant du compte chez le service.
    public let identifiant: String

    /// Nom affiche du compte, celui que l utilisateur reconnait.
    public let pseudonyme: String

    public init(identifiant: String, pseudonyme: String) {
        self.identifiant = identifiant
        self.pseudonyme = pseudonyme
    }
}

/// Etat de connexion d un service.
public enum EtatDeConnexionDeSuivi: Sendable, Hashable {
    /// Aucun compte connecte.
    case deconnecte

    /// Un compte est connecte et son jeton vaut encore.
    case connecte(CompteDeSuivi)

    /// Le compte est connu mais son jeton ne vaut plus.
    ///
    /// L etat existe separement de `deconnecte` parce que les deux ne se
    /// reparent pas pareil. Un service expire garde ses liaisons et demande une
    /// reconnexion ; un service deconnecte n a plus rien a reconnecter.
    case expire(CompteDeSuivi)

    /// Vrai quand le service peut recevoir une progression.
    public var peutEnvoyer: Bool {
        switch self {
        case .connecte: true
        case .deconnecte, .expire: false
        }
    }

    /// Compte connu, meme quand le jeton a expire.
    public var compte: CompteDeSuivi? {
        switch self {
        case .deconnecte: nil
        case let .connecte(compte), let .expire(compte): compte
        }
    }
}

/// Etat de connexion des quatre services, tel que l ecran des reglages le lit.
public struct EtatDesSuivis: Sendable, Hashable {
    private var etats: [ServiceDeSuivi: EtatDeConnexionDeSuivi]

    public init(_ etats: [ServiceDeSuivi: EtatDeConnexionDeSuivi] = [:]) {
        self.etats = etats
    }

    /// Aucun service connecte, l etat d une installation neuve.
    public static let aucun = EtatDesSuivis()

    /// Etat de ce service, deconnecte quand rien n a jamais ete connecte.
    public subscript(service: ServiceDeSuivi) -> EtatDeConnexionDeSuivi {
        etats[service] ?? .deconnecte
    }

    /// Enregistre la connexion d un compte a ce service.
    public mutating func connecter(_ service: ServiceDeSuivi, compte: CompteDeSuivi) {
        etats[service] = .connecte(compte)
    }

    /// Marque le jeton de ce service comme perime, sans oublier le compte.
    ///
    /// Ne fait rien quand aucun compte n est connu : un service jamais connecte
    /// ne peut pas expirer, et lui inventer un compte vide afficherait une
    /// ligne a reconnecter la ou il n y a jamais rien eu.
    public mutating func marquerExpire(_ service: ServiceDeSuivi) {
        guard let compte = self[service].compte else {
            return
        }

        etats[service] = .expire(compte)
    }

    /// Efface toute trace de connexion a ce service.
    ///
    /// L entree est retiree plutot que remise a `deconnecte`. Les deux se lisent
    /// pareil, mais une table qui se vide vraiment rend le premier critere
    /// verifiable : il suffit de comparer la table a la table vide.
    public mutating func deconnecter(_ service: ServiceDeSuivi) {
        etats[service] = nil
    }

    /// Services dont un compte est connecte et utilisable.
    public var servicesConnectes: [ServiceDeSuivi] {
        ServiceDeSuivi.allCases.filter { self[$0].peutEnvoyer }
    }

    /// Services dont la session a expire et qui attendent une reconnexion.
    public var servicesExpires: [ServiceDeSuivi] {
        ServiceDeSuivi.allCases.filter {
            if case .expire = self[$0] {
                return true
            }

            return false
        }
    }

    /// Nombre de services connectes, celui que la ligne des reglages affiche.
    public var nombreDeServicesConnectes: Int {
        servicesConnectes.count
    }

    /// Vrai quand plus aucun service ne porte d etat.
    public var estVide: Bool {
        etats.isEmpty
    }
}
