import Foundation

//
// SauvegardeDesSources
//
// La part sources du fichier JSON versionne de la section 10, celle dont le
// cahier de developpement dit qu elle contient la configuration des sources
// **sans les mots de passe**.
//
// La regle n est pas tenue par un filtre applique a la sortie. Un filtre se
// contourne des qu un champ est ajoute ailleurs, et personne ne le remarque
// avant la fuite. Elle est tenue par la forme : la sauvegarde ne recopie jamais
// la colonne `configurationChiffree` telle quelle. Elle la relit dans
// `ConfigurationDeSource`, un type ferme sans champ secret, et reencode ce type
// la. Tout ce que la colonne pourrait porter d autre est perdu au passage, ce
// qui est exactement l effet voulu.
//
// Les identifiants, eux, ne sont meme pas atteignables depuis ici :
// `IdentifiantsDeSource` ne conforme pas a `Codable`, et le trousseau n est pas
// interroge par ce fichier.
//

/// Une source telle qu elle figure dans une sauvegarde.
///
/// L identifiant est conserve : une restauration doit pouvoir rapprocher les
/// series exportees de leur source. Le mot de passe, lui, est a ressaisir apres
/// restauration, ce que la section 10 assume.
public struct SourceExportee: Sendable, Codable, Hashable {
    public let id: UUID
    public let type: TypeDeSource
    public let nom: String
    public let configuration: ConfigurationDeSource?
    public let versionExtension: String?
    public let langue: String?
    public let ordreAffichage: Int
    public let estActive: Bool

    /// Projette une source vers sa forme exportable.
    ///
    /// - Throws: `ErreurDeConfigurationDeSource.illisible` quand la colonne de
    ///   configuration ne se relit pas. Une sauvegarde qui recopierait des
    ///   octets qu elle ne sait pas lire serait precisement le trou que ce type
    ///   existe pour fermer, elle echoue donc plutot que de les emporter.
    public init(_ source: Source) throws {
        id = source.id
        type = source.type
        nom = source.nom
        configuration = try source.configuration()
        versionExtension = source.versionExtension
        langue = source.langue
        ordreAffichage = source.ordreAffichage
        estActive = source.estActive
    }

    /// Reconstruit une source a partir de sa forme exportee.
    ///
    /// L etat de connexion revient a `nonVerifie` et la date de derniere
    /// verification a nul : la sauvegarde ne dit rien de la joignabilite du
    /// serveur au moment de la restauration, et les identifiants sont a
    /// ressaisir de toute maniere.
    public func source() throws -> Source {
        var source = Source(
            id: id,
            type: type,
            nom: nom,
            versionExtension: versionExtension,
            langue: langue,
            ordreAffichage: ordreAffichage,
            estActive: estActive
        )

        if let configuration {
            try source.definirLaConfiguration(configuration)
        }

        return source
    }
}

/// La part sources d une sauvegarde, versionnee.
public struct SauvegardeDesSources: Sendable, Codable, Hashable {
    /// Version du format de la part sources.
    ///
    /// Elle est ecrite dans le fichier et relue a l import : une sauvegarde
    /// produite par une version anterieure doit se lire, ou se refuser en le
    /// disant, jamais se lire de travers.
    public static let versionCourante = 1

    public let version: Int
    public let sources: [SourceExportee]

    public init(version: Int = SauvegardeDesSources.versionCourante, sources: [SourceExportee]) {
        self.version = version
        self.sources = sources
    }

    /// Construit la part sources a partir des sources persistees.
    public init(_ sources: [Source]) throws {
        try self.init(sources: sources.map(SourceExportee.init))
    }

    /// Encode la part sources du fichier de sauvegarde.
    public func donnees() throws -> Data {
        let encodeur = JSONEncoder()
        encodeur.outputFormatting = [.sortedKeys]

        return try encodeur.encode(self)
    }

    /// Relit une part sources deja encodee.
    ///
    /// - Throws: `ErreurDeSauvegarde.formatInconnu` quand la version du fichier
    ///   n est pas celle que cette version de l application sait lire.
    public init(donnees: Data) throws {
        guard let relue = try? JSONDecoder().decode(SauvegardeDesSources.self, from: donnees) else {
            throw ErreurDeSauvegarde.fichierIllisible
        }

        guard relue.version == Self.versionCourante else {
            throw ErreurDeSauvegarde.formatInconnu(version: relue.version)
        }

        self = relue
    }
}

/// Ce qui peut mal tourner a la relecture d une sauvegarde.
public enum ErreurDeSauvegarde: Error, Sendable, Equatable {
    /// Le fichier ne decrit pas une sauvegarde de ce projet.
    case fichierIllisible

    /// Le fichier vient d une version que celle ci ne sait pas lire.
    case formatInconnu(version: Int)

    /// Message destine a l utilisateur, qui nomme la cause et indique la sortie.
    public var messageUtilisateur: String {
        switch self {
        case .fichierIllisible:
            "Ce fichier n est pas une sauvegarde lisible par l application."
                + " Choisis le fichier produit par la fonction Sauvegarder."
        case let .formatInconnu(version):
            "Cette sauvegarde est au format \(version), que cette version de l application ne lit pas."
                + " Mets l application a jour, puis relance la restauration."
        }
    }

    /// Identifiant stable pour le journal, sans aucune donnee personnelle.
    public var codeDeJournal: String {
        switch self {
        case .fichierIllisible: "sauvegarde.fichierIllisible"
        case let .formatInconnu(version): "sauvegarde.formatInconnu.\(version)"
        }
    }
}
