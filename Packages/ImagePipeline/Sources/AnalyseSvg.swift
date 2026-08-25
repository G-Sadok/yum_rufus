import CoreGraphics
import Foundation

//
// AnalyseSvg
//
// Lecture d un document SVG vers une liste de formes peintes, prete a rendre.
//
// Aucun systeme Apple ne declare `public.svg-image` en lecture. Image I/O
// refuse donc le format, et la section 5.2 le demande. Le paquet le lit lui
// meme, avec l analyseur XML de Foundation, present sur les deux plateformes.
//
// La couverture est celle d un dessin au trait, ce que sont les rares pages
// SVG d un chapitre et les illustrations de couverture : les six formes de
// base, les chemins, les groupes, les transformations et la peinture unie.
// Ce qui suppose une cascade CSS, une police, un degrade ou une image liee
// n est pas rendu, et l element concerne est ignore plutot que mal dessine.
//
// L arbre n est pas conserve. Chaque forme est ramenee des la lecture dans le
// repere du document, transformation des parents comprise, et le style herite
// y est fige. Le rasterisateur n a plus qu une liste plate a peindre, ce qui
// evite de retraverser un arbre pour chaque taille demandee.
//

/// Une forme du document, ramenee au repere du document et prete a peindre.
struct PeintureSvg {
    let chemin: CGPath
    let style: StyleSvg
}

/// Document SVG lu, sans dependance a une taille de rendu.
struct DocumentSvg {
    /// Zone du document couverte par le dessin, l attribut `viewBox`.
    let cadre: CGRect

    /// Taille propre du document, celle qu il occupe sans contrainte.
    let taille: CGSize

    /// Formes a peindre, dans l ordre du document.
    let peintures: [PeintureSvg]

    /// Lit un document, ou rend nil quand il n en est pas un.
    static func lire(_ donnees: Data) -> DocumentSvg? {
        let assembleur = AssembleurSvg()
        let analyseur = XMLParser(data: donnees)
        analyseur.delegate = assembleur
        analyseur.shouldResolveExternalEntities = false

        // Un document tronque a deja livre ses premieres formes. On les garde :
        // une page a demi dessinee reste plus utile qu une page de remplacement,
        // et l analyseur signale l erreur sans effacer ce qu il a lu.
        analyseur.parse()

        return assembleur.document()
    }
}

/// Delegue d analyse, qui aplatit l arbre au fil de la lecture.
private final class AssembleurSvg: NSObject, XMLParserDelegate {
    private var pileDeStyles: [StyleSvg] = [StyleSvg()]
    private var pileDeTransformations: [CGAffineTransform] = [.identity]
    private var profondeurIgnoree = 0
    private var peintures: [PeintureSvg] = []
    private var cadre: CGRect?
    private var taille: CGSize?

    /// Elements dont le contenu n est pas dessine sur place.
    ///
    /// Les definitions, les masques et les motifs ne se peignent que reprises
    /// par un `use`, que ce lecteur ne suit pas. Les rendre en place les ferait
    /// apparaitre en double et au mauvais endroit, ce qui est pire que de ne
    /// pas les rendre.
    private static let elementsIgnores: Set<String> = [
        "defs", "clipPath", "mask", "symbol", "marker", "pattern",
        "filter", "style", "text", "title", "desc", "metadata", "switch",
    ]

    func document() -> DocumentSvg? {
        guard let cadre, cadre.width > 0, cadre.height > 0 else { return nil }

        return DocumentSvg(
            cadre: cadre,
            taille: taille ?? cadre.size,
            peintures: peintures
        )
    }

    func parser(
        _ parser: XMLParser,
        didStartElement element: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes attributs: [String: String]
    ) {
        guard profondeurIgnoree == 0 else {
            profondeurIgnoree += 1
            return
        }

        guard Self.elementsIgnores.contains(element) == false else {
            profondeurIgnoree = 1
            return
        }

        empiler(attributs)

        if element == "svg", cadre == nil {
            lireLaRacine(attributs)
        }

        if let forme = FormeSvg(rawValue: element), let chemin = forme.chemin(attributs: attributs) {
            ajouter(chemin)
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement element: String,
        namespaceURI: String?,
        qualifiedName: String?
    ) {
        guard profondeurIgnoree == 0 else {
            profondeurIgnoree -= 1
            return
        }

        if pileDeStyles.count > 1 {
            pileDeStyles.removeLast()
            pileDeTransformations.removeLast()
        }
    }

    // MARK: Assemblage

    private func empiler(_ attributs: [String: String]) {
        let style = (pileDeStyles.last ?? StyleSvg()).herite(de: attributs)
        let propre = TransformationSvg.transformation(depuis: attributs["transform"] ?? "")

        pileDeStyles.append(style)
        pileDeTransformations.append(propre.concatenating(pileDeTransformations.last ?? .identity))
    }

    /// Ajoute une forme, ramenee au repere du document.
    ///
    /// L epaisseur du contour subit la meme mise a l echelle que la forme. Elle
    /// est ramenee par la racine du determinant, qui est le facteur exact d une
    /// transformation uniforme et une moyenne raisonnable des deux facteurs
    /// d une transformation qui ne l est pas.
    private func ajouter(_ chemin: CGPath) {
        guard var style = pileDeStyles.last,
              var transformation = pileDeTransformations.last
        else {
            return
        }

        let determinant = abs(transformation.a * transformation.d - transformation.b * transformation.c)
        style.epaisseurDeContour *= determinant.squareRoot()

        guard let place = chemin.copy(using: &transformation) else { return }

        peintures.append(PeintureSvg(chemin: place, style: style))
    }

    private func lireLaRacine(_ attributs: [String: String]) {
        let dimensions = CGSize(
            width: Self.longueur(attributs["width"]) ?? 0,
            height: Self.longueur(attributs["height"]) ?? 0
        )

        if let boite = Self.viewBox(attributs["viewBox"]) {
            cadre = boite
            taille = dimensions.width > 0 && dimensions.height > 0 ? dimensions : boite.size
        } else if dimensions.width > 0, dimensions.height > 0 {
            cadre = CGRect(origin: .zero, size: dimensions)
            taille = dimensions
        }
    }

    private static func viewBox(_ valeur: String?) -> CGRect? {
        guard let valeur else { return nil }

        let nombres = LecteurDeNombres.tousLesNombres(de: valeur)

        guard nombres.count >= 4, nombres[2] > 0, nombres[3] > 0 else { return nil }

        return CGRect(x: nombres[0], y: nombres[1], width: nombres[2], height: nombres[3])
    }

    /// Longueur d attribut, unite comprise.
    ///
    /// Les unites absolues sont converties en pixels au taux de la
    /// specification. Un pourcentage n a pas de reference ici, il est ignore et
    /// le cadre prend le relais.
    private static func longueur(_ valeur: String?) -> Double? {
        guard let valeur = valeur?.trimmingCharacters(in: .whitespaces), valeur.hasSuffix("%") == false else {
            return nil
        }

        var lecteur = LecteurDeNombres(valeur)

        guard let nombre = lecteur.prochainNombre(), nombre > 0 else { return nil }

        let unite = valeur.drop(while: { $0.isNumber || $0 == "." || $0 == "-" || $0 == "+" })

        return nombre * (unites[String(unite).lowercased()] ?? 1)
    }

    private static let unites: [String: Double] = [
        "": 1, "px": 1, "pt": 4.0 / 3, "pc": 16, "mm": 96 / 25.4, "cm": 96 / 2.54, "in": 96,
    ]
}
