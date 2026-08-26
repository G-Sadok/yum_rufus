import Foundation

//
// ValeurJson
//
// Un document JSON lu sans schema, pour les deux usages du systeme
// d extensions.
//
// Le premier est la relecture du manifeste avant son decodage. Un decodeur
// Swift ignore en silence les cles qu il ne connait pas, ce qui est exactement
// le contraire de ce que la section 4.3 demande : une entree que l interprete
// ne sait pas appliquer doit faire refuser le paquet, pas disparaitre du
// resultat sans que personne ne le voie. Relire l arbre brut permet de comparer
// les cles presentes a celles que le langage declaratif connait.
//
// Le second est l application des regles a une reponse de serveur, ou le
// document recu n a par definition aucun schema connu a l avance.
//
// Le type est ferme et sans effet de bord. Il ne sait rien faire d autre que
// porter des valeurs, ce qui est la premiere ligne de defense du critere
// aucun code fourni par une extension n est execute.
//

/// Une valeur d un document JSON, quelle que soit sa forme.
public indirect enum ValeurJson: Sendable, Hashable {
    case nul
    case booleen(Bool)
    case nombre(Double)
    case texte(String)
    case liste([ValeurJson])
    case objet([String: ValeurJson])

    /// Lit un document JSON complet.
    ///
    /// - Throws: `ErreurDExtension.manifesteIllisible` quand les octets ne
    ///   decrivent pas un document JSON.
    public init(donnees: Data) throws {
        guard donnees.isEmpty == false else {
            throw ErreurDExtension.manifesteIllisible
        }
        guard let lue = try? JSONDecoder().decode(ValeurJson.self, from: donnees) else {
            throw ErreurDExtension.manifesteIllisible
        }

        self = lue
    }
}

// MARK: - Lecture

extension ValeurJson {
    /// La chaine portee, ou nul quand la valeur n en est pas une.
    ///
    /// Un nombre et un booleen se lisent aussi comme du texte : un serveur
    /// publie regulierement un identifiant sous forme de nombre, et une regle
    /// qui le cherche comme identifiant de serie ne rendrait rien du tout.
    public var texteLisible: String? {
        switch self {
        case let .texte(valeur): valeur
        case let .nombre(valeur): Self.texte(deNombre: valeur)
        case let .booleen(valeur): String(valeur)
        case .nul, .liste, .objet: nil
        }
    }

    /// Le nombre porte, ou nul quand la valeur n en est pas un.
    ///
    /// Une chaine numerique est acceptee pour la meme raison que ci dessus :
    /// le nombre de chapitres arrive tantot en nombre, tantot en chaine, selon
    /// le serveur.
    public var nombreLisible: Double? {
        switch self {
        case let .nombre(valeur): valeur
        case let .texte(valeur): Double(valeur)
        case .nul, .booleen, .liste, .objet: nil
        }
    }

    /// Les elements portes, une liste a un element pour une valeur seule.
    ///
    /// Sert aux champs que les serveurs publient tantot en liste, tantot en
    /// valeur unique, les auteurs et les genres en tete.
    public var elements: [ValeurJson] {
        switch self {
        case let .liste(valeurs): valeurs
        case .nul: []
        default: [self]
        }
    }

    /// Les entrees de l objet porte, ou nul quand la valeur n en est pas un.
    public var entrees: [String: ValeurJson]? {
        guard case let .objet(table) = self else {
            return nil
        }

        return table
    }

    /// Vrai quand la valeur est nulle ou vide.
    public var estVide: Bool {
        switch self {
        case .nul: true
        case let .texte(valeur): valeur.isEmpty
        case let .liste(valeurs): valeurs.isEmpty
        case let .objet(table): table.isEmpty
        case .booleen, .nombre: false
        }
    }

    /// Toutes les cles d objet presentes dans l arbre, a tous les niveaux.
    ///
    /// C est la lecture dont depend le refus d une cle inconnue. Elle est a
    /// plat et non par chemin : le langage declaratif ne reutilise pas un meme
    /// nom de cle pour deux sens differents, et une comparaison a plat se lit
    /// et se teste sans decrire le schema une seconde fois.
    public var clesPresentes: Set<String> {
        switch self {
        case let .objet(table):
            table.reduce(into: Set(table.keys)) { cles, entree in
                cles.formUnion(entree.value.clesPresentes)
            }
        case let .liste(valeurs):
            valeurs.reduce(into: Set()) { cles, valeur in
                cles.formUnion(valeur.clesPresentes)
            }
        default:
            []
        }
    }

    /// Ecrit un nombre sans decimale superflue.
    ///
    /// JSON ne distingue pas l entier du flottant, et un identifiant lu comme
    /// nombre puis rendu en texte deviendrait `1234.0` sans cette reduction,
    /// ce qui ne designerait plus rien chez le serveur.
    private static func texte(deNombre valeur: Double) -> String {
        guard valeur.rounded() == valeur, valeur.magnitude < 1e15 else {
            return String(valeur)
        }

        return String(Int64(valeur))
    }
}

// MARK: - Decodage

extension ValeurJson: Decodable {
    public init(from decodeur: any Decoder) throws {
        let conteneur = try decodeur.singleValueContainer()

        if conteneur.decodeNil() {
            self = .nul
        } else if let valeur = try? conteneur.decode(Bool.self) {
            // Le booleen se tente avant le nombre : un decodeur JSON accepte
            // `true` comme booleen seulement, mais l ordre inverse ferait lire
            // 0 et 1 comme des booleens chez un decodeur plus permissif.
            self = .booleen(valeur)
        } else if let valeur = try? conteneur.decode(Double.self) {
            self = .nombre(valeur)
        } else if let valeur = try? conteneur.decode(String.self) {
            self = .texte(valeur)
        } else if let valeurs = try? conteneur.decode([ValeurJson].self) {
            self = .liste(valeurs)
        } else {
            self = try .objet(conteneur.decode([String: ValeurJson].self))
        }
    }
}
