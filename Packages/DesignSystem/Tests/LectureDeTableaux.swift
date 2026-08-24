import DesignSystem
import Foundation

/// Extraction des valeurs chiffrees d un tableau de DESIGN-SPEC.md.
///
/// Partage par les suites qui verifient la coquille. Les valeurs restent dans
/// le document, seul le decoupage vit ici.
enum LectureDeTableaux {
    /// Tableau `Propriete | Valeur` qui porte la propriete demandee.
    ///
    /// Le document en compte une dizaine. La propriete sert de signature.
    static func tableauDeProprietes(contenantLaPropriete propriete: String) throws -> TableauMarkdown? {
        try SpecificationDeDesign.tableaux(dontLEnteteEst: ["Propriete", "Valeur"])
            .first { tableau in tableau.lignes.contains { $0[0] == propriete } }
    }

    /// Valeurs d un tableau a deux colonnes, indexees par leur premiere cellule.
    static func valeursParPropriete(_ tableau: TableauMarkdown) -> [String: String] {
        Dictionary(tableau.lignes.map { ($0[0], $0[1]) }, uniquingKeysWith: { premiere, _ in premiere })
    }

    /// Tous les nombres d une cellule, dans l ordre de lecture.
    static func nombres(dans texte: String?) -> [Double] {
        guard let texte else { return [] }

        return texte
            .components(separatedBy: CharacterSet(charactersIn: "0123456789").inverted)
            .filter { !$0.isEmpty }
            .compactMap(Double.init)
    }

    /// Premier nombre d une cellule.
    static func premierNombre(_ texte: String?) -> Double? {
        nombres(dans: texte).first
    }
}

// MARK: Contextes de reference

extension ContexteDeCoquille {
    /// iPad plein ecran en paysage.
    static let iPadPaysage = ContexteDeCoquille(
        plateforme: .tactile,
        classeHorizontale: .reguliere,
        estEnPaysage: true
    )

    /// iPad plein ecran en portrait.
    static let iPadPortrait = ContexteDeCoquille(
        plateforme: .tactile,
        classeHorizontale: .reguliere,
        estEnPaysage: false
    )

    /// iPhone en portrait.
    static let iPhone = ContexteDeCoquille(
        plateforme: .tactile,
        classeHorizontale: .compacte,
        estEnPaysage: false
    )
}
