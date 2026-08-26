import Foundation

///
/// ExtractionDExtension
///
/// D ou une regle tire une valeur : un chemin dans un document JSON, ou un
/// element d une page HTML.
///
/// Le type est une enumeration fermee a deux cas, et c est la brique sur
/// laquelle repose le premier critere de la fonctionnalite. Une extension ne
/// decrit pas comment obtenir une valeur, elle designe ou elle se trouve. Il n y
/// a donc rien a executer, seulement un chemin a suivre.
///
/// Forme du document qu un serveur rend pour une regle donnee.
public enum FormatDeReponse: String, Sendable, Codable, CaseIterable, Hashable {
    case json
    case html
}

// MARK: - Extraction

/// D ou une valeur est tiree du document recu.
///
/// Les deux cas correspondent aux deux formats. Une regle qui declare `json` et
/// dont l extraction est un selecteur est refusee a la lecture du manifeste,
/// parce que le contraire ferait rendre une source vide sans jamais dire
/// pourquoi.
public enum Extraction: Sendable, Hashable {
    /// Chemin dans un document JSON.
    case json(CheminJson)

    /// Element d un document HTML, et ce qui s y lit.
    case html(selecteur: SelecteurHtml, valeur: ValeurDElement)

    /// Format de document auquel cette extraction s applique.
    public var format: FormatDeReponse {
        switch self {
        case .json: .json
        case .html: .html
        }
    }
}

extension Extraction: Codable {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case json
        case html
        case attribut
    }

    public init(from decodeur: any Decoder) throws {
        let conteneur = try decodeur.container(keyedBy: CodingKeys.self)

        if let chemin = try conteneur.decodeIfPresent(CheminJson.self, forKey: .json) {
            self = .json(chemin)

            return
        }

        let selecteur = try conteneur.decode(SelecteurHtml.self, forKey: .html)
        let attribut = try conteneur.decodeIfPresent(String.self, forKey: .attribut)

        // L absence d attribut veut dire le texte de l element. C est le cas de
        // loin le plus frequent, et l ecrire explicitement a chaque champ
        // alourdirait tous les manifestes pour un seul cas rare.
        self = .html(selecteur: selecteur, valeur: attribut.map(ValeurDElement.attribut) ?? .texte)
    }

    public func encode(to encodeur: any Encoder) throws {
        var conteneur = encodeur.container(keyedBy: CodingKeys.self)

        switch self {
        case let .json(chemin):
            try conteneur.encode(chemin, forKey: .json)
        case let .html(selecteur, valeur):
            try conteneur.encode(selecteur, forKey: .html)

            if case let .attribut(nom) = valeur {
                try conteneur.encode(nom, forKey: .attribut)
            }
        }
    }
}
