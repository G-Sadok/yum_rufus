import CoreGraphics
import Foundation

//
// GeometrieSvg
//
// Les primitives geometriques du document : les six formes de base et
// l attribut `transform`.
//
// Toutes les formes sont ramenees a un `CGPath`. Le rasterisateur n a donc
// qu une seule facon de peindre, et le style s applique de la meme maniere a
// un rectangle et a un chemin, ce que la specification demande.
//

/// Les elements dessinables que le rasterisateur sait rendre.
enum FormeSvg: String {
    case rect
    case circle
    case ellipse
    case line
    case polyline
    case polygon
    case path

    /// Chemin de la forme, dans le repere du document.
    ///
    /// Rend nil quand les attributs decrivent une forme sans surface : un
    /// rectangle de largeur nulle, un cercle de rayon nul. La specification
    /// veut qu elle ne soit pas rendue, et un chemin vide couterait un appel de
    /// peinture pour rien.
    func chemin(attributs: [String: String]) -> CGPath? {
        switch self {
        case .rect: Self.rectangle(attributs)
        case .circle: Self.ellipse(attributs, rayonUnique: true)
        case .ellipse: Self.ellipse(attributs, rayonUnique: false)
        case .line: Self.segment(attributs)
        case .polyline: Self.ligneBrisee(attributs, fermee: false)
        case .polygon: Self.ligneBrisee(attributs, fermee: true)
        case .path: Self.cheminDecrit(attributs)
        }
    }

    private static func rectangle(_ attributs: [String: String]) -> CGPath? {
        let largeur = nombre(attributs, "width")
        let hauteur = nombre(attributs, "height")

        guard largeur > 0, hauteur > 0 else { return nil }

        let cadre = CGRect(
            x: nombre(attributs, "x"),
            y: nombre(attributs, "y"),
            width: largeur,
            height: hauteur
        )

        // Un seul des deux rayons suffit a arrondir les angles, l autre le
        // reprend. C est la regle de la specification, et les exportateurs ne
        // fournissent souvent que `rx`.
        let rayonX = attributs["rx"].flatMap(Double.init)
        let rayonY = attributs["ry"].flatMap(Double.init)
        let arrondiX = rayonX ?? rayonY ?? 0
        let arrondiY = rayonY ?? rayonX ?? 0

        guard arrondiX > 0, arrondiY > 0 else {
            return CGPath(rect: cadre, transform: nil)
        }

        return CGPath(
            roundedRect: cadre,
            cornerWidth: min(arrondiX, largeur / 2),
            cornerHeight: min(arrondiY, hauteur / 2),
            transform: nil
        )
    }

    private static func ellipse(_ attributs: [String: String], rayonUnique: Bool) -> CGPath? {
        let rayonX = rayonUnique ? nombre(attributs, "r") : nombre(attributs, "rx")
        let rayonY = rayonUnique ? nombre(attributs, "r") : nombre(attributs, "ry")

        guard rayonX > 0, rayonY > 0 else { return nil }

        let cadre = CGRect(
            x: nombre(attributs, "cx") - rayonX,
            y: nombre(attributs, "cy") - rayonY,
            width: rayonX * 2,
            height: rayonY * 2
        )

        return CGPath(ellipseIn: cadre, transform: nil)
    }

    private static func segment(_ attributs: [String: String]) -> CGPath? {
        let chemin = CGMutablePath()
        chemin.move(to: CGPoint(x: nombre(attributs, "x1"), y: nombre(attributs, "y1")))
        chemin.addLine(to: CGPoint(x: nombre(attributs, "x2"), y: nombre(attributs, "y2")))

        return chemin
    }

    private static func ligneBrisee(_ attributs: [String: String], fermee: Bool) -> CGPath? {
        let valeurs = LecteurDeNombres.tousLesNombres(de: attributs["points"] ?? "")

        guard valeurs.count >= 4 else { return nil }

        let chemin = CGMutablePath()
        chemin.move(to: CGPoint(x: valeurs[0], y: valeurs[1]))

        for rang in stride(from: 2, to: valeurs.count - 1, by: 2) {
            chemin.addLine(to: CGPoint(x: valeurs[rang], y: valeurs[rang + 1]))
        }

        if fermee {
            chemin.closeSubpath()
        }

        return chemin
    }

