import Archive
import Core
import Foundation
import ImagePipeline

//
// LecteurDeConteneur
//
// Le choix du lecteur qui correspond au format d un conteneur, partage par les
// sources qui en ouvrent un.
//
// Il vit a part parce que deux sources l emploient desormais, pour des raisons
// opposees. Le dossier local ouvre un fichier deja pose sur le disque. Jellyfin
// ouvre un fichier qu il vient de rapatrier, faute de point d entree qui
// servirait ses pages une par une. Le choix du lecteur, lui, est le meme des
// deux cotes, et deux copies auraient diverge au premier format ajoute.
//
// Le format decide, jamais le contenu : un fichier renomme en .cbz reste
// annonce comme un ZIP par le systeme de fichiers, et un lecteur qui devinerait
// au vu des premiers octets ouvrirait sans le dire une archive que
// l utilisateur croit d un autre type.
//

/// Ouverture d un conteneur de pages, quel que soit son format.
enum LecteurDeConteneur {
    /// Ouvre le conteneur avec le lecteur qui correspond a son format.
    ///
    /// - Throws: `ErreurDeSource.formatNonPrisEnCharge` quand aucun lecteur ne
    ///   connait ce format, et `ErreurDeDocument` quand le lecteur choisi refuse
    ///   le fichier. Le second remonte tel quel : le PDF protege y annonce
    ///   `conteneurChiffre`, ce que l ecran attend pour demander le mot de passe,
    ///   et le traduire en erreur de source le rendrait indiscernable d une
    ///   archive cassee.
    static func ouvrir(_ emplacement: URL, format: String, nom: String) throws -> any DocumentLocal {
        if DocumentZip.extensions.contains(format) {
            return try DocumentZip(contenuDe: emplacement)
        }
        if DocumentTar.extensions.contains(format) {
            return try DocumentTar(contenuDe: emplacement)
        }
        if DocumentPdf.extensions.contains(format) {
            return try DocumentPdf(contenuDe: emplacement)
        }

        throw ErreurDeSource.formatNonPrisEnCharge(nom: nom, format: format)
    }
}
