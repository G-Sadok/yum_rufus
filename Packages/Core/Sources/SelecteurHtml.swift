import Foundation

//
// SelecteurHtml
//
// Le selecteur CSS de la section 4.3, reduit a ce qui designe un element sans
// jamais calculer quoi que ce soit.
//
// La reduction suit la meme regle que `CheminJson`. CSS accepte des pseudo
// classes fonctionnelles, `:nth-child(2n+1)` et `:has(...)` en tete, qui sont
// des expressions a evaluer. Une extension qui en fournirait ferait tourner du
// calcul qu elle a ecrit, ce que le premier critere interdit. Le langage retenu
// ne sait donc designer que par balise, identifiant, classe et attribut, avec
// les deux combinateurs de descendance.
//
//     div.serie a.titre
//     ul#chapitres > li[data-id]
//     img[src$=.jpg]
//
// Ce sous ensemble couvre les catalogues reels. Ce qu il ne couvre pas se
// declare autrement dans le manifeste, ou ne se declare pas du tout.
//

/// Comment un attribut est compare a une valeur.
public enum ComparaisonDAttribut: String, Sendable, Codable, CaseIterable, Hashable {
    /// L attribut existe, quelle que soit sa valeur.
    case presence

    /// La valeur est exactement celle attendue.
    case egale

    /// La valeur contient celle attendue.
    case contient

    /// La valeur commence par celle attendue.
    case commencePar

    /// La valeur finit par celle attendue.
    case finitPar

    /// L operateur tel qu il s ecrit entre crochets.
    var operateur: String {
        switch self {
        case .presence: ""
        case .egale: "="
        case .contient: "*="
        case .commencePar: "^="
        case .finitPar: "$="
        }
    }
}

/// Une condition portee par un attribut.
public struct ConditionDAttribut: Sendable, Hashable {
    public let nom: String
    public let comparaison: ComparaisonDAttribut

    /// Valeur attendue, nulle pour une simple presence.
    public let valeur: String?

    public init(nom: String, comparaison: ComparaisonDAttribut = .presence, valeur: String? = nil) {
        self.nom = nom
        self.comparaison = comparaison
        self.valeur = valeur
    }

    /// Vrai quand la valeur observee satisfait la condition.
    public func estSatisfaite(par observee: String?) -> Bool {
        guard let observee else {
            return false
        }
        guard let valeur else {
            return comparaison == .presence
        }

        switch comparaison {
        case .presence: return true
        case .egale: return observee == valeur
        case .contient: return observee.contains(valeur)
        case .commencePar: return observee.hasPrefix(valeur)
        case .finitPar: return observee.hasSuffix(valeur)
        }
    }

    /// Forme textuelle, crochets compris.
    var texte: String {
        guard let valeur else {
            return "[\(nom)]"
        }

        return "[\(nom)\(comparaison.operateur)\(valeur)]"
    }
}

/// Lien entre une etape de selecteur et la precedente.
public enum CombinateurDeSelecteur: String, Sendable, Codable, CaseIterable, Hashable {
    /// N importe ou sous l element precedent.
    case descendant

    /// Directement sous l element precedent.
    case enfant
}

/// Une etape d un selecteur, c est a dire ce qu un element doit porter.
public struct EtapeDeSelecteur: Sendable, Hashable {
    public let combinateur: CombinateurDeSelecteur

    /// Nom de balise attendu, nul pour n importe laquelle.
    public let balise: String?

    /// Identifiant attendu, nul quand l etape n en impose pas.
    public let identifiant: String?

    /// Classes que l element doit toutes porter.
    public let classes: [String]

    /// Conditions d attribut que l element doit toutes satisfaire.
    public let attributs: [ConditionDAttribut]

    public init(
        combinateur: CombinateurDeSelecteur = .descendant,
        balise: String? = nil,
        identifiant: String? = nil,
        classes: [String] = [],
        attributs: [ConditionDAttribut] = []
    ) {
        self.combinateur = combinateur
        self.balise = balise
        self.identifiant = identifiant
        self.classes = classes
        self.attributs = attributs
    }