    private static func cheminDecrit(_ attributs: [String: String]) -> CGPath? {
        guard let donnees = attributs["d"], donnees.isEmpty == false else { return nil }

        let chemin = CheminSvg.chemin(depuis: donnees)

        return chemin.isEmpty ? nil : chemin
    }

    /// Valeur numerique d un attribut, zero quand il manque ou ne se lit pas.
    private static func nombre(_ attributs: [String: String], _ nom: String) -> Double {
        attributs[nom].flatMap(Double.init) ?? 0
    }
}

/// Lecture de l attribut `transform`.
enum TransformationSvg {
    /// Transformation decrite par une liste de fonctions.
    ///
    /// Les fonctions s appliquent de la gauche vers la droite au repere, donc
    /// de la droite vers la gauche a un point. `translate(10 0) scale(2)`
    /// double les coordonnees puis decale de dix, et non l inverse.
    static func transformation(depuis texte: String) -> CGAffineTransform {
        var resultat = CGAffineTransform.identity

        for (nom, arguments) in fonctions(dans: texte) {
            resultat = fonction(nom: nom, arguments: arguments).concatenating(resultat)
        }

        return resultat
    }

    /// Couples nom et arguments, dans l ordre du texte.
    private static func fonctions(dans texte: String) -> [(String, [Double])] {
        var resultat: [(String, [Double])] = []
        var nom = ""
        var arguments = ""
        var dansLesArguments = false

        for caractere in texte {
            switch caractere {
            case "(":
                dansLesArguments = true
            case ")":
                resultat.append((
                    nom.trimmingCharacters(in: .whitespacesAndNewlines),
                    LecteurDeNombres.tousLesNombres(de: arguments)
                ))
                nom = ""
                arguments = ""
                dansLesArguments = false
            default:
                if dansLesArguments {
                    arguments.append(caractere)
                } else if caractere.isWhitespace == false, caractere != "," {
                    nom.append(caractere)
                }
            }
        }

        return resultat
    }

    private static func fonction(nom: String, arguments: [Double]) -> CGAffineTransform {
        switch nom {
        case "translate": translation(arguments)
        case "scale": echelle(arguments)
        case "rotate": rotation(arguments)
        case "matrix": matrice(arguments)
        case "skewX": inclinaison(arguments, horizontale: true)
        case "skewY": inclinaison(arguments, horizontale: false)
        default: .identity
        }
    }

    private static func translation(_ arguments: [Double]) -> CGAffineTransform {
        guard let horizontale = arguments.first else { return .identity }

        return CGAffineTransform(
            translationX: horizontale,
            y: arguments.count > 1 ? arguments[1] : 0
        )
    }

    /// Mise a l echelle, le second facteur reprenant le premier quand il manque.
    private static func echelle(_ arguments: [Double]) -> CGAffineTransform {
        guard let horizontale = arguments.first else { return .identity }

        return CGAffineTransform(
            scaleX: horizontale,
            y: arguments.count > 1 ? arguments[1] : horizontale
        )
    }

    /// Rotation, autour de l origine ou autour d un centre donne.
    private static func rotation(_ arguments: [Double]) -> CGAffineTransform {
        guard let degres = arguments.first else { return .identity }

        let tour = CGAffineTransform(rotationAngle: degres * .pi / 180)

        guard arguments.count >= 3 else { return tour }

        return CGAffineTransform(translationX: arguments[1], y: arguments[2])
            .rotated(by: degres * .pi / 180)
            .translatedBy(x: -arguments[1], y: -arguments[2])
    }

    private static func matrice(_ arguments: [Double]) -> CGAffineTransform {
        guard arguments.count >= 6 else { return .identity }

        return CGAffineTransform(
            a: arguments[0],
            b: arguments[1],
            c: arguments[2],
            d: arguments[3],
            tx: arguments[4],
            ty: arguments[5]
        )
    }

    private static func inclinaison(_ arguments: [Double], horizontale: Bool) -> CGAffineTransform {
        guard let degres = arguments.first else { return .identity }

        let tangente = tan(degres * .pi / 180)

        return horizontale
            ? CGAffineTransform(a: 1, b: 0, c: tangente, d: 1, tx: 0, ty: 0)
            : CGAffineTransform(a: 1, b: tangente, c: 0, d: 1, tx: 0, ty: 0)
    }
}
