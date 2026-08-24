import Foundation

/// Un tableau de DESIGN-SPEC.md, lu tel quel.
struct TableauMarkdown {
    let entetes: [String]
    let lignes: [[String]]
}

/// Lecture de DESIGN-SPEC.md depuis le disque.
///
/// Les tests comparent le code au document lui meme, jamais a une copie des
/// valeurs. Une modification du document qui n arrive pas jusqu au code fait
/// virer la suite au rouge, ce qui est exactement le but.
enum SpecificationDeDesign {
    /// Chemin du document, resolu depuis l emplacement de ce fichier.
    static var chemin: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // DesignSystem
            .deletingLastPathComponent() // Packages
            .deletingLastPathComponent() // racine du depot
            .appendingPathComponent("DESIGN-SPEC.md")
    }

    /// Lignes du document.
    static func lignes() throws -> [String] {
        try String(contentsOf: chemin, encoding: .utf8)
            .components(separatedBy: .newlines)
    }

    /// Tous les tableaux du document, dans l ordre de lecture.
    static func tableaux() throws -> [TableauMarkdown] {
        let lignes = try lignes()
        var tableaux: [TableauMarkdown] = []
        var index = 0

        while index < lignes.count {
            guard estUneLigneDeTableau(lignes[index]),
                  index + 1 < lignes.count,
                  estUnSeparateur(lignes[index + 1])
            else {
                index += 1
                continue
            }

            let entetes = cellules(lignes[index])
            var corps: [[String]] = []
            var suivant = index + 2

            while suivant < lignes.count, estUneLigneDeTableau(lignes[suivant]) {
                corps.append(cellules(lignes[suivant]))
                suivant += 1
            }

            tableaux.append(TableauMarkdown(entetes: entetes, lignes: corps))
            index = suivant
        }

        return tableaux
    }

    /// Tableaux dont l entete est exactement celui demande.
    static func tableaux(dontLEnteteEst entetes: [String]) throws -> [TableauMarkdown] {
        try tableaux().filter { $0.entetes == entetes }
    }

    /// Premiere ligne du document qui contient le fragment demande.
    static func ligne(contenant fragment: String) throws -> String? {
        try lignes().first { $0.contains(fragment) }
    }

    /// Nombre place en tete d une cellule, `120 ms` donne 120.
    static func nombre(_ texte: String) -> Double? {
        let caracteres = texte.prefix { $0.isNumber || $0 == "." || $0 == "-" }
        return Double(caracteres)
    }

    private static func estUneLigneDeTableau(_ ligne: String) -> Bool {
        ligne.trimmingCharacters(in: .whitespaces).hasPrefix("|")
    }

    private static func estUnSeparateur(_ ligne: String) -> Bool {
        let contenu = ligne.trimmingCharacters(in: .whitespaces)
        guard contenu.hasPrefix("|"), contenu.contains("-") else { return false }
        return contenu.allSatisfy { "|-: ".contains($0) }
    }

    private static func cellules(_ ligne: String) -> [String] {
        var morceaux = ligne
            .trimmingCharacters(in: .whitespaces)
            .components(separatedBy: "|")

        if morceaux.first?.isEmpty == true {
            morceaux.removeFirst()
        }

        if morceaux.last?.isEmpty == true {
            morceaux.removeLast()
        }

        return morceaux
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .map(sansAccentsGraves)
    }

    /// Retire les accents graves qui encadrent une valeur du document.
    ///
    /// Une cellule comme `contour \`border\`` garde les siens, parce qu ils
    /// n encadrent pas toute la cellule.
    private static func sansAccentsGraves(_ texte: String) -> String {
        guard texte.count >= 2, texte.hasPrefix("`"), texte.hasSuffix("`") else {
            return texte
        }
        return String(texte.dropFirst().dropLast())
    }
}
