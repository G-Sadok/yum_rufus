import Core
import Foundation

//
// MagasinDeSignets
//
// La ou vivent les signets entre deux lancements.
//
// Un signet n est pas un identifiant de connexion : il n ouvre rien qui ne soit
// deja autorise, et le trousseau ne lui apporterait rien. Il vit donc dans un
// fichier de l espace applicatif, comme le fait le systeme lui meme pour les
// documents recents. Les mots de passe et les jetons des sources distantes,
// eux, iront au trousseau.
//
// Le protocole existe pour que la source ne connaisse pas le disque. Les tests
// s en servent avec un dossier temporaire, et un nouveau magasin sur le meme
// dossier reproduit exactement ce que fait un relancement de l application.
//

/// Range et retrouve les signets d acces aux dossiers.
public protocol MagasinDeSignets: Sendable {
    /// Enregistre ou remplace le signet range sous cette cle.
    func enregistrer(_ signet: SignetDeSecurite, pour cle: String) throws

    /// Rend le signet range sous cette cle, ou nul s il n y en a pas.
    func signet(pour cle: String) throws -> SignetDeSecurite?

    /// Oublie le signet range sous cette cle.
    func oublier(_ cle: String) throws
}

/// Magasin de signets pose sur un fichier JSON.
///
/// Le type est une valeur sans etat en memoire : chaque operation relit et
/// reecrit le fichier. C est ce qui le rend sur a partager entre taches sans
/// verrou, et ce qui garantit qu un signet ecrit est un signet persiste, pas un
/// signet en attente de vidange.
public struct MagasinDeSignetsFichier: MagasinDeSignets {
    /// Emplacement du fichier de signets.
    public let fichier: URL

    /// Voir `AnalyseurDeDossier` : le gestionnaire de fichiers n est pas
    /// `Sendable`, il est donc pris a chaque appel et jamais retenu.
    private var gestionnaire: FileManager {
        .default
    }

    public init(fichier: URL) {
        self.fichier = fichier
    }

    /// Magasin range dans le dossier de support de l application.
    ///
    /// - Throws: l erreur du systeme quand le dossier ne peut pas etre cree.
    public static func parDefaut(nomApplication: String) throws -> MagasinDeSignetsFichier {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dossier = support.appendingPathComponent(nomApplication, isDirectory: true)

        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)

        return MagasinDeSignetsFichier(fichier: dossier.appendingPathComponent("signets.json"))
    }

    public func enregistrer(_ signet: SignetDeSecurite, pour cle: String) throws {
        var contenu = try lire()
        contenu[cle] = signet

        try ecrire(contenu)
    }

    public func signet(pour cle: String) throws -> SignetDeSecurite? {
        try lire()[cle]
    }

    public func oublier(_ cle: String) throws {
        var contenu = try lire()
        guard contenu.removeValue(forKey: cle) != nil else { return }

        try ecrire(contenu)
    }

    private func lire() throws -> [String: SignetDeSecurite] {
        guard let donnees = gestionnaire.contents(atPath: fichier.path) else { return [:] }

        // Un fichier illisible n est pas une raison de perdre l acces a tout :
        // il est traite comme vide, et la prochaine ecriture le remplace.
        return (try? JSONDecoder().decode([String: SignetDeSecurite].self, from: donnees)) ?? [:]
    }

    private func ecrire(_ contenu: [String: SignetDeSecurite]) throws {
        let donnees = try JSONEncoder().encode(contenu)
        let dossier = fichier.deletingLastPathComponent()

        if gestionnaire.fileExists(atPath: dossier.path) == false {
            try gestionnaire.createDirectory(at: dossier, withIntermediateDirectories: true)
        }

        try donnees.write(to: fichier, options: .atomic)
    }
}