    /// Forme textuelle de l etape, sans son combinateur.
    var texte: String {
        let debut = balise ?? (identifiant == nil && classes.isEmpty && attributs.isEmpty ? "*" : "")
        let marqueur = identifiant.map { "#\($0)" } ?? ""

        return debut + marqueur + classes.map { ".\($0)" }.joined() + attributs.map(\.texte).joined()
    }
}

/// Un selecteur, c est a dire une suite d etapes a satisfaire de proche en
/// proche.
public struct SelecteurHtml: Sendable, Hashable {
    public let etapes: [EtapeDeSelecteur]

    public init(etapes: [EtapeDeSelecteur]) {
        self.etapes = etapes
    }

    /// Analyse la forme textuelle d un selecteur.
    ///
    /// - Throws: `ErreurDExtension.extractionMalFormee` quand le texte n est
    ///   pas un selecteur de ce sous ensemble.
    public init(_ texte: String) throws {
        etapes = try Self.analyser(texte)
    }

    /// Vrai quand le selecteur ne designe rien, ce qui est refuse a l analyse.
    public var estVide: Bool {
        etapes.isEmpty
    }

    /// Forme textuelle canonique, celle qui se relit par `init(_:)`.
    public var texte: String {
        etapes.enumerated().reduce(into: "") { assemblee, paire in
            if paire.offset > 0 {
                assemblee += paire.element.combinateur == .enfant ? " > " : " "
            }

            assemblee += paire.element.texte
        }
    }

    // MARK: Analyse

    /// Decoupe la forme textuelle en etapes.
    private static func analyser(_ texte: String) throws -> [EtapeDeSelecteur] {
        var etapes: [EtapeDeSelecteur] = []
        var combinateur = CombinateurDeSelecteur.descendant

        for morceau in decouper(texte) {
            if morceau == ">" {
                guard etapes.isEmpty == false else {
                    throw ErreurDExtension.extractionMalFormee(texte: texte)
                }

                combinateur = .enfant
                continue
            }

            try etapes.append(etape(morceau, combinateur: combinateur, dans: texte))
            combinateur = .descendant
        }

        guard etapes.isEmpty == false else {
            throw ErreurDExtension.extractionMalFormee(texte: texte)
        }

        return etapes
    }

    /// Separe le texte en morceaux, en isolant le combinateur enfant.
    ///
    /// Le chevron est isole meme colle a ses voisins, parce que `a>b` et
    /// `a > b` designent la meme chose en CSS et qu un auteur de regles ecrit
    /// l un ou l autre sans y penser.
    private static func decouper(_ texte: String) -> [String] {
        texte
            .replacingOccurrences(of: ">", with: " > ")
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
    }

    /// Lit une etape complete, balise, identifiant, classes et attributs.
    private static func etape(
        _ morceau: String,
        combinateur: CombinateurDeSelecteur,
        dans texte: String
    ) throws -> EtapeDeSelecteur {
        var restant = Substring(morceau)
        let balise = lireLeNom(&restant)
        var identifiant: String?
        var classes: [String] = []
        var attributs: [ConditionDAttribut] = []

        while let marqueur = restant.first {
            switch marqueur {
            case "#":
                restant = restant.dropFirst()
                identifiant = try nomObligatoire(&restant, dans: texte)
            case ".":
                restant = restant.dropFirst()
                try classes.append(nomObligatoire(&restant, dans: texte))
            case "[":
                try attributs.append(condition(&restant, dans: texte))
            default:
                throw ErreurDExtension.extractionMalFormee(texte: texte)
            }
        }

        guard balise != nil || identifiant != nil || classes.isEmpty == false || attributs.isEmpty == false else {
            throw ErreurDExtension.extractionMalFormee(texte: texte)
        }

        return EtapeDeSelecteur(
            combinateur: combinateur,
            balise: balise,
            identifiant: identifiant,
            classes: classes,
            attributs: attributs
        )
    }

