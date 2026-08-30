import Core
import CoreText
import Foundation

//
// MesureDeTexteDuSysteme
//
// La mesure exacte d un texte dans la police que le produit pose reellement.
//
// Le modele sait replier un texte dans un rectangle sans jamais deborder, mais
// il ne peut pas le faire seul : il faudrait qu il connaisse la largeur d un
// caractere, qui depend du caractere, de la police et du corps. Un calcul
// approche, une largeur moyenne multipliee par le nombre de caracteres, se
// tromperait exactement la ou il ne faut pas, sur les lignes presque pleines,
// et le debordement reviendrait par la porte de derriere.
//
// La mesure passe donc par CoreText, qui compose la ligne comme le systeme la
// composera. `CTLineGetTypographicBounds` rend la largeur d avance de la ligne,
// celle que le rendu occupera, et non la boite englobante des glyphes, qui est
// plus petite et laisserait passer les debordements d un jambage.
//
// La hauteur de ligne vient de la police elle meme, montante plus descendante
// plus interligne, et non d un rapport ecrit ici. Le tableau 1.5 fixe bien un
// interlignage par role, mais il ne le fixe que pour les huit corps de
// l echelle, et la mise en page de bulle essaie tous les corps intermediaires.
// Prendre la mesure de la police est la seule facon de rester exact entre deux
// paliers.
//
// La police est celle du systeme, comme l impose la section 1.5. Aucune police
// tierce, ici comme partout ailleurs.
//

/// Mesure du texte dans la police du systeme, par CoreText.
public struct MesureDeTexteDuSysteme: MesureDeTexte {
    /// Graisse mesuree, celle qui sera posee a l ecran.
    public let graisse: Graisse

    /// Prepare une mesure.
    ///
    /// - Parameter graisse: graisse du texte qui sera rendu. Une mesure faite
    ///   dans une graisse et un rendu fait dans une autre ne diraient pas la
    ///   meme largeur, et l ecart passerait par dessus le bord de la bulle.
    public init(graisse: Graisse = .normale) {
        self.graisse = graisse
    }

    /// Largeur d avance de la ligne, ou l infini quand elle ne se compose pas.
    ///
    /// Rendre l infini plutot que zero est un choix de sens : un fragment
    /// qu on ne sait pas mesurer n entre nulle part, et la mise en page le
    /// coupera. Rendre zero le ferait passer pour tenant dans n importe quelle
    /// largeur, et il deborderait a l ecran.
    public func largeur(de fragment: String, corps: Double) -> Double {
        guard fragment.isEmpty == false else { return 0 }

        let attributs = [kCTFontAttributeName: police(corps: corps)] as CFDictionary

        guard let attribuee = CFAttributedStringCreate(nil, fragment as CFString, attributs) else {
            return .infinity
        }

        return CTLineGetTypographicBounds(
            CTLineCreateWithAttributedString(attribuee),
            nil,
            nil,
            nil
        )
    }

    public func hauteurDeLigne(corps: Double) -> Double {
        let police = police(corps: corps)
        let montante = CTFontGetAscent(police)
        let descendante = CTFontGetDescent(police)
        let interligne = CTFontGetLeading(police)

        return (montante + descendante + interligne).rounded(.up)
    }

    /// Police du systeme au corps et a la graisse demandes.
    ///
    /// Le descripteur passe par les traits plutot que par un nom de fonte.
    /// Nommer une graisse par son nom de fichier lierait le produit a une
    /// version du systeme, alors que la section 1.5 demande seulement la police
    /// du systeme.
    private func police(corps: Double) -> CTFont {
        let base = CTFontCreateUIFontForLanguage(.system, corps, nil)
            ?? CTFontCreateWithName(Self.nomDeRepli as CFString, corps, nil)

        guard graisse != .normale else { return base }

        let traits = [
            kCTFontWeightTrait: NSNumber(value: Self.poids(de: graisse)),
        ] as CFDictionary

        let descripteur = CTFontDescriptorCreateCopyWithAttributes(
            CTFontCopyFontDescriptor(base),
            [kCTFontTraitsAttribute: traits] as CFDictionary
        )

        return CTFontCreateWithFontDescriptor(descripteur, corps, nil)
    }

    /// Police de repli, quand le systeme ne rend pas sa police d interface.
    ///
    /// Le cas ne se produit pas sur un appareil sain. Il existe pour que la
    /// mesure ne soit jamais forcee a deballer un optionnel, ce que le projet
    /// interdit hors des tests.
    private static let nomDeRepli = "Helvetica"

    /// Poids CoreText d une graisse de la section 1.5.
    ///
    /// L echelle de CoreText va de moins un a un, celle du document de quatre
    /// cents a sept cents. Les trois valeurs sont celles que le systeme emploie
    /// pour `regular`, `semibold` et `bold`.
    private static func poids(de graisse: Graisse) -> Double {
        switch graisse {
        case .normale: 0
        case .semiGrasse: 0.3
        case .grasse: 0.4
        }
    }
}
