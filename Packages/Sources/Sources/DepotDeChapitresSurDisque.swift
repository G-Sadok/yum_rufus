import Core
import Foundation

//
// DepotDeChapitresSurDisque
//
// Ou les chapitres telecharges sont poses, et comment un fichier a moitie ecrit
// se distingue d un fichier complet.
//
// La distinction tient a un suffixe. Une page en cours de reception s appelle
// `page-0007.partiel`, une page complete s appelle `page-0007`. Le passage de
// l un a l autre est un renommage, donc une operation que le systeme de fichiers
// rend atomique : une coupure de courant laisse ou bien le fragment, ou bien la
// page, jamais un fichier a demi renomme.
//
// C est pourquoi l inventaire compte les pages completes depuis la premiere et
// s arrete au premier trou. Le moteur ecrit dans l ordre de lecture ; un trou
// veut donc dire que ce qui suit vient d une tentative dont on ignore l issue,
// et le compter reviendrait a declarer completes des pages qui ne le sont pas.
//

/// Depot des chapitres telecharges dans un dossier local.
public struct DepotDeChapitresSurDisque: DepotDeChapitres {
    /// Suffixe des fragments en cours de reception.
    static let suffixeDeFragment = "partiel"

    /// Prefixe des fichiers de page.
    static let prefixeDePage = "page-"

    /// Nombre de chiffres du numero de page dans un nom de fichier.
    ///
    /// Quatre, ce qui couvre les chapitres jusqu a dix mille pages. Les zeros
    /// initiaux gardent l ordre alphabetique du dossier aligne sur l ordre de
    /// lecture, ce qui evite qu un utilisateur qui ouvre le dossier dans le
    /// Finder voie la page dix avant la page deux.
    static let chiffresDeNumero = 4

    private let racine: URL

    /// Gestionnaire de fichiers du systeme.
    ///
    /// Il n est pas injecte, contrairement au transport HTTP. `FileManager`
    /// n est pas `Sendable`, et surtout les tests de ce depot n ont rien a
    /// simuler : ils ecrivent dans un dossier temporaire reel, ce qui est
    /// exactement ce que le code fera en production.
    private var fichiers: FileManager {
        .default
    }

    /// Construit le depot sur un dossier.
    ///
    /// - Parameter racine: dossier des telechargements, cree au besoin.
    public init(racine: URL) {
        self.racine = racine
    }

    // MARK: Protocole

    public func inventaire(du chapitre: UUID) async throws -> InventaireDeTelechargement {
        let dossier = dossier(de: chapitre)

        guard fichiers.fileExists(atPath: dossier.path) else {
            return .vierge
        }

        var completes = 0

        while fichiers.fileExists(atPath: page(completes, dans: dossier).path) {
            completes += 1
        }

        return InventaireDeTelechargement(
            pagesCompletes: completes,
            octetsDuFragment: poids(de: fragment(completes, dans: dossier))
        )
    }

    public func ecrire(_ octets: Data, page index: Int, du chapitre: UUID, enPoursuivant: Bool) async throws {
        let dossier = try dossierPret(de: chapitre)
        let destination = fragment(index, dans: dossier)

        guard enPoursuivant, fichiers.fileExists(atPath: destination.path) else {
            try octets.write(to: destination, options: .atomic)

            return
        }

        let poignee = try FileHandle(forWritingTo: destination)

        defer { try? poignee.close() }

        try poignee.seekToEnd()
        try poignee.write(contentsOf: octets)
    }

    public func sceller(page index: Int, du chapitre: UUID) async throws -> Int {
        let dossier = try dossierPret(de: chapitre)
        let source = fragment(index, dans: dossier)
        let destination = page(index, dans: dossier)

        if fichiers.fileExists(atPath: destination.path) {
            try fichiers.removeItem(at: destination)
        }

        try fichiers.moveItem(at: source, to: destination)

        return poids(de: destination)
    }

    // MARK: Chemins

    /// Dossier d un chapitre telecharge.
    public func dossier(de chapitre: UUID) -> URL {
        racine.appendingPathComponent(chapitre.uuidString, isDirectory: true)
    }

    private func dossierPret(de chapitre: UUID) throws -> URL {
        let dossier = dossier(de: chapitre)

        try fichiers.createDirectory(at: dossier, withIntermediateDirectories: true)

        return dossier
    }

    private func page(_ index: Int, dans dossier: URL) -> URL {
        dossier.appendingPathComponent(Self.nomDePage(index))
    }

    private func fragment(_ index: Int, dans dossier: URL) -> URL {
        dossier.appendingPathComponent(Self.nomDePage(index) + "." + Self.suffixeDeFragment)
    }

    /// Nom de fichier d une page, numero garni de zeros initiaux.
    static func nomDePage(_ index: Int) -> String {
        let numero = String(index)
        let garniture = String(repeating: "0", count: max(0, chiffresDeNumero - numero.count))

        return prefixeDePage + garniture + numero
    }

    /// Poids d un fichier, zero quand il n existe pas.
    ///
    /// Un fichier absent n est pas une erreur ici : c est l etat ordinaire du
    /// fragment d une page qui n a jamais commence.
    private func poids(de url: URL) -> Int {
        let valeurs = try? url.resourceValues(forKeys: [.fileSizeKey])

        return valeurs?.fileSize ?? 0
    }
}
