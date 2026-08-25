import CoreGraphics
import Foundation

//
// StyleSvg
//
// Peinture d une forme SVG : remplissage, contour, epaisseur, opacite.
//
// Le style d un element est celui de son parent, modifie par ses propres
// attributs. C est la seule raison pour laquelle il forme un type a part :
// l heritage suppose de pouvoir partir d une copie du style courant et de n en
// changer que ce que l element declare.
//
// Les couleurs se lisent sous les trois formes que produisent les
// exportateurs : notation abregee a trois chiffres, notation a six chiffres,
// et fonction `rgb`. Les noms de couleur sont limites aux quinze de la norme
// HTML d origine, les seuls qu un dessin au trait emploie encore. Un nom
// inconnu vaut noir, ce qui laisse la forme visible plutot que de la faire
// disparaitre.
//

/// Peinture heritee et modifiee le long de l arbre du document.
struct StyleSvg: Equatable {
    /// Couleur de remplissage, nil pour `none`.
    var remplissage: CouleurSvg? = .noir

    /// Couleur du contour, nil pour `none`.
    var contour: CouleurSvg?

    /// Epaisseur du contour, en unites du document.
    var epaisseurDeContour: Double = 1

    /// Opacite propre du remplissage.
    var opaciteDeRemplissage: Double = 1

    /// Opacite propre du contour.
    var opaciteDeContour: Double = 1

    /// Opacite du groupe, multipliee aux deux autres.
    var opaciteDeGroupe: Double = 1

    /// Regle de remplissage, `nonzero` par defaut.
    var regleDeRemplissage: CGPathFillRule = .winding

    /// Forme du bout d un contour ouvert.
    var extremite: CGLineCap = .butt

    /// Forme de la jonction entre deux segments.
    var jointure: CGLineJoin = .miter

    /// Couleur de remplissage effective, opacites appliquees.
    var remplissageEffectif: CGColor? {
        remplissage?.couleur(opacite: opaciteDeRemplissage * opaciteDeGroupe)
    }

    /// Couleur de contour effective, opacites appliquees.
    var contourEffectif: CGColor? {
        guard epaisseurDeContour > 0 else { return nil }

        return contour?.couleur(opacite: opaciteDeContour * opaciteDeGroupe)
    }

    /// Style modifie par les attributs de presentation d un element.
    ///
    /// L attribut `style` est lu en premier, les attributs de presentation
    /// ensuite : la cascade CSS veut l inverse, mais aucun exportateur ne
    /// produit les deux formes pour une meme propriete sur un meme element, et
    /// l ordre retenu evite d avoir a porter une cascade complete ici.
    func herite(de attributs: [String: String]) -> StyleSvg {
        var resultat = self

        for (propriete, valeur) in Self.declarations(de: attributs["style"]) {
            resultat.appliquer(propriete: propriete, valeur: valeur)
        }

        for propriete in Self.proprietes {
            if let valeur = attributs[propriete] {
                resultat.appliquer(propriete: propriete, valeur: valeur)
            }
        }

        return resultat
    }

    /// Proprietes de presentation lues sur un element.
    private static let proprietes = [
        "fill", "stroke", "stroke-width", "fill-opacity", "stroke-opacity",
        "opacity", "fill-rule", "stroke-linecap", "stroke-linejoin",
    ]

    private mutating func appliquer(propriete: String, valeur: String) {
        let valeur = valeur.trimmingCharacters(in: .whitespacesAndNewlines)

        switch propriete {
        case "fill": remplissage = CouleurSvg(valeur)
        case "stroke": contour = CouleurSvg(valeur)
        case "stroke-width": epaisseurDeContour = Double(valeur) ?? epaisseurDeContour
        case "fill-opacity": opaciteDeRemplissage = Self.opacite(valeur) ?? opaciteDeRemplissage
        case "stroke-opacity": opaciteDeContour = Self.opacite(valeur) ?? opaciteDeContour
        case "opacity": opaciteDeGroupe *= Self.opacite(valeur) ?? 1
        case "fill-rule": regleDeRemplissage = valeur == "evenodd" ? .evenOdd : .winding
        case "stroke-linecap": extremite = Self.extremite(valeur)
        case "stroke-linejoin": jointure = Self.jointure(valeur)
        default: break
        }
    }

