import Foundation

/// Acces au jeu de fichiers de metadonnees range dans `Tests/Fichiers`.
///
/// Les fichiers sont suivis dans le depot plutot que fabriques par le test,
/// contrairement aux archives ZIP de `ConstructeurDeZip`. La raison est celle
/// que la section 5.3 rend critique : ce qui casse un lecteur de metadonnees,
/// ce n est pas la structure XML, c est l encodage, la marque d ordre, le bloc
/// litteral, la troncature au milieu d une balise. Un fichier fabrique en Swift
/// serait toujours ecrit en UTF-8 par construction, et n aurait donc jamais
/// prouve que le ISO-8859-1 est lu correctement.
enum FichiersDeMetadonnees {
    /// Fichiers du jeu, avec ce que chacun apporte a la couverture.
    ///
    /// Chaque nom correspond a la forme reellement produite par un outil du
    /// domaine. Le contenu est original : aucune oeuvre sous droit d auteur
    /// n entre dans le depot.
    static let tous = [
        // ComicInfo complet ecrit par un outil de catalogage occidental, avec
        // les attributs de schema et le bloc Pages en fin de document.
        "comicrack-occidental.xml",
        // ComicInfo de manga, resume en bloc litteral, sens de lecture declare.
        "kavita-manga.xml",
        // ComicInfo en ISO-8859-1, encodage annonce dans la declaration.
        "latin1.xml",
        // ComicInfo en UTF-8 precede d une marque d ordre.
        "utf8-bom.xml",
        // ComicInfo reduit a deux champs, sans declaration XML.
        "minimal.xml",
        // ComicInfo coupe au milieu d une valeur.
        "tronque.xml",
        // Page d erreur HTML enregistree a la place du fichier attendu.
        "page-html.xml",
        // Fichier de zero octet.
        "vide.xml",
        // Commentaire ComicBookInfo complet.
        "comictagger-comicbookinfo.json",
        // Commentaire ComicBookInfo coupe.
        "comicbookinfo-tronque.json",
    ]

    /// Octets d un fichier du jeu, nul quand il manque.
    static func octets(_ nom: String) -> Data? {
        guard let dossier = Bundle.module.resourceURL else { return nil }

        return try? Data(contentsOf: dossier.appending(path: "Fichiers").appending(path: nom))
    }
}
