import Core
import Foundation

//
// ProtocoleDePartage
//
// Ce que les trois partages reseau du tableau 4.2 ont en commun, et rien de
// plus : lister un dossier, connaitre les attributs d une entree, et rendre une
// plage d octets d un fichier.
//
// Les trois verbes sont choisis pour ce que la lecture en flux exige. Un partage
// qui ne saurait rendre qu un fichier entier obligerait a le copier avant de
// l ouvrir, ce que le premier critere de la fonctionnalite interdit. SMB, NFS et
// WebDAV savent tous les trois lire a partir d un decalage : SMB par la commande
// READ, NFS par la procedure READ, WebDAV par l en tete `Range`. La plage est
// donc le denominateur commun, et c est elle qui monte dans le protocole.
//
// Ce qui n y monte pas compte autant. Aucune ecriture, parce que le tableau 4.2
// decrit une lecture seule et qu une source de contenu n a rien a poser sur le
// partage de l utilisateur. Aucune notion de connexion ouverte non plus : une
// implementation qui tient une session la tient derriere son propre acteur, et
// l appelant ne sait jamais si un appel a coute une reconnexion. C est ce qui
// rend la reprise apres coupure possible sans que chaque appelant la reecrive.
//
// Les chemins sont relatifs a la racine du partage, separes par des barres
// obliques, et la racine s ecrit chaine vide. Ce choix vient de l identifiant de
// chapitre deja employe par la source de fichiers locaux : un chemin relatif
// survit au deplacement de la racine, un chemin absolu non.
//

/// Une entree de partage, telle que le serveur l annonce.
public struct EntreeDePartage: Sendable, Hashable {
    /// Chemin relatif a la racine du partage, separe par des barres obliques.
    ///
    /// La racine elle meme porte la chaine vide.
    public let chemin: String

    /// Dernier composant du chemin, tel qu il s affiche.
    public let nom: String

    public let estDossier: Bool

    /// Taille en octets. Toujours zero pour un dossier, dont la taille annoncee
    /// par un serveur ne veut rien dire de comparable d un protocole a l autre.
    public let taille: UInt64

    public let dateModification: Date?

    public init(
        chemin: String,
        nom: String? = nil,
        estDossier: Bool,
        taille: UInt64 = 0,
        dateModification: Date? = nil
    ) {
        self.chemin = chemin
        self.nom = nom ?? CheminDePartage.nom(de: chemin)
        self.estDossier = estDossier
        self.taille = estDossier ? 0 : taille
        self.dateModification = dateModification
    }

    /// Extension en minuscules, vide quand l entree n en porte pas.
    public var format: String {
        CheminDePartage.format(de: nom)
    }

    /// Nom sans son extension.
    public var nomSansExtension: String {
        CheminDePartage.sansExtension(nom)
    }
}

/// Un partage reseau monte en lecture seule.
///
/// Les trois implementations livrees sont `PartageSmb`, `PartageNfs` et
/// `PartageWebDav`. Les tests en fournissent une quatrieme, qui sert des octets
/// synthetiques et compte ce qu elle a reellement transmis.
public protocol PartageReseau: Sendable {
    /// Nom du partage tel que l utilisateur l a nomme, repris dans les erreurs.
    var libelle: String { get }

    /// Liste le contenu direct d un dossier.
    ///
    /// - Parameter chemin: chemin relatif a la racine, chaine vide pour la
    ///   racine elle meme.
    /// - Throws: `ErreurReseau` quand le transport echoue,
    ///   `ErreurDeSource.sourceInjoignable` quand la racine ne se laisse pas
    ///   lister.
    func lister(_ chemin: String) async throws -> [EntreeDePartage]

    /// Rend les attributs d une entree, sans lire son contenu.
    ///
    /// - Throws: `ErreurReseau.ressourceIntrouvable` quand rien ne porte ce
    ///   chemin.
    func attributs(de chemin: String) async throws -> EntreeDePartage

    /// Rend exactement `longueur` octets d un fichier, a partir de `offset`.
    ///
    /// Une reponse plus courte que demandee signale une fin de fichier, et
    /// l appelant la traite comme telle. Une reponse plus longue est tronquee
    /// par l appelant : elle vient d un serveur qui ignore la borne haute d une
    /// plage, cas courant chez les serveurs WebDAV les plus simples.
    ///
    /// - Throws: `ErreurReseau`, dans le cas nomme qui correspond a ce qui s est
    ///   passe.
    func lire(_ chemin: String, a offset: UInt64, longueur: Int) async throws -> Data

    /// Ferme ce que l implementation tient ouvert.
    ///
    /// Appele quand la source est liberee. Une implementation sans session n a
    /// rien a faire, et la mise en oeuvre par defaut ne fait rien.
    func fermer() async
}

extension PartageReseau {
    public func fermer() async {}
}

// MARK: - Chemins

/// Manipulation des chemins de partage, separes par des barres obliques.
///
/// Le type existe parce que `URL` ne convient pas. Un chemin de partage n est
/// pas une adresse : il ne porte ni schema ni hote, il accepte des caracteres
/// qu une URL encoderait, et le passer par `URL` puis le relire rendrait un
/// chemin different de celui que le serveur a annonce. Les trois protocoles
/// nomment leurs entrees en texte, ce type les garde en texte.
public enum CheminDePartage {
    /// Assemble un chemin parent et un nom d entree.
    public static func joindre(_ parent: String, _ nom: String) -> String {
        let base = parent.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard base.isEmpty == false else {
            return nom
        }

        return base + "/" + nom
    }

    /// Dernier composant d un chemin.
    public static func nom(de chemin: String) -> String {
        chemin.split(separator: "/").last.map(String.init) ?? ""
    }

    /// Extension en minuscules du nom, vide quand il n en porte pas.
    ///
    /// Le point de tete d un nom cache n est pas une extension : `.DS_Store` a
    /// une extension vide, pas une extension `ds_store`.
    public static func format(de nom: String) -> String {
        guard let point = nom.lastIndex(of: "."), point != nom.startIndex else {
            return ""
        }

        return String(nom[nom.index(after: point)...]).lowercased()
    }

    /// Nom prive de son extension.
    public static func sansExtension(_ nom: String) -> String {
        guard let point = nom.lastIndex(of: "."), point != nom.startIndex else {
            return nom
        }

        return String(nom[nom.startIndex..<point])
    }
}
