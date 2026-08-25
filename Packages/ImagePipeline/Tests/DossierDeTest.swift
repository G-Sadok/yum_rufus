import Foundation

//
// DossierDeTest
//
// Dossier temporaire unique, supprime par l appelant a la fin du test.
//
// Chaque test de cache disque ouvre le sien. Deux tests qui partageraient un
// dossier verraient leurs purges se melanger, et la suite deviendrait
// dependante de son ordre d execution.
//

enum DossierDeTest {
    /// Cree un dossier temporaire vide et rend son emplacement.
    static func creer() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("yum-cache-\(UUID().uuidString)", isDirectory: true)

        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

        return url
    }

    /// Supprime le dossier et tout ce qu il contient.
    static func supprimer(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    /// Octets reellement presents dans le dossier, index exclu.
    ///
    /// Mesure prise sur le systeme de fichiers, jamais sur la comptabilite du
    /// cache. Un cache qui se tromperait dans son propre compte passerait tous
    /// les controles fondes sur ce compte.
    static func octetsSurLeDisque(_ url: URL) -> Int {
        let contenu = (try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey]
        )) ?? []

        return contenu
            .filter { $0.lastPathComponent != "index.json" }
            .reduce(0) { total, fichier in
                total + ((try? fichier.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
            }
    }
}
