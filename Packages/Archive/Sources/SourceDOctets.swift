import Core
import Foundation

//
// SourceDOctets
//
// Acces aleatoire aux octets d un conteneur. Toute la lecture d archive passe
// par cette abstraction plutot que par URL, pour trois raisons.
//
// D abord elle rend l acces aleatoire explicite : un lecteur qui ne peut
// demander qu une plage ne peut pas, par distraction, decompresser tout ce qui
// precede la page voulue. Ensuite elle borne les lectures a un seul endroit, ce
// qui transforme une archive tronquee en erreur typee au lieu d une lecture
// hors limites. Enfin elle rend le comportement observable en test : une source
// espionne enregistre les plages demandees et prouve qu ouvrir la page N ne
// touche pas les octets de la page N moins un.
//

/// Train d octets adressable, ouvert en lecture seule.
public protocol SourceDOctets: Sendable {
    /// Chemin ou libelle de la source, repris dans les messages d erreur.
    var nom: String { get }

    /// Nombre total d octets disponibles.
    var taille: UInt64 { get }

    /// Rend exactement `longueur` octets a partir de `offset`.
    ///
    /// - Throws: `ErreurDeDocument.conteneurTronque` si la plage demandee sort
    ///   de la source, ce qui signale toujours un conteneur incomplet.
    func lire(a offset: UInt64, longueur: Int) throws -> Data
}

/// Source adossee a un bloc d octets deja en memoire, ou projete en memoire.
///
/// La lecture d un fichier passe par une projection `mappedIfSafe` : le noyau
/// ne charge que les pages reellement touchees, ce qui donne l acces aleatoire
/// sans lire l archive entiere. Une archive de 400 Mo dont on ouvre la page 12
/// ne coute que les quelques pages memoire de l index central et de l entree.
public struct OctetsEnMemoire: SourceDOctets {
    public let nom: String
    private let contenu: Data

    public var taille: UInt64 {
        UInt64(contenu.count)
    }

    public init(_ contenu: Data, nom: String = "") {
        self.contenu = contenu
        self.nom = nom
    }

    /// Projette le fichier en memoire.
    ///
    /// - Throws: `ErreurDeDocument.fichierIntrouvable` si le fichier n existe
    ///   pas, `ErreurDeDocument.conteneurIllisible` s il existe mais refuse de
    ///   s ouvrir, par exemple faute de droits.
    public init(contenuDe url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ErreurDeDocument.fichierIntrouvable(chemin: url.path)
        }

        do {
            let donnees = try Data(contentsOf: url, options: .mappedIfSafe)
            self.init(donnees, nom: url.path)
        } catch {
            throw ErreurDeDocument.conteneurIllisible(chemin: url.path)
        }
    }

    public func lire(a offset: UInt64, longueur: Int) throws -> Data {
        guard longueur >= 0, offset <= taille, UInt64(longueur) <= taille - offset else {
            throw ErreurDeDocument.conteneurTronque(chemin: nom)
        }

        // Le decalage part de startIndex et non de zero : une Data obtenue par
        // decoupage garde les indices de son origine, et supposer zero rendrait
        // des octets voisins sans jamais lever d erreur.
        let debut = contenu.startIndex + Int(offset)

        return contenu.subdata(in: debut..<(debut + longueur))
    }
}
