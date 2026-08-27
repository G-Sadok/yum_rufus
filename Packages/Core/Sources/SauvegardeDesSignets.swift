import Foundation

//
// SauvegardeDesSignets
//
// La part signets du fichier JSON versionne de la section 10 du cahier de
// developpement, celle dont il dit que l export inclut `la bibliotheque, les
// categories, la progression, les signets, les prereglages et la configuration
// des sources`.
//
// Comme les deux autres parts deja ecrites, celle ci ne recopie pas une ligne de
// base telle quelle : elle projette chaque signet vers un type ferme, puis
// reencode ce type la. Une colonne qui porterait autre chose que les six champs
// de la section 3.1 ne franchit donc pas la sauvegarde.
//
// La vignette est exportee sous son nom de fichier, et la sauvegarde n emporte
// pas l image. Deux raisons. Le fichier JSON de la section 10 decrit des
// donnees, pas des octets d image, et une bibliotheque de mille signets y
// ajouterait plusieurs dizaines de megaoctets. Et une vignette se refabrique
// depuis la page, la ou une note perdue ne se retrouve pas. Un signet restaure
// dont la vignette manque affiche donc une vignette de remplacement, sans
// jamais perdre ni sa page ni sa note.
//

/// Un signet tel qu il figure dans une sauvegarde.
///
/// L identifiant est conserve : une restauration doit pouvoir reconnaitre un
/// signet deja present plutot que d en creer un double a chaque import.
public struct SignetExporte: Sendable, Codable, Hashable {
    public let id: UUID
    public let chapitreId: UUID
    public let pageIndex: Int
    public let note: String?
    public let dateCreation: Date
    public let vignetteLocale: String?

    /// Projette un signet vers sa forme exportable.
    public init(_ signet: Signet) {
        id = signet.id
        chapitreId = signet.chapitreId
        pageIndex = signet.pageIndex
        note = OrdreDesSignets.noteNettoyee(signet.note)
        dateCreation = signet.dateCreation
        vignetteLocale = signet.vignetteLocale
    }

    /// Reconstruit un signet a partir de sa forme exportee.
    public func signet() -> Signet {
        Signet(
            id: id,
            chapitreId: chapitreId,
            pageIndex: max(pageIndex, 0),
            note: note,
            dateCreation: dateCreation,
            vignetteLocale: vignetteLocale
        )
    }
}

/// La part signets d une sauvegarde, versionnee.
public struct SauvegardeDesSignets: Sendable, Codable, Hashable {
    /// Version du format de la part signets.
    public static let versionCourante = 1

    public let version: Int
    public let signets: [SignetExporte]

    public init(
        version: Int = SauvegardeDesSignets.versionCourante,
        signets: [SignetExporte]
    ) {
        self.version = version
        self.signets = signets
    }

    /// Construit la part signets a partir des signets persistes.
    ///
    /// L ordre est celui de `OrdreDesSignets.trierBruts`, pour qu une sauvegarde
    /// relue produise le meme fichier que la precedente quand rien n a change.
    public init(_ signets: [Signet]) {
        self.init(signets: OrdreDesSignets.trierBruts(signets).map(SignetExporte.init))
    }

    /// Encode la part signets du fichier de sauvegarde.
    public func donnees() throws -> Data {
        let encodeur = JSONEncoder()
        encodeur.outputFormatting = [.sortedKeys]

        return try encodeur.encode(self)
    }

    /// Relit une part signets deja encodee.
    ///
    /// - Throws: `ErreurDeSauvegarde.fichierIllisible` quand les octets ne
    ///   decrivent pas cette part, `.formatInconnu` quand ils viennent d une
    ///   version que celle ci ne sait pas lire.
    public init(donnees: Data) throws {
        guard let relue = try? JSONDecoder().decode(SauvegardeDesSignets.self, from: donnees) else {
            throw ErreurDeSauvegarde.fichierIllisible
        }

        guard relue.version == Self.versionCourante else {
            throw ErreurDeSauvegarde.formatInconnu(version: relue.version)
        }

        self = relue
    }

    /// Signets reconstruits, dans l ordre de la liste.
    public func restaures() -> [Signet] {
        signets.map { $0.signet() }
    }
}