    /// Lit un nom de balise, de classe ou d identifiant, ou rend nul.
    ///
    /// L etoile est lue comme une absence de contrainte de balise, ce qu elle
    /// veut dire en CSS.
    private static func lireLeNom(_ restant: inout Substring) -> String? {
        if restant.first == "*" {
            restant = restant.dropFirst()

            return nil
        }

        let nom = restant.prefix { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }

        guard nom.isEmpty == false else {
            return nil
        }

        restant = restant.dropFirst(nom.count)

        return String(nom).lowercased()
    }

    /// Lit un nom la ou il en faut un.
    private static func nomObligatoire(_ restant: inout Substring, dans texte: String) throws -> String {
        guard let nom = lireLeNom(&restant) else {
            throw ErreurDExtension.extractionMalFormee(texte: texte)
        }

        return nom
    }

    /// Lit une condition d attribut entre crochets.
    private static func condition(_ restant: inout Substring, dans texte: String) throws -> ConditionDAttribut {
        restant = restant.dropFirst()

        guard let fin = restant.firstIndex(of: "]") else {
            throw ErreurDExtension.extractionMalFormee(texte: texte)
        }

        let contenu = String(restant[restant.startIndex..<fin])
        restant = restant[restant.index(after: fin)...]

        return try conditionDepuis(contenu, dans: texte)
    }

    /// Analyse le contenu d une paire de crochets.
    private static func conditionDepuis(_ contenu: String, dans texte: String) throws -> ConditionDAttribut {
        // Les operateurs a deux caracteres sont essayes avant le simple egal,
        // sans quoi `*=` serait lu comme un nom d attribut `foo*` suivi de `=`.
        for comparaison in [ComparaisonDAttribut.contient, .commencePar, .finitPar, .egale] {
            guard let separation = contenu.range(of: comparaison.operateur) else {
                continue
            }

            let nom = String(contenu[contenu.startIndex..<separation.lowerBound])
            let valeur = String(contenu[separation.upperBound...])

            guard nom.isEmpty == false else {
                throw ErreurDExtension.extractionMalFormee(texte: texte)
            }

            return ConditionDAttribut(
                nom: nom.lowercased(),
                comparaison: comparaison,
                valeur: sansGuillemets(valeur)
            )
        }

        guard contenu.isEmpty == false else {
            throw ErreurDExtension.extractionMalFormee(texte: texte)
        }

        return ConditionDAttribut(nom: contenu.lowercased())
    }

    /// Retire les guillemets d une valeur d attribut quand elle en porte.
    private static func sansGuillemets(_ valeur: String) -> String {
        guard valeur.count >= 2, let premier = valeur.first, let dernier = valeur.last,
              premier == dernier, premier == "\"" || premier == "'"
        else {
            return valeur
        }

        return String(valeur.dropFirst().dropLast())
    }
}

// MARK: - Ce qui est extrait d un element

/// Ce qu une regle lit sur l element qu elle a designe.
public enum ValeurDElement: Sendable, Hashable, Codable {
    /// Le texte de l element et de ses descendants, espaces normalises.
    case texte

    /// La valeur d un de ses attributs.
    case attribut(String)

    /// Nom du champ pour le journal et les messages, sans valeur d attribut.
    var libelle: String {
        switch self {
        case .texte: "texte"
        case let .attribut(nom): nom
        }
    }
}

// MARK: - Codage

extension SelecteurHtml: Codable {
    public init(from decodeur: any Decoder) throws {
        let conteneur = try decodeur.singleValueContainer()

        try self.init(conteneur.decode(String.self))
    }

    public func encode(to encodeur: any Encoder) throws {
        var conteneur = encodeur.singleValueContainer()

        try conteneur.encode(texte)
    }
}
