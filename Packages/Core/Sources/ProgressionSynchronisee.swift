import Foundation

//
// ProgressionSynchronisee
//
// La progression de lecture telle qu elle voyage entre deux appareils, et sa
// traduction dans les deux sens avec une ligne de journal.
//
// Elle ressemble a `ProgressionDeChapitreExportee` de la sauvegarde sans etre
// le meme type, et c est un choix. Le format de sauvegarde est un fichier que
// l utilisateur garde des annees et que la migration doit savoir relire ; le
// format de synchronisation vit quelques secondes entre deux appareils de la
// meme version. Les lier ferait qu un changement du format d echange casserait
// la relecture des vieilles sauvegardes, ou l inverse.
//
// L encodage trie ses cles. Sans cela, deux appareils encodant la meme
// progression produiraient deux suites d octets differentes selon l ordre de
// hachage du processus, et la troisieme ligne de la resolution de conflit,
// celle qui compare les charges, cesserait d etre stable.
//

/// Ce qui peut mal tourner quand une ligne de journal est relue.
public enum ErreurDeSynchronisation: Error, Sendable, Equatable {
    /// La charge ne se decode pas dans le type attendu.
    ///
    /// Le cas arrive quand un appareil plus recent envoie une charge que
    /// celui ci ne connait pas encore. Elle est ecartee, jamais appliquee a
    /// moitie.
    case chargeIllisible(cle: CleDeChangement)

    /// La ligne ne decrit pas l entite attendue.
    case entiteInattendue(attendue: EntiteSynchronisee, recue: EntiteSynchronisee)
}

/// La progression d un chapitre telle qu elle circule entre appareils.
public struct ProgressionSynchronisee: Sendable, Codable, Hashable {
    /// Chapitre concerne, meme identifiant sur tous les appareils.
    public let chapitreId: UUID

    /// Page atteinte, indexee a partir de zero.
    public let pageAtteinte: Int

    /// Decalage de defilement des modes verticaux, entre zero et un.
    public let decalageDeDefilement: Double

    /// Vrai quand le chapitre est lu.
    public let estLu: Bool

    /// Instant de la lecture sur l appareil qui l a produite.
    ///
    /// C est aussi l horodatage de la ligne de journal. Les separer laisserait
    /// la porte ouverte a une ligne dont la date de lecture et la date de
    /// changement se contredisent, et la resolution de conflit trancherait
    /// alors sur une date que l applicateur n ecrirait pas.
    public let dateLecture: Date

    public init(
        chapitreId: UUID,
        pageAtteinte: Int,
        decalageDeDefilement: Double = 0,
        estLu: Bool = false,
        dateLecture: Date
    ) {
        self.chapitreId = chapitreId
        self.pageAtteinte = max(0, pageAtteinte)
        self.decalageDeDefilement = min(max(decalageDeDefilement, 0), 1)
        self.estLu = estLu
        self.dateLecture = dateLecture
    }

    /// Progression tiree d une position de lecture.
    public init(_ position: PositionDeLecture, estLu: Bool = false, le date: Date) {
        self.init(
            chapitreId: position.chapitreId,
            pageAtteinte: position.pageIndex,
            decalageDeDefilement: position.decalageDeDefilement,
            estLu: estLu,
            dateLecture: date
        )
    }

    /// Cle de journal de cette progression.
    public var cle: CleDeChangement {
        CleDeChangement(entite: .progressionDeChapitre, identifiant: chapitreId)
    }

    /// Position de reprise que cette progression decrit.
    public func position() -> PositionDeLecture {
        PositionDeLecture(
            chapitreId: chapitreId,
            pageIndex: pageAtteinte,
            decalageDeDefilement: decalageDeDefilement
        )
    }

    /// Ligne de journal correspondante, produite par cet appareil.
    public func changement(depuis appareil: String) throws -> ChangementSynchronise {
        try ChangementSynchronise(
            cle: cle,
            charge: CodageDeSynchronisation.encoder(self),
            horodatage: dateLecture,
            appareil: appareil
        )
    }

    /// Progression relue depuis une ligne de journal.
    ///
    /// - Throws: `ErreurDeSynchronisation.entiteInattendue` quand la ligne
    ///   decrit autre chose, `chargeIllisible` quand elle ne se decode pas.
    public static func lire(_ changement: ChangementSynchronise) throws -> ProgressionSynchronisee {
        try CodageDeSynchronisation.decoder(
            ProgressionSynchronisee.self,
            depuis: changement,
            attendue: .progressionDeChapitre
        )
    }
}
