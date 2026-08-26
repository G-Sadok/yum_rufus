import Core
import Foundation

//
// DocumentHtml
//
// La lecture d une page HTML, pour les extensions dont le catalogue n a pas
// d API et se lit dans la page elle meme.
//
// L arbre est a plat, un tableau d elements relies par des index, et non une
// suite de noeuds imbriques. Trois raisons, dans cet ordre.
//
// La premiere est la selection. Un selecteur descendant designe le meme element
// par plusieurs chemins, `div a` le trouve une fois par `div` ancetre. Il faut
// donc dedoublonner, et dedoublonner des valeurs imbriquees confondrait deux
// freres identiques, ce qui arrive tout le temps dans une grille de vignettes.
// Un index designe un element et un seul.
//
// La deuxieme est la profondeur. Une page reelle imbrique parfois plusieurs
// centaines de niveaux quand elle est mal fermee, et un arbre de valeurs
// Swift se copie a chaque remontee.
//
// La troisieme est l ordre du document. Les regles rendent des listes, et
// l ordre des pages d un chapitre est justement ce qu il ne faut pas perdre.
// Trier des index le garantit.
//
// L analyse est tolerante, parce qu une page reelle l exige : balises non
// fermees, attributs sans guillemets, commentaires, doctype, script et style.
// Elle ne construit jamais rien d executable. Le contenu des balises `script`
// et `style` est jete a la lecture, il n atteint meme pas l arbre.
//

/// Un element d une page HTML.
public struct ElementHtml: Sendable, Hashable {
    /// Rang de l element dans le document, qui est aussi son identite.
    public let index: Int

    /// Element qui le contient, nul pour la racine du document.
    public let parent: Int?

    /// Nom de balise, en minuscules. Vide pour la racine.
    public let balise: String

    /// Attributs, noms en minuscules.
    public let attributs: [String: String]

    /// Contenu, dans l ordre du document.
    public let contenu: [FragmentHtml]

    /// Les elements contenus directement, dans l ordre.
    public var enfants: [Int] {
        contenu.compactMap { fragment in
            guard case let .element(index) = fragment else {
                return nil
            }

            return index
        }
    }
}

/// Un morceau de contenu, texte ou element.
public enum FragmentHtml: Sendable, Hashable {
    case texte(String)
    case element(Int)
}

/// Une page HTML lue.
public struct DocumentHtml: Sendable, Hashable {
    /// Les elements, dans l ordre du document. Le premier est la racine.
    public let elements: [ElementHtml]

    /// Lit une page depuis ses octets.
    ///
    /// L encodage est suppose UTF-8, avec repli sur Latin 1. Un catalogue qui
    /// publie dans un troisieme encodage sera lu de travers plutot que refuse :
    /// une page a moitie lisible vaut mieux qu une source vide, et le cas se
    /// verra dans les titres.
    public init(donnees: Data) {
        let texte = String(data: donnees, encoding: .utf8)
            ?? String(data: donnees, encoding: .isoLatin1)
            ?? ""

        self.init(texte)
    }

    /// Lit une page deja decodee.
    public init(_ texte: String) {
        elements = AnalyseHtml.analyser(texte)
    }

    /// L element racine, celui qui contient toute la page.
    public var racine: ElementHtml? {
        elements.first
    }

    /// L element de ce rang.
    public func element(_ index: Int) -> ElementHtml? {
        elements.indices.contains(index) ? elements[index] : nil
    }

    /// Le texte de cet element et de tout ce qu il contient, espaces
    /// normalises.
    ///
    /// La normalisation ramene toute suite d espaces, de tabulations et de
    /// retours a la ligne a une espace unique, et coupe aux extremites. Sans
    /// elle, un titre indente dans la page arriverait avec son indentation, et
    /// deux catalogues qui presentent la meme serie ne rendraient pas le meme
    /// titre.
    public func texte(de index: Int) -> String {
        Self.normaliser(texteBrut(de: index))
    }

