import Core
import Foundation

//
// DocumentInterprete
//
// Ce qu un serveur a repondu, et les elements qu on y designe.
//
// Les deux formats du langage declaratif se rejoignent ici sous une seule
// forme, pour que `InterpreteDExtension` n ait pas a distinguer un document
// JSON d une page HTML a chaque champ lu. La distinction se fait une fois, a la
// lecture, et le reste du chemin est commun.
//
// Aucun cas par defaut ne devine. Un chemin JSON applique a une page HTML rend
// une liste vide, pas un resultat approximatif : le manifeste refuse deja ce
// melange, et ce qui passerait quand meme ne doit surtout pas etre interprete
// de travers.
//

/// Un document recu, sous la forme que son format impose.
public enum DocumentInterprete: Sendable {
    case json(ValeurJson)
    case html(DocumentHtml)

    /// Lit les octets recus selon le format que la regle annonce.
    ///
    /// - Throws: `ErreurReseau.reponseVide` sur un corps vide, et
    ///   `.reponseIllisible` quand un document JSON ne se decode pas.
    public static func lire(_ donnees: Data, format: FormatDeReponse) throws -> DocumentInterprete {
        guard donnees.isEmpty == false else {
            throw ErreurReseau.reponseVide
        }

        switch format {
        case .json:
            guard let arbre = try? ValeurJson(donnees: donnees) else {
                throw ErreurReseau.reponseIllisible
            }

            return .json(arbre)
        case .html:
            return .html(DocumentHtml(donnees: donnees))
        }
    }

    /// Le document entier, vu comme un element.
    public var racine: ElementInterprete {
        switch self {
        case let .json(arbre): .json(arbre)
        case let .html(document): .html(document: document, index: 0)
        }
    }

    /// Les elements que cette extraction designe dans le document.
    public func elements(_ extraction: Extraction) -> [ElementInterprete] {
        racine.elements(extraction)
    }
}

/// Un element d un document, sur lequel les correspondances de champs
/// s appliquent.
public enum ElementInterprete: Sendable {
    case json(ValeurJson)
    case html(document: DocumentHtml, index: Int)

    /// Les elements que cette extraction designe sous celui ci.
    ///
    /// Pour un document HTML, l element de depart peut lui meme correspondre :
    /// une correspondance de champ ecrite `{"html": "img", "attribut": "src"}`
    /// et appliquee a une image doit rendre cette image.
    public func elements(_ extraction: Extraction) -> [ElementInterprete] {
        switch (self, extraction) {
        case let (.json(valeur), .json(chemin)):
            chemin.valeurs(dans: valeur).map(ElementInterprete.json)
        case let (.html(document, index), .html(selecteur, _)):
            document
                .selectionner(selecteur, depuis: index, inclureLeDepart: index != 0)
                .map { .html(document: document, index: $0) }
        default:
            // Le manifeste refuse deja un selecteur dans une regle JSON, ce cas
            // ne devrait donc pas exister. Rendre vide plutot que lever garde
            // la garantie meme si une regle passait entre les mailles.
            []
        }
    }

    /// La premiere valeur textuelle que cette extraction rend ici.
    public func texte(_ extraction: Extraction?) -> String? {
        guard let extraction else {
            return nil
        }

        return textes(extraction).first
    }

    /// Toutes les valeurs textuelles que cette extraction rend ici.
    ///
    /// Les valeurs vides sont ecartees : un attribut present mais vide et un
    /// attribut absent decrivent le meme fait, et les distinguer obligerait
    /// chaque appelant a tester les deux.
    public func textes(_ extraction: Extraction?) -> [String] {
        guard let extraction else {
            return []
        }

        return elements(extraction).compactMap { $0.valeurLue(extraction) }
    }

    /// La premiere valeur numerique que cette extraction rend ici.
    public func nombre(_ extraction: Extraction?) -> Double? {
        texte(extraction).flatMap(Double.init)
    }

    /// Ce que l extraction lit sur cet element.
    private func valeurLue(_ extraction: Extraction) -> String? {
        switch (self, extraction) {
        case let (.json(valeur), .json):
            let lue = valeur.texteLisible

            return lue?.isEmpty == false ? lue : nil
        case let (.html(document, index), .html(_, valeur)):
            return document.valeur(valeur, de: index)
        default:
            return nil
        }
    }
}
