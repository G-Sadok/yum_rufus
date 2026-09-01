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
// Il est public parce que le lecteur de l application ouvre les memes fichiers,
// ceux que le systeme lui pose par un clic droit. Il n ouvrait que le ZIP, donc
// un PDF annonce dans les types du bundle s ouvrait sur une erreur.
//

/// Ouverture d un conteneur de pages, quel que soit son format.
public enum LecteurDeConteneur {
    /// Ouvre le conteneur avec le lecteur qui correspond a son format.
    ///
    /// - Throws: `ErreurDeSource.formatNonPrisEnCharge` quand aucun lecteur ne
    ///   connait ce format, et `ErreurDeDocument` quand le lecteur choisi refuse
    ///   le fichier. Le second remonte tel quel : le PDF protege y annonce
    ///   `conteneurChiffre`, ce que l ecran attend pour demander le mot de passe,
    ///   et le traduire en erreur de source le rendrait indiscernable d une
    ///   archive cassee.
    public static func ouvrir(
        _ emplacement: URL,
        format: String,
        nom: String
    ) throws -> any DocumentLocal {
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

    /// Ouvre un fichier pose par le systeme, dont seul le chemin est connu.
    ///
    /// Le format est lu sur l extension et rien d autre, comme au dessus.
    public static func ouvrir(_ emplacement: URL) throws -> any DocumentLocal {
        // Un dossier n a pas d extension qui dise ce qu il est. Il se reconnait
        // au systeme de fichiers, avant que le format n ait son mot a dire.
        var estDossier: ObjCBool = false
        let existe = FileManager.default.fileExists(
            atPath: emplacement.path,
            isDirectory: &estDossier
        )

        if existe, estDossier.boolValue {
            return try DocumentDeDossier(contenuDe: emplacement)
        }

        return try ouvrir(
            emplacement,
            format: emplacement.pathExtension.lowercased(),
            nom: emplacement.lastPathComponent
        )
    }

    /// Vrai quand ce dossier porte des pages, donc quand c est un chapitre.
    ///
    /// Un dossier de series n en porte pas : ses images sont deux niveaux plus
    /// bas, sous une serie puis sous un chapitre. La distinction decide ce que
    /// fait un dossier ouvert avec Yum, le lire ou l installer comme source, et
    /// se trompe rarement : un dossier qui contient a la fois des pages et des
    /// series n existe pas dans une bibliotheque rangee.
    public static func porteDesPages(_ dossier: URL) -> Bool {
        AnalyseurDeDossier().imagesPosees(dans: dossier).isEmpty == false
    }

    /// Les formats que le lecteur sait ouvrir.
    public static var formatsConnus: Set<String> {
        DocumentZip.extensions
            .union(DocumentTar.extensions)
            .union(DocumentPdf.extensions)
    }
}
