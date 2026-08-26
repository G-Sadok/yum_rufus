import Foundation

//
// GabaritDExtension
//
// Les adresses qu une extension demande, et la seule composition de chaine que
// le langage declaratif autorise.
//
// Un gabarit est un texte a trous, et les trous ne peuvent citer que les cinq
// variables de `VariableDeGabarit`. C est ce qui empeche une extension de
// construire une adresse a partir d une valeur que nous ne lui avons pas
// donnee : une accolade qui cite autre chose fait refuser le manifeste entier.
//
// Il n y a pas de verbe dans une regle de requete. Toutes les requetes d une
// extension sont des lectures. Un manifeste ne peut donc pas faire publier quoi
// que ce soit sur un serveur au nom de l utilisateur, ce qui serait le premier
// usage detourne du systeme.
//

/// Ce qu un gabarit d adresse peut citer.
///
/// L enumeration est fermee, et c est ce qui empeche une extension de
/// construire une adresse a partir d une valeur que nous ne lui avons pas
/// donnee. Une variable inconnue fait refuser le manifeste.
public enum VariableDeGabarit: String, Sendable, Codable, CaseIterable, Hashable {
    /// Texte saisi dans le champ de recherche.
    case texteRecherche

    /// Numero de page demande, decale par `ReglesDExtension.pageDeDepart`.
    case page

    /// Langue demandee, au format BCP 47.
    case langue

    /// Identifiant de serie chez la source.
    case identifiantSerie

    /// Identifiant de chapitre chez la source.
    case identifiantChapitre
}

/// Ce qu un gabarit sait remplir.
public struct ContexteDeGabarit: Sendable, Hashable {
    public var texteRecherche: String
    public var page: Int
    public var langue: String
    public var identifiantSerie: String
    public var identifiantChapitre: String

    public init(
        texteRecherche: String = "",
        page: Int = 0,
        langue: String = "",
        identifiantSerie: String = "",
        identifiantChapitre: String = ""
    ) {
        self.texteRecherche = texteRecherche
        self.page = page
        self.langue = langue
        self.identifiantSerie = identifiantSerie
        self.identifiantChapitre = identifiantChapitre
    }

    /// Valeur d une variable dans ce contexte.
    func valeur(de variable: VariableDeGabarit) -> String {
        switch variable {
        case .texteRecherche: texteRecherche
        case .page: String(page)
        case .langue: langue
        case .identifiantSerie: identifiantSerie
        case .identifiantChapitre: identifiantChapitre
        }
    }
}

/// Un morceau de gabarit, litteral ou variable.
public enum MorceauDeGabarit: Sendable, Hashable {
    case litteral(String)
    case variable(VariableDeGabarit)
}

/// Un texte a trous, pour un chemin d API ou une valeur de parametre.
///
///     /api/series/{identifiantSerie}/books
public struct GabaritDeTexte: Sendable, Hashable {
    public let morceaux: [MorceauDeGabarit]

    public init(morceaux: [MorceauDeGabarit]) {
        self.morceaux = morceaux
    }

    /// Analyse la forme textuelle d un gabarit.
    ///
    /// - Throws: `ErreurDExtension.variableInconnue` quand une accolade cite un
    ///   nom qui n est pas une variable, et
    ///   `ErreurDExtension.extractionMalFormee` quand une accolade n est pas
    ///   fermee.
    public init(_ texte: String) throws {
        morceaux = try Self.analyser(texte)
    }

    /// Le texte, variables remplacees par leur valeur dans ce contexte.
    public func remplir(_ contexte: ContexteDeGabarit) -> String {
        morceaux.reduce(into: "") { assemble, morceau in
            switch morceau {
            case let .litteral(texte): assemble += texte
            case let .variable(variable): assemble += contexte.valeur(de: variable)
            }
        }
    }

