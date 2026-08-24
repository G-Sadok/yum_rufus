import Core
import Foundation

//
// AccesAuDossier
//
// Le titulaire de l autorisation d acces a un dossier, du signet range sur
// disque jusqu a la portee de securite ouverte pendant la lecture.
//
// C est un acteur parce que l ouverture de portee n est pas reentrante : deux
// taches qui ouvrent puis ferment la portee du meme dossier en parallele
// finissent par la fermer alors que l autre lit encore. L acteur serialise, et
// la portee est ouverte une seule fois pour la duree de vie de l acces.
//
// Le rafraichissement du signet perime est fait ici, au moment ou le systeme le
// signale. Le remettre a plus tard revient a le remettre au prochain lancement,
// c est a dire au moment ou l acces sera perdu.
//

/// Detient l autorisation de lire un dossier choisi par l utilisateur.
public actor AccesAuDossier {
    /// Nom de la source, repris dans les erreurs.
    public let source: String

    private let magasin: any MagasinDeSignets
    private let cle: String

    private var dossierResolu: URL?
    private var porteeOuverte = false

    /// Prepare un acces qui lira son signet dans le magasin a la demande.
    ///
    /// Rien n est resolu ici. Un lancement d application declare ses sources
    /// sans toucher le disque, la resolution vient a la premiere lecture.
    public init(magasin: any MagasinDeSignets, cle: String, source: String) {
        self.magasin = magasin
        self.cle = cle
        self.source = source
    }

    /// Enregistre le signet d un dossier que l utilisateur vient de designer,
    /// puis rend l acces correspondant.
    ///
    /// - Throws: `ErreurDeSource.accesAuDossierPerdu` si le systeme refuse de
    ///   produire un signet.
    public static func enregistrant(
        dossier: URL,
        magasin: any MagasinDeSignets,
        cle: String,
        source: String
    ) throws -> AccesAuDossier {
        let signet = try SignetDeSecurite.creer(pour: dossier, source: source)

        try magasin.enregistrer(signet, pour: cle)

        return AccesAuDossier(magasin: magasin, cle: cle, source: source)
    }

    /// Rend le dossier, en resolvant le signet au premier appel.
    ///
    /// - Throws: `ErreurDeSource.accesAuDossierPerdu` quand aucun signet n est
    ///   range, quand il ne designe plus rien, ou quand le dossier n est plus
    ///   lisible.
    public func dossier() throws -> URL {
        if let dossierResolu {
            return dossierResolu
        }

        guard let signet = try? magasin.signet(pour: cle) else {
            throw ErreurDeSource.accesAuDossierPerdu(source: source)
        }

        let resolution = try signet.resoudre(source: source)
        let dossier = resolution.dossier
        let portee = signet.porteeDeSecurite && dossier.startAccessingSecurityScopedResource()

        guard estLisible(dossier) else {
            if portee {
                dossier.stopAccessingSecurityScopedResource()
            }

            throw ErreurDeSource.accesAuDossierPerdu(source: source)
        }

        if resolution.aRafraichir {
            reecrireLeSignet(pour: dossier)
        }

        dossierResolu = dossier
        porteeOuverte = portee

        return dossier
    }

    /// Ferme la portee de securite et oublie le dossier resolu.
    ///
    /// A appeler quand la source est retiree ou desactivee. La portee est une
    /// ressource du noyau, la laisser ouverte pour une source qu on n interroge
    /// plus consomme un jeton pour rien.
    public func liberer() {
        libererLaPortee()
        dossierResolu = nil
    }

    /// Oublie le signet, donc l autorisation elle meme.
    public func revoquer() throws {
        liberer()
        try magasin.oublier(cle)
    }

    private func libererLaPortee() {
        if porteeOuverte, let dossierResolu {
            dossierResolu.stopAccessingSecurityScopedResource()
        }

        porteeOuverte = false
    }

    private func estLisible(_ dossier: URL) -> Bool {
        var estDossier: ObjCBool = false
        let existe = FileManager.default.fileExists(atPath: dossier.path, isDirectory: &estDossier)

        return existe && estDossier.boolValue
    }

    /// Remplace un signet perime par un signet neuf.
    ///
    /// L echec n est pas fatal : le dossier est accessible maintenant, seul le
    /// prochain lancement en patira, et il retentera la meme operation.
    private func reecrireLeSignet(pour dossier: URL) {
        guard let neuf = try? SignetDeSecurite.creer(pour: dossier, source: source) else { return }

        try? magasin.enregistrer(neuf, pour: cle)
    }
}
