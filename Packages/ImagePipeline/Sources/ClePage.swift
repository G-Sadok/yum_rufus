import Core
import CryptoKit
import Foundation

//
// ClePage
//
// Identite d une page decodee, commune au cache memoire et au cache disque.
//
// Trois composantes et pas une de moins. Le chapitre et l index designent la
// page dans le catalogue. La variante designe l etat dans lequel cette page a
// ete produite : taille demandee, sens de lecture au moment de la division,
// reglages de traitement. Deux etats differents de la meme page sont deux
// entrees distinctes, sans quoi un changement de reglage rendrait le cache
// menteur sans jamais l invalider.
//
// L empreinte est le nom de fichier du cache disque. Elle passe par un
// condensat plutot que par les composantes en clair, pour deux raisons. Le nom
// reste court et valide sur tout systeme de fichiers, et le dossier de cache
// cesse de reveler ce que l utilisateur lit a qui l ouvre.
//

/// Identifie une page dans un etat de production donne.
public struct ClePage: Sendable, Hashable, Codable {
    /// Chapitre auquel la page appartient.
    public let chapitre: UUID

    /// Position de la page dans le chapitre, indexee a partir de zero.
    public let index: Int

    /// Etat de production de la page : taille, traitements, sens de lecture.
    ///
    /// Chaine vide pour la page telle que la source la porte.
    public let variante: String

    public init(chapitre: UUID, index: Int, variante: String = "") {
        self.chapitre = chapitre
        self.index = index
        self.variante = variante
    }

    /// Cle d une page du catalogue, dans l etat de production indique.
    public init(_ page: Page, variante: String = "") {
        self.init(chapitre: page.chapitreId, index: page.index, variante: variante)
    }

    /// Nom de fichier stable et anonyme de cette cle dans le cache disque.
    ///
    /// Deterministe d une session a l autre, sans quoi le cache disque
    /// repartirait de zero a chaque lancement.
    public var empreinte: String {
        let graine = "\(chapitre.uuidString)|\(index)|\(variante)"

        return SHA256.hash(data: Data(graine.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
