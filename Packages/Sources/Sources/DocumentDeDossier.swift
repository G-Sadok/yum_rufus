import Core
import Foundation

//
// DocumentDeDossier
//
// Un chapitre range en images posees dans un dossier, sans archive autour.
//
// C est la forme la plus courante d un chapitre local, et la seule que le
// lecteur ne savait pas ouvrir : le systeme proposait Yum pour un dossier, et
// Yum repondait que le format n etait pas pris en charge.
//
// Les pages sont listees une fois, a l ouverture. Relire le dossier a chaque
// page ferait dependre la pagination de ce que le systeme de fichiers rend au
// moment ou on l interroge, et un fichier ajoute pendant la lecture
// deplacerait les pages sous les yeux du lecteur.
//
// Le tri est celui des archives, pas celui du systeme. `page10` doit suivre
// `page9` et non `page1`, ce que l ordre alphabetique ne fait pas.
//

/// Un chapitre range en images dans un dossier.
public struct DocumentDeDossier: DocumentLocal {
    /// Le dossier lui meme, dont les pages ont ete listees a l ouverture.
    private let dossier: URL

    private let pages: [ReferencePage]

    /// Ouvre un dossier de pages.
    ///
    /// - Throws: `ErreurDeDocument.fichierIntrouvable` quand le chemin ne
    ///   designe pas un dossier, `.aucunePage` quand il ne contient aucune
    ///   image lisible.
    public init(contenuDe url: URL) throws {
        var estDossier: ObjCBool = false
        let existe = FileManager.default.fileExists(atPath: url.path, isDirectory: &estDossier)

        guard existe, estDossier.boolValue else {
            throw ErreurDeDocument.fichierIntrouvable(chemin: url.path)
        }

        let noms = AnalyseurDeDossier().imagesPosees(dans: url)

        guard noms.isEmpty == false else {
            throw ErreurDeDocument.aucunePage(chemin: url.path)
        }

        dossier = url
        pages = noms.enumerated().map { index, nom in
            let fichier = url.appending(path: nom)
            let octets = (try? fichier.resourceValues(forKeys: [.fileSizeKey]))?.fileSize

            return ReferencePage(index: index, nom: nom, tailleOctets: octets ?? 0)
        }
    }

    public var nombrePages: Int {
        pages.count
    }

    public func referencePage(_ index: Int) throws -> ReferencePage {
        guard pages.indices.contains(index) else {
            throw ErreurDeDocument.indexHorsBornes(demande: index, nombrePages: pages.count)
        }

        return pages[index]
    }

    public func donneesPage(_ reference: ReferencePage) throws -> Data {
        guard pages.indices.contains(reference.index),
              pages[reference.index].nom == reference.nom
        else {
            throw ErreurDeDocument.entreeIntrouvable(nom: reference.nom)
        }

        do {
            return try Data(contentsOf: dossier.appending(path: reference.nom))
        } catch {
            throw ErreurDeDocument.entreeCorrompue(nom: reference.nom)
        }
    }

    /// Un dossier de pages porte son `ComicInfo.xml` a cote de ses images.
    public func donneesDeMetadonnees() throws -> Data? {
        let fichier = dossier.appending(path: Self.nomDesMetadonnees)

        return try? Data(contentsOf: fichier)
    }

    private static let nomDesMetadonnees = "ComicInfo.xml"
}
