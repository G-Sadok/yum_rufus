import Foundation

//
// CheminJson
//
// Le chemin JSON de la section 4.3, sous la forme reduite que l interprete sait
// appliquer.
//
// Il ne s agit pas de JSONPath complet, et c est voulu. JSONPath accepte des
// filtres et des expressions, c est a dire du code, et le premier critere de la
// fonctionnalite interdit d executer quoi que ce soit qu une extension
// fournirait. Ce chemin la ne sait faire que trois choses : entrer dans une cle,
// prendre un element par son rang, prendre tous les elements. Les trois se
// lisent, se testent et ne calculent rien.
//
// La forme textuelle est celle que les auteurs de regles connaissent :
//
//     $.results[*].id
//     data.items[0].title
//     $
//
// Le `$` de tete est facultatif. Un chemin vide designe la valeur elle meme, ce
// qui sert aux listes de chaines, ou l element est deja la valeur cherchee.
//

/// Une etape d un chemin JSON.
public enum EtapeDeCheminJson: Sendable, Hashable {
    /// Entre dans la cle d un objet.
    case cle(String)

    /// Prend l element de ce rang dans une liste, a partir de zero.
    case rang(Int)

    /// Prend tous les elements d une liste.
    case tousLesElements
}

/// Un chemin de lecture dans un document JSON.
public struct CheminJson: Sendable, Hashable {
    /// Les etapes, dans l ordre de descente.
    public let etapes: [EtapeDeCheminJson]

    public init(etapes: [EtapeDeCheminJson]) {
        self.etapes = etapes
    }

    /// Analyse la forme textuelle d un chemin.
    ///
    /// - Throws: `ErreurDExtension.extractionMalFormee` quand le texte n est pas
    ///   un chemin de cette forme reduite.
    public init(_ texte: String) throws {
        etapes = try Self.analyser(texte)
    }

    /// Vrai quand le chemin designe la valeur elle meme.
    public var estRacine: Bool {
        etapes.isEmpty
    }

    /// Forme textuelle canonique, celle qui se relit par `init(_:)`.
    public var texte: String {
        guard etapes.isEmpty == false else {
            return "$"
        }

        return etapes.reduce(into: "$") { assemblee, etape in
            switch etape {
            case let .cle(nom): assemblee += ".\(nom)"
            case let .rang(index): assemblee += "[\(index)]"
            case .tousLesElements: assemblee += "[*]"
            }
        }
    }

    // MARK: Application

    /// Toutes les valeurs que ce chemin designe dans un document.
    ///
    /// Rend une liste et non une valeur unique parce que `[*]` en designe
    /// plusieurs. Un chemin sans etoile rend zero ou une valeur.
    public func valeurs(dans document: ValeurJson) -> [ValeurJson] {
        etapes.reduce([document]) { courantes, etape in
            courantes.flatMap { etape.appliquer(a: $0) }
        }
    }

    /// La premiere valeur que ce chemin designe, ou nul quand il n en designe
    /// aucune.
    public func valeur(dans document: ValeurJson) -> ValeurJson? {
        valeurs(dans: document).first
    }

    // MARK: Analyse

    /// Decoupe la forme textuelle en etapes.
    private static func analyser(_ texte: String) throws -> [EtapeDeCheminJson] {
        var restant = Substring(texte.trimmingCharacters(in: .whitespaces))

        if restant.first == "$" {
            restant = restant.dropFirst()
        }

        var etapes: [EtapeDeCheminJson] = []

        while restant.isEmpty == false {
            if restant.first == "." {
                try etapes.append(.cle(nomDeCle(&restant, dans: texte)))
            } else if restant.first == "[" {
                try etapes.append(indice(&restant, dans: texte))
            } else if etapes.isEmpty {
                // Un chemin peut commencer par un nom sans point, comme
                // `data.items`. Une fois la premiere etape lue, le point
                // redevient obligatoire, sans quoi `a b` passerait pour un
                // chemin de deux etapes.
                try etapes.append(.cle(nomDeCle(&restant, dans: texte, avecPoint: false)))
            } else {
                throw ErreurDExtension.extractionMalFormee(texte: texte)
            }
        }

        return etapes
    }

    /// Lit un nom de cle, avec ou sans le point qui le precede.
    private static func nomDeCle(
        _ restant: inout Substring,
        dans texte: String,
        avecPoint: Bool = true
    ) throws -> String {
        if avecPoint {
            restant = restant.dropFirst()
        }

        let nom = restant.prefix { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }

        guard nom.isEmpty == false else {
            throw ErreurDExtension.extractionMalFormee(texte: texte)
        }

        restant = restant.dropFirst(nom.count)

        return String(nom)
    }

    /// Lit un indice entre crochets, rang ou etoile.
    private static func indice(_ restant: inout Substring, dans texte: String) throws -> EtapeDeCheminJson {
        restant = restant.dropFirst()

        guard let fin = restant.firstIndex(of: "]") else {
            throw ErreurDExtension.extractionMalFormee(texte: texte)
        }

        let contenu = restant[restant.startIndex..<fin]
        restant = restant[restant.index(after: fin)...]

        if contenu == "*" {
            return .tousLesElements
        }
        guard let rang = Int(contenu), rang >= 0 else {
            throw ErreurDExtension.extractionMalFormee(texte: texte)
        }

        return .rang(rang)
    }
}

// MARK: - Application d une etape

extension EtapeDeCheminJson {
    /// Les valeurs que cette etape designe a partir d une valeur.
    ///
    /// Une etape qui ne s applique pas rend une liste vide plutot que de lever.
    /// Un document de serveur ou une cle manque n est pas une erreur de regle :
    /// c est un champ absent, que l appelant traite comme tel.
    func appliquer(a valeur: ValeurJson) -> [ValeurJson] {
        switch self {
        case let .cle(nom):
            valeur.entrees?[nom].map { [$0] } ?? []
        case let .rang(index):
            Self.element(index, de: valeur)
        case .tousLesElements:
            Self.tousLesElements(de: valeur)
        }
    }

    /// L element de ce rang, quand la valeur est une liste assez longue.
    private static func element(_ index: Int, de valeur: ValeurJson) -> [ValeurJson] {
        guard case let .liste(valeurs) = valeur, index < valeurs.count else {
            return []
        }

        return [valeurs[index]]
    }

    /// Tous les elements d une liste.
    ///
    /// Une valeur qui n est pas une liste ne rend rien, plutot que de se rendre
    /// elle meme : `[*]` demande explicitement plusieurs elements, et repondre
    /// par un seul deguiserait un document de forme inattendue en document
    /// conforme.
    private static func tousLesElements(de valeur: ValeurJson) -> [ValeurJson] {
        guard case let .liste(valeurs) = valeur else {
            return []
        }

        return valeurs
    }
}

// MARK: - Codage

extension CheminJson: Codable {
    public init(from decodeur: any Decoder) throws {
        let conteneur = try decodeur.singleValueContainer()

        try self.init(conteneur.decode(String.self))
    }

    public func encode(to encodeur: any Encoder) throws {
        var conteneur = encodeur.singleValueContainer()

        try conteneur.encode(texte)
    }
}