    /// Les variables citees par ce gabarit.
    public var variablesCitees: Set<VariableDeGabarit> {
        Set(morceaux.compactMap { morceau in
            guard case let .variable(variable) = morceau else {
                return nil
            }

            return variable
        })
    }

    /// Forme textuelle canonique, celle qui se relit par `init(_:)`.
    public var texte: String {
        morceaux.reduce(into: "") { assemble, morceau in
            switch morceau {
            case let .litteral(texte): assemble += texte
            case let .variable(variable): assemble += "{\(variable.rawValue)}"
            }
        }
    }

    /// Decoupe le texte en litteraux et en variables.
    private static func analyser(_ texte: String) throws -> [MorceauDeGabarit] {
        var morceaux: [MorceauDeGabarit] = []
        var restant = Substring(texte)

        while let ouverture = restant.firstIndex(of: "{") {
            guard let fermeture = restant[ouverture...].firstIndex(of: "}") else {
                throw ErreurDExtension.extractionMalFormee(texte: texte)
            }

            let avant = restant[restant.startIndex..<ouverture]

            if avant.isEmpty == false {
                morceaux.append(.litteral(String(avant)))
            }

            let nom = String(restant[restant.index(after: ouverture)..<fermeture])

            guard let variable = VariableDeGabarit(rawValue: nom) else {
                throw ErreurDExtension.variableInconnue(nom: nom)
            }

            morceaux.append(.variable(variable))
            restant = restant[restant.index(after: fermeture)...]
        }

        if restant.isEmpty == false {
            morceaux.append(.litteral(String(restant)))
        }

        return morceaux
    }
}

extension GabaritDeTexte: Codable {
    public init(from decodeur: any Decoder) throws {
        let conteneur = try decodeur.singleValueContainer()

        try self.init(conteneur.decode(String.self))
    }

    public func encode(to encodeur: any Encoder) throws {
        var conteneur = encodeur.singleValueContainer()

        try conteneur.encode(texte)
    }
}

// MARK: - Requete

/// Un parametre de requete, dont la valeur est un gabarit.
public struct ParametreDeRequete: Sendable, Hashable, Codable {
    public let nom: String
    public let valeur: GabaritDeTexte

    public init(nom: String, valeur: GabaritDeTexte) {
        self.nom = nom
        self.valeur = valeur
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case nom
        case valeur
    }
}

/// Ce qu il faut demander au serveur pour obtenir un document.
///
/// Il n y a pas de verbe : toutes les requetes d une extension sont des `GET`.
/// Un manifeste ne peut donc pas faire publier quoi que ce soit sur un serveur
/// au nom de l utilisateur, ce qui serait le premier usage detourne du systeme.
public struct RegleDeRequete: Sendable, Hashable, Codable {
    /// Chemin ajoute a l adresse de base.
    public let chemin: GabaritDeTexte

    /// Parametres de la chaine de requete.
    public let parametres: [ParametreDeRequete]

    /// Forme du document attendu en reponse.
    public let format: FormatDeReponse

    public init(chemin: GabaritDeTexte, parametres: [ParametreDeRequete] = [], format: FormatDeReponse) {
        self.chemin = chemin
        self.parametres = parametres
        self.format = format
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case chemin
        case parametres
        case format
    }

    public init(from decodeur: any Decoder) throws {
        let conteneur = try decodeur.container(keyedBy: CodingKeys.self)

        chemin = try conteneur.decode(GabaritDeTexte.self, forKey: .chemin)
        parametres = try conteneur.decodeIfPresent([ParametreDeRequete].self, forKey: .parametres) ?? []
        format = try conteneur.decode(FormatDeReponse.self, forKey: .format)
    }

    /// Les variables citees par le chemin et par les parametres.
    public var variablesCitees: Set<VariableDeGabarit> {
        parametres.reduce(into: chemin.variablesCitees) { citees, parametre in
            citees.formUnion(parametre.valeur.variablesCitees)
        }
    }
}
