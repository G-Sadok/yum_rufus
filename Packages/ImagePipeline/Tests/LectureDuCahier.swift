import Foundation

//
// LectureDuCahier
//
// Lecture de docs/CAHIER-DES-CHARGES-DEV.md depuis le disque.
//
// La chaine de traitement se compare au document lui meme, jamais a une copie de
// son contenu. L ordre des dix etapes est la seule chose que la section 6.3
// impose, et une interversion ne leve aucune erreur : elle se voit sur la
// planche, des mois plus tard. Lire le document ici est ce qui fait virer la
// suite au rouge le jour ou le code et le cahier ne disent plus la meme chose.
//

enum CahierDeDeveloppement {
    /// Chemin du document, resolu depuis l emplacement de ce fichier.
    static var chemin: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // ImagePipeline
            .deletingLastPathComponent() // Packages
            .deletingLastPathComponent() // racine du depot
            .appendingPathComponent("docs/CAHIER-DES-CHARGES-DEV.md")
    }

    /// Lignes du document.
    static func lignes() throws -> [String] {
        try String(contentsOf: chemin, encoding: .utf8)
            .components(separatedBy: .newlines)
    }

    /// Elements d une liste numerotee placee sous ce titre, dans l ordre.
    ///
    /// La lecture s arrete au premier titre suivant, pour ne pas ramasser une
    /// liste voisine si la section perd un jour sa liste.
    static func listeNumerotee(sous titre: String) throws -> [String] {
        let lignes = try lignes()

        guard let depart = lignes.firstIndex(where: { $0.hasPrefix("#") && $0.contains(titre) }) else {
            return []
        }

        var elements: [String] = []

        for ligne in lignes[lignes.index(after: depart)...] {
            if ligne.hasPrefix("#") {
                break
            }

            if let element = elementNumerote(ligne) {
                elements.append(element)
            }
        }

        return elements
    }

    /// Texte d une ligne de la forme `3. Reduction du bruit`, nil sinon.
    private static func elementNumerote(_ ligne: String) -> String? {
        let contenu = ligne.trimmingCharacters(in: .whitespaces)
        let chiffres = contenu.prefix { $0.isNumber }

        guard chiffres.isEmpty == false else {
            return nil
        }

        let reste = contenu.dropFirst(chiffres.count)

        guard reste.hasPrefix(". ") else {
            return nil
        }

        return String(reste.dropFirst(2)).trimmingCharacters(in: .whitespaces)
    }
}
