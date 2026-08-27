import Foundation

//
// SauvegardeDesPrereglages
//
// La part prereglages du fichier JSON versionne de la section 10 du cahier de
// developpement, celle dont il dit que l export inclut `la bibliotheque, les
// categories, la progression, les signets, les prereglages et la configuration
// des sources`.
//
// Comme `SauvegardeDesSources`, la sauvegarde ne recopie jamais la colonne
// telle quelle. Elle relit `donneesReglages` dans `ContenuDePrereglage`, un
// type ferme, et reencode ce type la. Un prereglage dont la colonne est abimee
// fait echouer l export au lieu d emporter des octets que personne ne sait
// relire, et un prereglage restaure est donc toujours applicable.
//

/// Un prereglage tel qu il figure dans une sauvegarde.
///
/// L identifiant est conserve : une restauration doit pouvoir reconnaitre un
/// prereglage deja present plutot que d en creer un double a chaque import.
public struct PrereglageExporte: Sendable, Codable, Hashable {
    public let id: UUID
    public let nom: String
    public let contenu: ContenuDePrereglage

    /// Projette un prereglage vers sa forme exportable.
    ///
    /// - Throws: `ErreurDePrereglage.contenuIllisible` ou `.formatInconnu`
    ///   quand la colonne ne se relit pas.
    public init(_ prereglage: PrereglageLecture) throws {
        id = prereglage.id
        nom = prereglage.nom
        contenu = try prereglage.contenu()
    }

    /// Reconstruit un prereglage a partir de sa forme exportee.
    public func prereglage() throws -> PrereglageLecture {
        try PrereglageLecture(id: id, nom: nom, contenu: contenu)
    }
}

/// La part prereglages d une sauvegarde, versionnee.
public struct SauvegardeDesPrereglages: Sendable, Codable, Hashable {
    /// Version du format de la part prereglages.
    public static let versionCourante = 1

    public let version: Int
    public let prereglages: [PrereglageExporte]

    public init(
        version: Int = SauvegardeDesPrereglages.versionCourante,
        prereglages: [PrereglageExporte]
    ) {
        self.version = version
        self.prereglages = prereglages
    }

    /// Construit la part prereglages a partir des prereglages persistes.
    ///
    /// L ordre est celui de la liste, pour qu une sauvegarde relue produise le
    /// meme fichier que la precedente quand rien n a change.
    public init(_ prereglages: [PrereglageLecture]) throws {
        try self.init(
            prereglages: OrdreDesPrereglages.trier(prereglages).map(PrereglageExporte.init)
        )
    }

    /// Encode la part prereglages du fichier de sauvegarde.
    public func donnees() throws -> Data {
        let encodeur = JSONEncoder()
        encodeur.outputFormatting = [.sortedKeys]

        return try encodeur.encode(self)
    }

    /// Relit une part prereglages deja encodee.
    ///
    /// - Throws: `ErreurDeSauvegarde.fichierIllisible` quand les octets ne
    ///   decrivent pas cette part, `.formatInconnu` quand ils viennent d une
    ///   version que celle ci ne sait pas lire.
    public init(donnees: Data) throws {
        guard let relue = try? JSONDecoder().decode(SauvegardeDesPrereglages.self, from: donnees) else {
            throw ErreurDeSauvegarde.fichierIllisible
        }

        guard relue.version == Self.versionCourante else {
            throw ErreurDeSauvegarde.formatInconnu(version: relue.version)
        }

        self = relue
    }

    /// Prereglages reconstruits, dans l ordre de la liste.
    public func restaures() throws -> [PrereglageLecture] {
        try prereglages.map { try $0.prereglage() }
    }
}
