import Foundation

//
// DepotDExtensions
//
// Le depot d extensions du tableau 4.2 : un manifeste JSON servi en HTTPS, qui
// annonce la liste des extensions installables.
//
// Le catalogue d un depot ne porte aucune regle. Il ne porte que de quoi
// afficher une liste et aller chercher un paquet. Les regles arrivent avec le
// paquet signe, et sont relues par `ManifesteDExtension.lire(_:)` a ce moment
// la. Un depot ne peut donc pas faire installer autre chose que ce que sa
// propre entree annonce sans que la signature le dise.
//
// Les domaines figurent quand meme dans l entree, et ce n est pas une
// duplication inutile : ils permettent d afficher la liste dans l ecran de
// depot, avant meme de telecharger le paquet. Ils ne font autorite pour rien.
// Ceux qui comptent sont ceux du manifeste signe, et c est sur ceux la que
// porte la confirmation.
//

/// Une extension telle qu un depot l annonce.
public struct EntreeDeDepot: Sendable, Hashable, Codable {
    public let identifiant: String
    public let nom: String
    public let version: VersionDExtension

    /// Langue du catalogue, au format BCP 47.
    public let langue: String

    /// Phrase de presentation, quand le depot en publie une.
    public let resume: String?

    /// Adresse du paquet signe.
    public let paquet: URL

    /// Domaines annonces, a titre indicatif, pour l affichage de la liste.
    public let domaines: [DomaineAutorise]

    public init(
        identifiant: String,
        nom: String,
        version: VersionDExtension,
        langue: String,
        resume: String? = nil,
        paquet: URL,
        domaines: [DomaineAutorise] = []
    ) {
        self.identifiant = identifiant
        self.nom = nom
        self.version = version
        self.langue = langue
        self.resume = resume
        self.paquet = paquet
        self.domaines = domaines
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case identifiant
        case nom
        case version
        case langue
        case resume
        case paquet
        case domaines
    }

    /// Lit une entree, en tolerant l absence de ce qui n est qu indicatif.
    ///
    /// Le resume et les domaines sont facultatifs : le premier est une phrase
    /// de presentation, le second ne fait autorite pour rien, seul le manifeste
    /// signe compte. Les exiger ferait tomber tout le catalogue d un depot qui
    /// ne les publie pas.
    public init(from decodeur: any Decoder) throws {
        let conteneur = try decodeur.container(keyedBy: CodingKeys.self)

        identifiant = try conteneur.decode(String.self, forKey: .identifiant)
        nom = try conteneur.decode(String.self, forKey: .nom)
        version = try conteneur.decode(VersionDExtension.self, forKey: .version)
        langue = try conteneur.decode(String.self, forKey: .langue)
        resume = try conteneur.decodeIfPresent(String.self, forKey: .resume)
        paquet = try conteneur.decode(URL.self, forKey: .paquet)
        domaines = try conteneur.decodeIfPresent([DomaineAutorise].self, forKey: .domaines) ?? []
    }

    /// Vrai quand l entree est utilisable, c est a dire installable.
    ///
    /// Une adresse de paquet en clair fait ecarter l entree plutot que tomber
    /// le catalogue entier : un depot qui publie une entree mal formee ne doit
    /// pas rendre les autres inaccessibles.
    public var estUtilisable: Bool {
        ManifesteDExtension.identifiantEstUtilisable(identifiant)
            && nom.isEmpty == false
            && paquet.scheme?.lowercased() == "https"
    }
}

/// Le catalogue publie par un depot.
public struct CatalogueDeDepot: Sendable, Hashable, Codable {
    /// Version du format de catalogue.
    public let format: Int

    /// Nom du depot, tel qu il s affiche en tete de l ecran.
    public let nom: String

    /// Les extensions annoncees.
    public let extensions: [EntreeDeDepot]

