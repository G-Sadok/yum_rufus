import Core
import Foundation

//
// SignetDeSecurite
//
// Le signet de securite de la section 4.2 : ce qui fait qu un dossier choisi
// une fois reste accessible au lancement suivant.
//
// Retenir le chemin ne suffit pas. Une application sandboxee ne recoit
// l autorisation de lire un dossier qu au moment ou l utilisateur le designe,
// et cette autorisation ne survit pas a la fermeture du processus. Le signet
// est la forme serialisable de cette autorisation. Il survit aussi au
// deplacement et au renommage du dossier, parce qu il designe le noeud du
// systeme de fichiers et non son chemin.
//
// macOS et iOS ne l obtiennent pas de la meme facon. Sur macOS la portee de
// securite est demandee explicitement a la creation comme a la resolution. Sur
// iOS elle est attachee a l URL rendue par le selecteur de documents, et le
// signet minimal suffit. La difference est isolee ici, personne d autre n a a
// la connaitre.
//

/// Autorisation d acces a un dossier, sous une forme qui se range sur disque.
public struct SignetDeSecurite: Sendable, Hashable, Codable {
    /// Octets rendus par le systeme. Opaques, ne pas les interpreter.
    public let donnees: Data

    /// Vrai quand le signet porte une portee de securite explicite.
    ///
    /// Faux veut dire signet simple. Cela arrive quand le systeme refuse la
    /// portee de securite, par exemple dans un processus non sandboxe. Le
    /// signet reste utilisable, il ne demande simplement pas d ouverture de
    /// portee.
    public let porteeDeSecurite: Bool

    public init(donnees: Data, porteeDeSecurite: Bool) {
        self.donnees = donnees
        self.porteeDeSecurite = porteeDeSecurite
    }

    /// Fabrique un signet pour un dossier que l utilisateur vient de designer.
    ///
    /// - Throws: `ErreurDeSource.accesAuDossierPerdu` si le systeme refuse de
    ///   produire un signet, y compris sans portee de securite.
    public static func creer(pour dossier: URL, source: String) throws -> SignetDeSecurite {
        #if os(macOS)
            if let donnees = try? dossier.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            ) {
                return SignetDeSecurite(donnees: donnees, porteeDeSecurite: true)
            }
        #endif

        // Repli sur le signet simple. Sur iOS c est la forme normale, sur macOS
        // c est ce qui reste quand la portee de securite n est pas accordee.
        guard let donnees = try? dossier.bookmarkData(
            options: [.minimalBookmark],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else {
            throw ErreurDeSource.accesAuDossierPerdu(source: source)
        }

        return SignetDeSecurite(donnees: donnees, porteeDeSecurite: false)
    }

    /// Rend le dossier designe par le signet.
    ///
    /// Un signet perime reste resolvable : le systeme le signale, et l appelant
    /// le remplace par un signet neuf pour eviter que le suivant echoue.
    ///
    /// - Returns: le dossier, et si le signet doit etre reecrit.
    /// - Throws: `ErreurDeSource.accesAuDossierPerdu` quand le signet ne
    ///   designe plus rien d accessible.
    public func resoudre(source: String) throws -> (dossier: URL, aRafraichir: Bool) {
        var estPerime = false

        #if os(macOS)
            let options: URL.BookmarkResolutionOptions = porteeDeSecurite
                ? [.withSecurityScope, .withoutUI]
                : [.withoutUI]
        #else
            let options: URL.BookmarkResolutionOptions = [.withoutUI]
        #endif

        guard let dossier = try? URL(
            resolvingBookmarkData: donnees,
            options: options,
            relativeTo: nil,
            bookmarkDataIsStale: &estPerime
        ) else {
            throw ErreurDeSource.accesAuDossierPerdu(source: source)
        }

        return (dossier, estPerime)
    }
}
