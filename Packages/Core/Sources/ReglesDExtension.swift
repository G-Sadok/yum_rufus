import Foundation

//
// ReglesDExtension
//
// Le jeu de regles d extraction declaratives de la section 4.3 : selecteurs CSS
// ou chemins JSON, correspondances de champs, regles de pagination.
//
// Tout ce fichier est constitue de donnees. Il n y a pas une seule fermeture,
// pas un seul nom de fonction, pas une seule chaine qui serait ensuite
// interpretee autrement que par les types declares ici. C est la forme meme du
// langage qui tient le premier critere : ce qu une extension peut ecrire, ce
// sont des valeurs de ces enumerations fermees, et rien d autre ne se decode.
//
// Les regles sont separees par question posee, recherche, parcours, details,
// chapitres et pages, plutot que reunies dans une table indexee par un nom.
// Une table aurait accepte n importe quelle cle, donc n importe quelle question
// inventee par l auteur du manifeste, et il aurait fallu la refuser a
// l execution au lieu de la refuser au decodage.
//

/// Regle qui rend une liste de series.
public struct RegleDeSeries: Sendable, Hashable, Codable {
    public let requete: RegleDeRequete

    /// Ou trouver les elements de la liste dans le document.
    public let elements: Extraction

    public let champs: CorrespondanceDeSerie
    public let pagination: ReglePagination?

    public init(
        requete: RegleDeRequete,
        elements: Extraction,
        champs: CorrespondanceDeSerie,
        pagination: ReglePagination? = nil
    ) {
        self.requete = requete
        self.elements = elements
        self.champs = champs
        self.pagination = pagination
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case requete
        case elements
        case champs
        case pagination
    }

    /// Toutes les extractions de la regle, y compris celles de la pagination.
    var toutesLesExtractions: [Extraction] {
        [elements] + champs.toutes + (pagination?.toutes ?? [])
    }
}

/// Regle qui rend le detail d une seule serie.
public struct RegleDeDetail: Sendable, Hashable, Codable {
    public let requete: RegleDeRequete

    /// Element qui porte le detail. Absent, le document entier en tient lieu.
    public let element: Extraction?

    public let champs: CorrespondanceDeSerie

    public init(requete: RegleDeRequete, element: Extraction? = nil, champs: CorrespondanceDeSerie) {
        self.requete = requete
        self.element = element
        self.champs = champs
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case requete
        case element
        case champs
    }

    var toutesLesExtractions: [Extraction] {
        (element.map { [$0] } ?? []) + champs.toutes
    }
}

/// Regle qui rend la liste des chapitres d une serie.
public struct RegleDeChapitres: Sendable, Hashable, Codable {
    public let requete: RegleDeRequete
    public let elements: Extraction
    public let champs: CorrespondanceDeChapitre

    /// Vrai quand la source publie les chapitres du plus recent au plus ancien.
    ///
    /// Le protocole rend les chapitres dans l ordre de lecture. Une source qui
    /// publie l inverse est retournee ici, une fois, plutot que par chaque
    /// couche qui affiche une liste.
    public let ordreInverse: Bool

    public init(
        requete: RegleDeRequete,
        elements: Extraction,
        champs: CorrespondanceDeChapitre,
        ordreInverse: Bool = false
    ) {
        self.requete = requete
        self.elements = elements
        self.champs = champs
        self.ordreInverse = ordreInverse
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case requete
        case elements
        case champs
        case ordreInverse
    }

    public init(from decodeur: any Decoder) throws {
        let conteneur = try decodeur.container(keyedBy: CodingKeys.self)

        requete = try conteneur.decode(RegleDeRequete.self, forKey: .requete)
        elements = try conteneur.decode(Extraction.self, forKey: .elements)
        champs = try conteneur.decode(CorrespondanceDeChapitre.self, forKey: .champs)
        ordreInverse = try conteneur.decodeIfPresent(Bool.self, forKey: .ordreInverse) ?? false
    }

    var toutesLesExtractions: [Extraction] {
        [elements] + champs.toutes
    }
}

/// Regle qui rend la liste des pages d un chapitre.
public struct RegleDePages: Sendable, Hashable, Codable {
    public let requete: RegleDeRequete
    public let elements: Extraction
    public let champs: CorrespondanceDePage

    public init(requete: RegleDeRequete, elements: Extraction, champs: CorrespondanceDePage) {
        self.requete = requete
        self.elements = elements
        self.champs = champs
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case requete
        case elements
        case champs
    }

    var toutesLesExtractions: [Extraction] {
        [elements] + champs.toutes
    }
}

/// Regle de parcours d une section du catalogue.
///
/// Une liste et non une table indexee par la section : une table aurait accepte
/// une cle inventee, qu il aurait fallu refuser a l execution au lieu du
/// decodage.
public struct RegleDeSection: Sendable, Hashable, Codable {
    public let section: SectionCatalogue
    public let regle: RegleDeSeries

    public init(section: SectionCatalogue, regle: RegleDeSeries) {
        self.section = section
        self.regle = regle
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case section
        case regle
    }
}