    /// Declarations d un attribut `style`, sous la forme propriete deux points valeur.
    private static func declarations(de style: String?) -> [(String, String)] {
        guard let style else { return [] }

        return style.split(separator: ";").compactMap { declaration in
            let morceaux = declaration.split(separator: ":", maxSplits: 1)

            guard morceaux.count == 2 else { return nil }

            return (
                morceaux[0].trimmingCharacters(in: .whitespacesAndNewlines),
                morceaux[1].trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }

    private static func opacite(_ valeur: String) -> Double? {
        if valeur.hasSuffix("%") {
            return Double(valeur.dropLast()).map { $0 / 100 }
        }

        return Double(valeur)
    }

    private static func extremite(_ valeur: String) -> CGLineCap {
        switch valeur {
        case "round": .round
        case "square": .square
        default: .butt
        }
    }

    private static func jointure(_ valeur: String) -> CGLineJoin {
        switch valeur {
        case "round": .round
        case "bevel": .bevel
        default: .miter
        }
    }
}

/// Couleur unie d un document SVG.
struct CouleurSvg: Equatable {
    let rouge: Double
    let vert: Double
    let bleu: Double

    /// Noir, valeur de remplissage par defaut de la specification.
    static let noir = CouleurSvg(rouge: 0, vert: 0, bleu: 0)

    init(rouge: Double, vert: Double, bleu: Double) {
        self.rouge = rouge
        self.vert = vert
        self.bleu = bleu
    }

    /// Couleur decrite par une valeur d attribut, nil pour `none`.
    init?(_ valeur: String) {
        let valeur = valeur.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard valeur != "none", valeur != "transparent" else { return nil }

        if valeur.hasPrefix("#"), let hexadecimale = Self.hexadecimale(String(valeur.dropFirst())) {
            self = hexadecimale
        } else if valeur.hasPrefix("rgb"), let fonction = Self.fonction(valeur) {
            self = fonction
        } else {
            self = Self.nommees[valeur] ?? .noir
        }
    }

    /// Couleur Core Graphics, opacite appliquee.
    func couleur(opacite: Double) -> CGColor {
        CGColor(
            colorSpace: CGColorSpaceCreateDeviceRGB(),
            components: [rouge, vert, bleu, min(1, max(0, opacite))]
        ) ?? CGColor(gray: 0, alpha: 1)
    }

    /// Notation a trois ou six chiffres, apres le croisillon.
    private static func hexadecimale(_ chiffres: String) -> CouleurSvg? {
        let normalisee: String

        switch chiffres.count {
        case 3: normalisee = chiffres.map { String(repeating: $0, count: 2) }.joined()
        case 6: normalisee = chiffres
        default: return nil
        }

        guard let valeur = UInt32(normalisee, radix: 16) else { return nil }

        return CouleurSvg(
            rouge: Double((valeur >> 16) & 0xFF) / 255,
            vert: Double((valeur >> 8) & 0xFF) / 255,
            bleu: Double(valeur & 0xFF) / 255
        )
    }

    /// Fonction `rgb`, en nombres entiers ou en pourcentages.
    private static func fonction(_ valeur: String) -> CouleurSvg? {
        guard let ouverture = valeur.firstIndex(of: "("),
              let fermeture = valeur.lastIndex(of: ")")
        else {
            return nil
        }

        let arguments = String(valeur[valeur.index(after: ouverture)..<fermeture])
        let pourcentages = arguments.contains("%")
        let nombres = LecteurDeNombres.tousLesNombres(de: arguments)

        guard nombres.count >= 3 else { return nil }

        let echelle = pourcentages ? 100.0 : 255.0

        return CouleurSvg(
            rouge: min(1, max(0, nombres[0] / echelle)),
            vert: min(1, max(0, nombres[1] / echelle)),
            bleu: min(1, max(0, nombres[2] / echelle))
        )
    }

    /// Les quinze couleurs nommees de la norme HTML d origine.
    private static let nommees: [String: CouleurSvg] = [
        "black": CouleurSvg(rouge: 0, vert: 0, bleu: 0),
        "silver": CouleurSvg(rouge: 0.75, vert: 0.75, bleu: 0.75),
        "gray": CouleurSvg(rouge: 0.5, vert: 0.5, bleu: 0.5),
        "grey": CouleurSvg(rouge: 0.5, vert: 0.5, bleu: 0.5),
        "white": CouleurSvg(rouge: 1, vert: 1, bleu: 1),
        "maroon": CouleurSvg(rouge: 0.5, vert: 0, bleu: 0),
        "red": CouleurSvg(rouge: 1, vert: 0, bleu: 0),
        "purple": CouleurSvg(rouge: 0.5, vert: 0, bleu: 0.5),
        "fuchsia": CouleurSvg(rouge: 1, vert: 0, bleu: 1),
        "green": CouleurSvg(rouge: 0, vert: 0.5, bleu: 0),
        "lime": CouleurSvg(rouge: 0, vert: 1, bleu: 0),
        "olive": CouleurSvg(rouge: 0.5, vert: 0.5, bleu: 0),
        "yellow": CouleurSvg(rouge: 1, vert: 1, bleu: 0),
        "navy": CouleurSvg(rouge: 0, vert: 0, bleu: 0.5),
        "blue": CouleurSvg(rouge: 0, vert: 0, bleu: 1),
        "teal": CouleurSvg(rouge: 0, vert: 0.5, bleu: 0.5),
        "aqua": CouleurSvg(rouge: 0, vert: 1, bleu: 1),
    ]
}
