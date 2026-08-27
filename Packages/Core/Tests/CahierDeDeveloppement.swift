import Foundation

//
// Lecture du cahier de developpement depuis le disque.
//
// La matrice premium de la section 10 est une liste de mots, pas un tableau de
// chiffres. Les tests la lisent donc dans le document lui meme plutot que dans
// une copie posee a cote : une fonction deplacee de la colonne gratuite vers la
// colonne premium change le document, et la suite doit virer au rouge tant que
// le code ne l a pas suivie.
//
// C est la meme methode que `SpecificationDeDesign` pour DESIGN-SPEC.md et que
// `ConfigurationStoreKit` pour les tarifs.
//

/// Les deux colonnes de la matrice de la section 10.
struct MatriceDuCahier {
    /// Fonctions listees comme gratuites, dans l ordre du document.
    let gratuites: [String]

    /// Fonctions listees comme premium, dans l ordre du document.
    let premium: [String]
}

/// Acces au cahier de developpement depuis le disque.
enum CahierDeDeveloppement {
    /// Chemin du document, resolu depuis l emplacement de ce fichier de test.
    static var chemin: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // Core
            .deletingLastPathComponent() // Packages
            .deletingLastPathComponent() // racine du depot
            .appendingPathComponent("docs/CAHIER-DES-CHARGES-DEV.md")
    }

    /// Lignes du document.
    static func lignes() throws -> [String] {
        try String(contentsOf: chemin, encoding: .utf8)
            .components(separatedBy: .newlines)
    }

    /// Premiere ligne du document qui contient le fragment demande.
    static func ligne(contenant fragment: String) throws -> String? {
        try lignes().first { $0.contains(fragment) }
    }

    /// Les deux colonnes de la matrice de la section 10.
    ///
    /// Chaque colonne est une phrase du document, introduite par son etiquette
    /// en gras et separee par des virgules. Le point final de la phrase est
    /// retire, les fragments vides le sont aussi.
    static func matricePremium() throws -> MatriceDuCahier {
        let gratuites = try fonctions(apres: "**Gratuit** :")
        let premium = try fonctions(apres: "**Premium** :")

        return MatriceDuCahier(gratuites: gratuites, premium: premium)
    }

    private static func fonctions(apres etiquette: String) throws -> [String] {
        guard let ligne = try ligne(contenant: etiquette),
              let debut = ligne.range(of: etiquette)
        else {
            return []
        }

        return ligne[debut.upperBound...]
            .components(separatedBy: ",")
            .map { fragment in
                fragment
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "."))
                    .trimmingCharacters(in: .whitespaces)
            }
            .filter { $0.isEmpty == false }
    }
}
