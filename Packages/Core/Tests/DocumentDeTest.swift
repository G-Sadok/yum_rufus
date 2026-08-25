import Core
import Foundation

/// Conteneur factice, juste assez complet pour eprouver la lecture des
/// metadonnees sans dependre d un format d archive.
///
/// Il vit dans les tests de Core parce que Core ne connait aucun conteneur
/// reel : le protocole y est defini, ses implementations sont ailleurs. Sans
/// ce faux, la regle qui dit qu un fichier de metadonnees casse n interrompt
/// jamais l ouverture ne serait verifiee que dans Archive, donc jamais pour les
/// formats qui arriveront plus tard.
struct DocumentDeTest: DocumentLocal {
    var nombrePages: Int = 3

    /// Octets rendus par `donneesDeMetadonnees()`.
    var octetsDeMetadonnees: Data?

    /// Commentaire global du conteneur.
    var commentaireDeConteneur: String?

    /// Erreur levee par la lecture des metadonnees, quand elle doit echouer.
    ///
    /// Le cas est reel : l entree `ComicInfo.xml` peut exister dans l index
    /// d une archive et ses octets etre corrompus, ou compresses avec une
    /// methode inconnue.
    var erreurDeMetadonnees: ErreurDeDocument?

    func referencePage(_ index: Int) throws -> ReferencePage {
        guard (0..<nombrePages).contains(index) else {
            throw ErreurDeDocument.indexHorsBornes(demande: index, nombrePages: nombrePages)
        }

        return ReferencePage(index: index, nom: "page\(index + 1).jpg", tailleOctets: 16)
    }

    func donneesPage(_ reference: ReferencePage) throws -> Data {
        Data(reference.nom.utf8)
    }

    func donneesDeMetadonnees() throws -> Data? {
        if let erreurDeMetadonnees {
            throw erreurDeMetadonnees
        }

        return octetsDeMetadonnees
    }
}
