import Core
import DesignSystem
import Foundation

//
// Meme role que les autres ponts de catalogue : le paquet DesignSystem sait
// disposer une colonne de reglages, il ne sait pas dans quelle langue.
//
// Les cles suivent la forme du catalogue, `reglages.section.X`,
// `reglages.ligne.Y` et `reglages.valeur.Z`. Elles sont construites depuis les
// enumerations plutot qu ecrites une a une : une section ajoutee au modele
// arrive alors ici sans qu on ait a y penser, et une cle absente se voit tout
// de suite a l ecran plutot que de se perdre dans une liste de cinquante cinq
// lignes.
//

extension LibellesDeReglages {
    /// Libelles tels que le catalogue de l application les porte.
    static var duCatalogue: LibellesDeReglages {
        LibellesDeReglages(
            titresDeSection: Dictionary(
                uniqueKeysWithValues: SectionDeReglages.allCases.map {
                    ($0, texte("reglages.section.\($0.rawValue)"))
                }
            ),
            libellesDeLigne: Dictionary(
                uniqueKeysWithValues: IdentifiantDeReglage.allCases.map {
                    ($0, texte("reglages.ligne.\(cleCourte(de: $0))"))
                }
            ),
            descriptionsDeSection: Dictionary(
                uniqueKeysWithValues: SectionDeReglages.allCases.compactMap { section in
                    let cle = "reglages.description.\(section.rawValue)"
                    let valeur = texte(cle)

                    // Toutes les sections n en portent pas. Une cle absente rend
                    // son propre nom, ce qui se verrait a l ecran : on l ecarte.
                    return valeur == cle ? nil : (section, valeur)
                }
            ),
            valeursDeMenu: valeursDeMenu,
            noteDeFin: texte("reglages.note"),
            augmenter: texte("reglages.augmenter"),
            diminuer: texte("reglages.diminuer")
        )
    }

    /// Cle courte d une ligne, la partie qui suit le point de sa section.
    ///
    /// Les identifiants s ecrivent `lecteur.miseEnPage`, et le catalogue range
    /// ses lignes sous `reglages.ligne.miseEnPage`.
    private static func cleCourte(de identifiant: IdentifiantDeReglage) -> String {
        identifiant.rawValue.split(separator: ".").last.map(String.init) ?? identifiant.rawValue
    }

    /// Valeurs des menus, prises sur les lignes qui en portent.
    ///
    /// Le catalogue de lignes est la seule source : un menu ajoute au modele
    /// apporte ses valeurs avec lui, sans liste a tenir a jour ici.
    private static var valeursDeMenu: [String: String] {
        var valeurs: [String: String] = [:]

        for ligne in CatalogueDeReglages.toutesLesLignes {
            for choix in ligne.choix {
                valeurs[choix] = texte("reglages.valeur.\(choix)")
            }
        }

        return valeurs
    }

    private static func texte(_ cle: String) -> String {
        String(localized: String.LocalizationValue(cle))
    }
}