    public init(format: Int = CatalogueDeDepot.versionDeFormatAppliquee, nom: String, extensions: [EntreeDeDepot]) {
        self.format = format
        self.nom = nom
        self.extensions = extensions
    }

    /// Version du format de catalogue que l application lit.
    public static let versionDeFormatAppliquee = 1

    enum CodingKeys: String, CodingKey, CaseIterable {
        case format
        case nom
        case extensions
    }

    public init(from decodeur: any Decoder) throws {
        let conteneur = try decodeur.container(keyedBy: CodingKeys.self)

        format = try conteneur.decodeIfPresent(Int.self, forKey: .format) ?? Self.versionDeFormatAppliquee
        nom = try conteneur.decode(String.self, forKey: .nom)
        extensions = try conteneur.decodeIfPresent([EntreeDeDepot].self, forKey: .extensions) ?? []
    }

    /// Lit un catalogue depuis les octets servis par le depot.
    ///
    /// Les entrees inutilisables sont ecartees et non refusees. Voir
    /// `EntreeDeDepot.estUtilisable`.
    ///
    /// - Throws: `ErreurDExtension.manifesteIllisible` quand le document ne se
    ///   decode pas, et `.formatNonPrisEnCharge` quand il annonce une version
    ///   plus recente.
    public static func lire(_ donnees: Data) throws -> CatalogueDeDepot {
        guard let lu = try? JSONDecoder().decode(CatalogueDeDepot.self, from: donnees) else {
            throw ErreurDExtension.manifesteIllisible
        }
        guard lu.format == versionDeFormatAppliquee else {
            throw ErreurDExtension.formatNonPrisEnCharge(
                annoncee: lu.format,
                appliquee: versionDeFormatAppliquee
            )
        }

        return CatalogueDeDepot(
            format: lu.format,
            nom: lu.nom,
            extensions: lu.extensions.filter(\.estUtilisable)
        )
    }
}

/// Un depot configure par l utilisateur.
public struct DepotConfigure: Sendable, Hashable, Codable {
    public let adresse: URL

    /// Nom lu dans le catalogue, ou l hote tant qu il n a pas ete lu.
    public let nom: String

    /// Construit un depot, en refusant une adresse en clair.
    ///
    /// - Throws: `ErreurReseau.transportNonChiffre` quand l adresse n est pas
    ///   en HTTPS. Aucune exception locale n est possible, pour la raison deja
    ///   ecrite dans `ListeBlancheDeDomaines.autorise(_:)`.
    public init(adresse: URL, nom: String? = nil) throws {
        guard adresse.scheme?.lowercased() == "https", let hote = adresse.host() else {
            throw ErreurReseau.transportNonChiffre
        }

        self.adresse = adresse
        self.nom = nom ?? hote
    }
}

/// Ce qu un utilisateur doit avoir lu avant d ajouter son premier depot.
///
/// La section 4.3 le demande explicitement : au premier ajout d un depot,
/// l utilisateur est averti qu il est responsable de la legalite des contenus
/// auxquels il accede. Le rappel n est pas rejoue a chaque ajout, il l a lu.
public struct AvertissementDeDepot: Sendable, Hashable {
    /// Vrai quand aucun depot n avait encore ete ajoute.
    public let estLePremierDepot: Bool

    /// Hote du depot, ce que l utilisateur voit avant de decider.
    public let hote: String

    public init(estLePremierDepot: Bool, hote: String) {
        self.estLePremierDepot = estLePremierDepot
        self.hote = hote
    }

    /// Construit l avertissement pour ce depot, connaissant ceux deja ajoutes.
    public init(depot: DepotConfigure, depotsDejaAjoutes: Int) {
        estLePremierDepot = depotsDejaAjoutes == 0
        hote = depot.adresse.host() ?? depot.nom
    }

    /// Vrai quand la mention de responsabilite doit etre affichee.
    public var afficheLaResponsabilite: Bool {
        estLePremierDepot
    }
}