    /// La valeur d un attribut de cet element.
    public func attribut(_ nom: String, de index: Int) -> String? {
        element(index)?.attributs[nom.lowercased()]
    }

    /// Ce que cette valeur d element lit sur cet element.
    public func valeur(_ valeur: ValeurDElement, de index: Int) -> String? {
        switch valeur {
        case .texte:
            let lu = texte(de: index)

            return lu.isEmpty ? nil : lu
        case let .attribut(nom):
            return attribut(nom, de: index)
        }
    }

    /// Le texte brut, avant normalisation.
    private func texteBrut(de index: Int) -> String {
        guard let element = element(index) else {
            return ""
        }

        return element.contenu.reduce(into: "") { assemble, fragment in
            switch fragment {
            case let .texte(morceau): assemble += morceau
            case let .element(enfant): assemble += texteBrut(de: enfant)
            }
        }
    }

    /// Ramene les blancs a une espace unique et coupe aux extremites.
    private static func normaliser(_ texte: String) -> String {
        texte
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}

// MARK: - Selection

extension DocumentHtml {
    /// Les elements que ce selecteur designe, dans l ordre du document.
    ///
    /// - Parameters:
    ///   - selecteur: le selecteur a appliquer.
    ///   - depuis: element de depart, la racine du document par defaut.
    ///   - inclureLeDepart: vrai quand l element de depart peut lui meme
    ///     correspondre a la premiere etape. C est le cas quand une regle
    ///     cherche un champ dans un element deja designe : `{"html": "img"}`
    ///     applique a une image doit rendre cette image, et non rien.
    public func selectionner(
        _ selecteur: SelecteurHtml,
        depuis depart: Int = 0,
        inclureLeDepart: Bool = false
    ) -> [Int] {
        guard let premiere = selecteur.etapes.first else {
            return []
        }

        var retenus = candidats(sous: depart, inclureLeDepart: inclureLeDepart)
            .filter { correspond(elements[$0], a: premiere) }

        for etape in selecteur.etapes.dropFirst() {
            var suivants: Set<Int> = []

            for index in retenus {
                let candidats = etape.combinateur == .enfant
                    ? elements[index].enfants
                    : descendants(de: index)

                suivants.formUnion(candidats.filter { correspond(elements[$0], a: etape) })
            }

            retenus = suivants.sorted()
        }

        return retenus
    }

    /// Les elements ou la premiere etape peut s appliquer.
    private func candidats(sous depart: Int, inclureLeDepart: Bool) -> [Int] {
        guard element(depart) != nil else {
            return []
        }

        return inclureLeDepart ? [depart] + descendants(de: depart) : descendants(de: depart)
    }

    /// Tous les elements contenus, a n importe quelle profondeur, dans l ordre.
    ///
    /// L index d un element est son rang dans le document, et un descendant est
    /// toujours lu apres son ancetre : trier les index rend donc l ordre du
    /// document sans avoir a le reconstituer.
    private func descendants(de index: Int) -> [Int] {
        guard let element = element(index) else {
            return []
        }

        return element.enfants.flatMap { [$0] + descendants(de: $0) }
    }

    /// Vrai quand l element satisfait toutes les contraintes de l etape.
    private func correspond(_ element: ElementHtml, a etape: EtapeDeSelecteur) -> Bool {
        if let balise = etape.balise, element.balise != balise {
            return false
        }
        if let identifiant = etape.identifiant, element.attributs["id"] != identifiant {
            return false
        }

        let classes = Set((element.attributs["class"] ?? "").split(whereSeparator: \.isWhitespace).map(String.init))

        guard etape.classes.allSatisfy({ classes.contains($0) }) else {
            return false
        }

        return etape.attributs.allSatisfy { $0.estSatisfaite(par: element.attributs[$0.nom]) }
    }
}
