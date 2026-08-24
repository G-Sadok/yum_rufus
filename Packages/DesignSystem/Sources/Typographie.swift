import SwiftUI

//
// Typographie, section 1.5 de DESIGN-SPEC.md.
//
// Police unique, celle du systeme. Aucune police tierce. La personnalite ne
// vient pas de la fonte, elle vient de la discipline de l echelle.
//

/// Les trois graisses autorisees par la section 1.5.
///
/// La graisse 600 est reservee a cinq cas : libelle de barre laterale active,
/// titre de carte de serie, texte de bouton principal, titre d un chapitre non
/// lu, titre de serie dans la barre du lecteur.
public enum Graisse: Int, CaseIterable, Sendable {
    case normale = 400
    case semiGrasse = 600
    case grasse = 700

    /// Graisse correspondante dans la couche vue.
    public var poids: Font.Weight {
        switch self {
        case .normale: .regular
        case .semiGrasse: .semibold
        case .grasse: .bold
        }
    }
}

/// Un role de l echelle typographique.
public struct StyleTypographique: Sendable, Equatable {
    /// Taille en points.
    public let taille: Double
    /// Graisse du role.
    public let graisse: Graisse
    /// Interlignage en points, tel que le document le fixe.
    public let interlignage: Double
    /// Interlettrage en em, negatif pour un resserrement.
    public let interlettrageEnEm: Double

    /// Espacement a passer a `lineSpacing`, qui compte l ecart entre lignes.
    public var espacementDeLigne: Double {
        interlignage - taille
    }

    /// Interlettrage converti en points pour `tracking`.
    public var interlettrage: Double {
        taille * interlettrageEnEm
    }

    /// Police prete a etre posee dans une vue.
    ///
    /// - Parameter chiffresTabulaires: obligatoire partout ou un nombre change
    ///   en place, compteur de pages, pourcentage, taille de fichier, numero de
    ///   chapitre, heure, compteur de categorie, compteur de resultats.
    public func police(chiffresTabulaires: Bool = false) -> Font {
        let police = Font.system(size: taille, weight: graisse.poids)
        return chiffresTabulaires ? police.monospacedDigit() : police
    }
}

extension Jetons {
    /// Echelle typographique, section 1.5.
    public enum Typo {
        /// Titre d une fiche de serie.
        public static let display = StyleTypographique(
            taille: 28,
            graisse: .grasse,
            interlignage: 34,
            interlettrageEnEm: -0.02
        )

        /// Titre d etat vide.
        public static let title1 = StyleTypographique(
            taille: 22,
            graisse: .grasse,
            interlignage: 28,
            interlettrageEnEm: -0.01
        )

        /// Titre de barre d outils, titre de feuille.
        public static let title2 = StyleTypographique(
            taille: 17,
            graisse: .grasse,
            interlignage: 22,
            interlettrageEnEm: -0.01
        )

        /// En tete de section de reglages.
        public static let headline = StyleTypographique(
            taille: 15,
            graisse: .grasse,
            interlignage: 20,
            interlettrageEnEm: 0
        )

        /// Libelle de ligne, valeur de reglage.
        public static let body = StyleTypographique(
            taille: 15,
            graisse: .normale,
            interlignage: 20,
            interlettrageEnEm: 0
        )

        /// Texte courant, resume de serie.
        public static let callout = StyleTypographique(
            taille: 13,
            graisse: .normale,
            interlignage: 18,
            interlettrageEnEm: 0
        )

        /// Description sous une section, sous ligne.
        public static let footnote = StyleTypographique(
            taille: 12,
            graisse: .normale,
            interlignage: 16,
            interlettrageEnEm: 0
        )

        /// Mention legale, version.
        public static let caption = StyleTypographique(
            taille: 11,
            graisse: .normale,
            interlignage: 14,
            interlettrageEnEm: 0.01
        )

        /// Roles indexes par leur nom dans le tableau 1.5.
        public static let parRole: [String: StyleTypographique] = [
            "display": display,
            "title1": title1,
            "title2": title2,
            "headline": headline,
            "body": body,
            "callout": callout,
            "footnote": footnote,
            "caption": caption,
        ]
    }
}
