import Foundation

//
// RechercheLocale
//
// Comparaison de textes pour la recherche dans la bibliotheque deja presente
// sur l appareil. Rien a voir avec l ecran Rechercher de la section 5.4, qui
// interroge les sources.
//

/// Normalisation et comparaison des titres pour la recherche locale.
///
/// La comparaison ignore la casse et les diacritiques. Une bibliotheque
/// francaise ou japonaise romanisee contient des titres accentues, et personne
/// ne tape les accents dans un champ de recherche.
///
/// SQLite ne sait pas retirer un diacritique. La regle vit donc ici, en Swift,
/// et le paquet Storage l expose a la base comme fonction SQL pour que le
/// filtre reste dans la requete plutot que dans une boucle posee apres coup.
public enum RechercheLocale {
    /// Nom sous lequel la normalisation est exposee a SQLite.
    public static let nomDeLaFonctionSQL = "yum_normaliser"

    /// Forme comparable d un texte, sans casse ni diacritique.
    public static func normaliser(_ texte: String) -> String {
        texte.folding(
            options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive],
            locale: nil
        )
    }

    /// Terme de recherche pret a etre compare, vide quand il ne filtre rien.
    ///
    /// Un champ vide, ou rempli de seuls espaces, ne filtre pas : la grille
    /// montre alors toute la bibliotheque.
    public static func termeNormalise(_ terme: String) -> String {
        normaliser(terme).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Vrai quand le terme apparait dans le texte, casse et accents ignores.
    public static func correspond(_ texte: String, a terme: String) -> Bool {
        let terme = termeNormalise(terme)
        guard !terme.isEmpty else { return true }
        return normaliser(texte).contains(terme)
    }
}
