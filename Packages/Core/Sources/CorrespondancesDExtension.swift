import Foundation

//
// CorrespondancesDExtension
//
// Ou lire chaque champ d une entite du protocole dans un element de la reponse,
// et comment savoir qu il reste des pages a demander.
//
// Les champs sont nommes un par un, dans trois structures fermees, et non
// ranges dans une table indexee par un nom de champ. Une table aurait accepte
// n importe quelle cle, donc n importe quel champ invente par l auteur du
// manifeste, qu il aurait fallu ignorer a l execution. Ici, un champ inconnu
// fait refuser le paquet des sa lecture.
//
// Les champs obligatoires ne sont pas optionnels. L identifiant d une serie,
// son titre et l emplacement d une page se decodent ou le manifeste est refuse,
// sans verification supplementaire a ecrire ni a oublier.
//

/// Ou lire chaque champ d une serie dans un element de la reponse.
public struct CorrespondanceDeSerie: Sendable, Hashable, Codable {
    public let identifiant: Extraction
    public let titre: Extraction
    public let auteurs: Extraction?
    public let resume: Extraction?
    public let genres: Extraction?
    public let statut: Extraction?
    public let langue: Extraction?
    public let couverture: Extraction?
    public let nombreChapitres: Extraction?

    public init(
        identifiant: Extraction,
        titre: Extraction,
        auteurs: Extraction? = nil,
        resume: Extraction? = nil,
        genres: Extraction? = nil,
        statut: Extraction? = nil,
        langue: Extraction? = nil,
        couverture: Extraction? = nil,
        nombreChapitres: Extraction? = nil
    ) {
        self.identifiant = identifiant
        self.titre = titre
        self.auteurs = auteurs
        self.resume = resume
        self.genres = genres
        self.statut = statut
        self.langue = langue
        self.couverture = couverture
        self.nombreChapitres = nombreChapitres
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case identifiant
        case titre
        case auteurs
        case resume
        case genres
        case statut
        case langue
        case couverture
        case nombreChapitres
    }

    /// Toutes les extractions declarees, obligatoires et facultatives.
    public var toutes: [Extraction] {
        [identifiant, titre] + [auteurs, resume, genres, statut, langue, couverture, nombreChapitres]
            .compactMap(\.self)
    }
}

/// Ou lire chaque champ d un chapitre dans un element de la reponse.
public struct CorrespondanceDeChapitre: Sendable, Hashable, Codable {
    public let identifiant: Extraction

    /// Numero de chapitre. Absent, le rang dans la liste en tient lieu.
    public let numero: Extraction?

    public let titre: Extraction?
    public let langue: Extraction?
    public let datePublication: Extraction?
    public let nombrePages: Extraction?

    public init(
        identifiant: Extraction,
        numero: Extraction? = nil,
        titre: Extraction? = nil,
        langue: Extraction? = nil,
        datePublication: Extraction? = nil,
        nombrePages: Extraction? = nil
    ) {
        self.identifiant = identifiant
        self.numero = numero
        self.titre = titre
        self.langue = langue
        self.datePublication = datePublication
        self.nombrePages = nombrePages
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case identifiant
        case numero
        case titre
        case langue
        case datePublication
        case nombrePages
    }

    public var toutes: [Extraction] {
        [identifiant] + [numero, titre, langue, datePublication, nombrePages].compactMap(\.self)
    }
}

/// Ou lire l emplacement d une page dans un element de la reponse.
public struct CorrespondanceDePage: Sendable, Hashable, Codable {
    public let emplacement: Extraction

    public init(emplacement: Extraction) {
        self.emplacement = emplacement
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case emplacement
    }

    public var toutes: [Extraction] {
        [emplacement]
    }
}

// MARK: - Pagination

/// Comment savoir qu il reste des pages a demander.
public enum ReglePagination: Sendable, Hashable {
    /// Il en reste tant que la liste rendue est pleine.
    case listePleine(tailleDePage: Int)

    /// Il en reste quand cette extraction rend une valeur non vide.
    case lienSuivant(Extraction)

    /// Le document annonce un total, dont se deduit le nombre de pages.
    case totalAnnonce(Extraction, tailleDePage: Int)

    /// Toutes les extractions de cette regle.
    public var toutes: [Extraction] {
        switch self {
        case .listePleine: []
        case let .lienSuivant(extraction): [extraction]
        case let .totalAnnonce(extraction, _): [extraction]
        }
    }
}

extension ReglePagination: Codable {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case listePleine
        case lienSuivant
        case totalAnnonce
        case tailleDePage
    }

    public init(from decodeur: any Decoder) throws {
        let conteneur = try decodeur.container(keyedBy: CodingKeys.self)

        if let taille = try conteneur.decodeIfPresent(Int.self, forKey: .listePleine) {
            self = .listePleine(tailleDePage: taille)
        } else if let extraction = try conteneur.decodeIfPresent(Extraction.self, forKey: .lienSuivant) {
            self = .lienSuivant(extraction)
        } else {
            let extraction = try conteneur.decode(Extraction.self, forKey: .totalAnnonce)
            let taille = try conteneur.decode(Int.self, forKey: .tailleDePage)

            self = .totalAnnonce(extraction, tailleDePage: taille)
        }
    }

    public func encode(to encodeur: any Encoder) throws {
        var conteneur = encodeur.container(keyedBy: CodingKeys.self)

        switch self {
        case let .listePleine(taille):
            try conteneur.encode(taille, forKey: .listePleine)
        case let .lienSuivant(extraction):
            try conteneur.encode(extraction, forKey: .lienSuivant)
        case let .totalAnnonce(extraction, taille):
            try conteneur.encode(extraction, forKey: .totalAnnonce)
            try conteneur.encode(taille, forKey: .tailleDePage)
        }
    }
}