// MARK: - Le jeu complet

/// Tout ce qu une extension declare pour repondre aux questions du protocole.
public struct ReglesDExtension: Sendable, Hashable, Codable {
    /// Adresse a laquelle tous les chemins s ajoutent.
    public let adresseDeBase: URL

    /// Numero de la premiere page chez ce serveur.
    ///
    /// Le protocole numerote les pages a partir de zero. Beaucoup de serveurs
    /// commencent a un, et corriger le decalage dans chaque gabarit obligerait
    /// a savoir compter dans un gabarit, c est a dire a calculer.
    public let pageDeDepart: Int

    /// Format des dates publiees, au vocabulaire de `DateFormatter`.
    ///
    /// Nul veut dire ISO 8601, la forme que rendent la plupart des API.
    public let formatDeDate: String?

    public let recherche: RegleDeSeries?
    public let sections: [RegleDeSection]
    public let details: RegleDeDetail?
    public let chapitres: RegleDeChapitres
    public let pages: RegleDePages

    public init(
        adresseDeBase: URL,
        pageDeDepart: Int = 0,
        formatDeDate: String? = nil,
        recherche: RegleDeSeries? = nil,
        sections: [RegleDeSection] = [],
        details: RegleDeDetail? = nil,
        chapitres: RegleDeChapitres,
        pages: RegleDePages
    ) {
        self.adresseDeBase = adresseDeBase
        self.pageDeDepart = pageDeDepart
        self.formatDeDate = formatDeDate
        self.recherche = recherche
        self.sections = sections
        self.details = details
        self.chapitres = chapitres
        self.pages = pages
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case adresseDeBase
        case pageDeDepart
        case formatDeDate
        case recherche
        case sections
        case details
        case chapitres
        case pages
    }

    public init(from decodeur: any Decoder) throws {
        let conteneur = try decodeur.container(keyedBy: CodingKeys.self)

        adresseDeBase = try conteneur.decode(URL.self, forKey: .adresseDeBase)
        pageDeDepart = try conteneur.decodeIfPresent(Int.self, forKey: .pageDeDepart) ?? 0
        formatDeDate = try conteneur.decodeIfPresent(String.self, forKey: .formatDeDate)
        recherche = try conteneur.decodeIfPresent(RegleDeSeries.self, forKey: .recherche)
        sections = try conteneur.decodeIfPresent([RegleDeSection].self, forKey: .sections) ?? []
        details = try conteneur.decodeIfPresent(RegleDeDetail.self, forKey: .details)
        chapitres = try conteneur.decode(RegleDeChapitres.self, forKey: .chapitres)
        pages = try conteneur.decode(RegleDePages.self, forKey: .pages)
    }

    /// La regle de parcours de cette section, quand l extension en declare une.
    public func regle(pour section: SectionCatalogue) -> RegleDeSeries? {
        sections.first { $0.section == section }?.regle
    }

    /// Les capacites que ces regles permettent reellement de servir.
    ///
    /// C est ce qui evite qu un manifeste annonce une capacite sans la regle
    /// qui va avec : l interface offrirait alors une action qui echouerait a
    /// chaque fois. Le manifeste retient l intersection de ce qu il annonce et
    /// de ce que ce calcul rend.
    public var capacitesServies: SourceCapacites {
        var servies = SourceCapacites()

        if recherche != nil {
            servies.insert(.recherche)
        }
        if recherche?.pagination != nil || sections.contains(where: { $0.regle.pagination != nil }) {
            servies.insert(.pagination)
        }
        if variablesCitees.contains(.langue) {
            servies.insert(.plusieursLangues)
        }

        // Une extension sert toujours ses pages par une adresse, donc toujours
        // le telechargement. Aucune ne tient de progression cote serveur : cela
        // demanderait de publier, et une extension ne publie jamais.
        servies.insert(.telechargement)

        return servies
    }

    /// Toutes les variables citees par les gabarits de toutes les regles.
    var variablesCitees: Set<VariableDeGabarit> {
        toutesLesRequetes.reduce(into: Set()) { citees, requete in
            citees.formUnion(requete.variablesCitees)
        }
    }

    /// Toutes les requetes declarees.
    var toutesLesRequetes: [RegleDeRequete] {
        (recherche.map { [$0.requete] } ?? [])
            + sections.map(\.regle.requete)
            + (details.map { [$0.requete] } ?? [])
            + [chapitres.requete, pages.requete]
    }

    /// Les couples format et extractions, pour verifier qu ils s accordent.
    var accords: [(format: FormatDeReponse, extractions: [Extraction])] {
        (recherche.map { [(format: $0.requete.format, extractions: $0.toutesLesExtractions)] } ?? [])
            + sections.map { (format: $0.regle.requete.format, extractions: $0.regle.toutesLesExtractions) }
            + (details.map { [(format: $0.requete.format, extractions: $0.toutesLesExtractions)] } ?? [])
            + [
                (format: chapitres.requete.format, extractions: chapitres.toutesLesExtractions),
                (format: pages.requete.format, extractions: pages.toutesLesExtractions),
            ]
    }
}
