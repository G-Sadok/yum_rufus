import Foundation

//
// EntreesDArchive
//
// Filtrage des entrees parasites exige par la section 5.3 du cahier de
// developpement, et selection des formats image de la section 5.2.
//
// Le filtrage vit dans Core et non dans Archive parce qu il ne concerne pas
// la lecture d un conteneur : un dossier d images sur disque et une reponse
// de serveur portent exactement les memes parasites.
//

/// Regles de selection des entrees d une archive ou d un dossier de pages.
public enum EntreesDArchive {
    /// Extensions des formats image pris en charge, section 5.2.
    public static let extensionsImage: Set<String> = [
        "jpg", "jpeg", "jpe", "jfif",
        "png", "apng",
        "gif",
        "bmp",
        "tif", "tiff",
        "webp",
        "avif", "avifs",
        "heic", "heif",
        "jp2", "j2k", "jpf", "jpx", "jpm",
        "jxl",
        "svg",
    ]

    /// Nom du fichier de metadonnees lu en priorite, section 5.3.
    public static let nomDesMetadonneesComic = "comicinfo.xml"

    /// Dossier ajoute par macOS a la racine des archives qu il produit.
    private static let dossierDeRessourcesApple = "__macosx"

    /// Noms de fichiers deposes par le systeme et jamais destines au lecteur.
    private static let nomsSysteme: Set<String> = [".ds_store", "thumbs.db", "desktop.ini"]

    /// Indique si une entree doit etre ignoree.
    ///
    /// Sont ecartes : le dossier `__MACOSX`, les noms deposes par le systeme,
    /// tout composant de chemin commencant par un point, ce qui couvre les
    /// dossiers caches comme les doublons AppleDouble `._page1.jpg`, ainsi que
    /// les entrees de dossier et les entrees vides.
    public static func estParasite(_ chemin: String) -> Bool {
        let composants = composantsDeChemin(chemin)

        guard let nom = composants.last else { return true }

        // Une entree qui se termine par un separateur decrit un dossier, pas
        // une page. Les archives ZIP en contiennent presque toujours.
        if chemin.hasSuffix("/") || chemin.hasSuffix("\\") {
            return true
        }

        for composant in composants {
            let compare = composant.lowercased()
            if compare == dossierDeRessourcesApple {
                return true
            }
            if composant.hasPrefix(".") {
                return true
            }
        }

        return nomsSysteme.contains(nom.lowercased())
    }

    /// Indique si une entree porte l extension d un format image pris en charge.
    public static func estImage(_ chemin: String) -> Bool {
        guard estParasite(chemin) == false else { return false }

        return extensionsImage.contains(extensionDeFichier(chemin))
    }

    /// Indique si une entree est le fichier de metadonnees `ComicInfo.xml`.
    public static func estMetadonneesComic(_ chemin: String) -> Bool {
        guard estParasite(chemin) == false else { return false }
        guard let nom = composantsDeChemin(chemin).last else { return false }

        return nom.lowercased() == nomDesMetadonneesComic
    }

    /// Rend les seules entrees affichables comme pages, dans l ordre de lecture.
    ///
    /// Le filtrage precede toujours le tri : trier puis filtrer coute le tri des
    /// parasites, et sur une archive qui en porte autant que de pages cela
    /// double le travail pour rien.
    public static func pages(parmi entrees: [String]) -> [String] {
        TriNaturel.trier(entrees.filter(estImage))
    }

    /// Rend l entree de metadonnees a lire, si l archive en porte une.
    ///
    /// La moins profonde gagne, parce qu un `ComicInfo.xml` place a la racine
    /// decrit le chapitre entier alors qu un homonyme enfoui accompagne le plus
    /// souvent un sous ensemble de pages.
    public static func metadonneesComic(parmi entrees: [String]) -> String? {
        entrees
            .filter(estMetadonneesComic)
            .min { composantsDeChemin($0).count < composantsDeChemin($1).count }
    }

    /// Decoupe un chemin sur les deux separateurs rencontres dans les archives.
    ///
    /// La barre inversee apparait dans les entrees ecrites par certains outils
    /// Windows. La traiter comme du texte laisserait passer `__MACOSX\page1.jpg`.
    private static func composantsDeChemin(_ chemin: String) -> [String] {
        chemin
            .split(whereSeparator: { $0 == "/" || $0 == "\\" })
            .map(String.init)
    }

    private static func extensionDeFichier(_ chemin: String) -> String {
        guard let nom = composantsDeChemin(chemin).last else { return "" }
        guard let point = nom.lastIndex(of: "."), point != nom.startIndex else { return "" }

        return String(nom[nom.index(after: point)...]).lowercased()
    }
}
