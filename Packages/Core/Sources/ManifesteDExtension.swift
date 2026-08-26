import Foundation

//
// ManifesteDExtension
//
// Le manifeste JSON de la section 4.3 : identifiant, nom, version, langue,
// capacites, domaines autorises, et le jeu de regles declaratives.
//
// La lecture est volontairement hostile. Un decodeur Swift ignore les cles
// qu il ne connait pas, ce qui reviendrait a accepter un paquet dont une partie
// du contenu n a jamais ete relue. `lire(_:)` compare donc d abord les cles
// presentes a celles que le langage declaratif connait, et refuse le paquet
// entier des la premiere inconnue. C est la garantie visible du critere aucun
// code fourni par une extension n est execute : ce que nous n interpretons pas,
// nous ne l acceptons pas non plus.
//
// La verification est a plat, sur l ensemble des noms de cles de l arbre, et
// non chemin par chemin. Elle n interdit donc pas de placer une cle connue au
// mauvais endroit, ce que le decodage attrape ensuite. Elle interdit d en
// introduire une nouvelle, ce qui est le seul moyen d y glisser une
// instruction.
//

/// Version d une extension, telle qu elle s affiche dans le sous titre de la
/// ligne de source, tableau 4.4 de DESIGN-SPEC.md.
public struct VersionDExtension: Sendable, Hashable, Comparable, Codable {
    public let majeure: Int
    public let mineure: Int
    public let correctif: Int

    public init(majeure: Int, mineure: Int = 0, correctif: Int = 0) {
        self.majeure = majeure
        self.mineure = mineure
        self.correctif = correctif
    }

    /// Analyse la forme `1.4` ou `1.4.2`.
    ///
    /// - Throws: `ErreurDExtension.champManquant` quand le texte n est pas une
    ///   version.
    public init(_ texte: String) throws {
        let morceaux = texte.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        let nombres = morceaux.compactMap(Int.init)

        guard morceaux.count == nombres.count, (1...3).contains(nombres.count), nombres.allSatisfy({ $0 >= 0 })
        else {
            throw ErreurDExtension.champManquant(nom: "version")
        }

        majeure = nombres[0]
        mineure = nombres.count > 1 ? nombres[1] : 0
        correctif = nombres.count > 2 ? nombres[2] : 0
    }

    /// Forme textuelle, `v1.4` ou `v1.4.2`, sans le prefixe.
    public var texte: String {
        correctif == 0 ? "\(majeure).\(mineure)" : "\(majeure).\(mineure).\(correctif)"
    }

    public static func < (gauche: VersionDExtension, droite: VersionDExtension) -> Bool {
        (gauche.majeure, gauche.mineure, gauche.correctif) < (droite.majeure, droite.mineure, droite.correctif)
    }

    public init(from decodeur: any Decoder) throws {
        let conteneur = try decodeur.singleValueContainer()

        try self.init(conteneur.decode(String.self))
    }

    public func encode(to encodeur: any Encoder) throws {
        var conteneur = encodeur.singleValueContainer()

        try conteneur.encode(texte)
    }
}

/// Nom d une capacite dans un manifeste.
///
/// L enumeration double `SourceCapacites` parce qu un jeu d options ne se
/// decode pas depuis une liste de noms, et parce qu un manifeste ne doit
/// surtout pas ecrire un entier de bits : un bit inconnu passerait sans etre
/// remarque.
public enum NomDeCapacite: String, Sendable, Codable, CaseIterable, Hashable {
    case recherche
    case filtres
    case pagination
    case telechargement
    case progressionDistante
    case plusieursLangues

    /// La capacite du protocole que ce nom designe.
    public var capacite: SourceCapacites {
        switch self {
        case .recherche: .recherche
        case .filtres: .filtres
        case .pagination: .pagination
        case .telechargement: .telechargement
        case .progressionDistante: .progressionDistante
        case .plusieursLangues: .plusieursLangues
        }
    }
}

/// Le manifeste d une extension declarative.
public struct ManifesteDExtension: Sendable, Hashable, Codable {
    /// Version du format de manifeste que cet interprete applique.
    ///
    /// Un manifeste ecrit pour une version plus recente est refuse au lieu
    /// d etre lu partiellement : c est le seul refus qui protege contre une
    /// regle dont le sens aurait change entre deux versions.
    public static let versionDeFormatAppliquee = 1

    /// Version du format que le manifeste declare suivre.
    public let format: Int

    /// Identifiant stable de l extension, en minuscules et sans espace.
    public let identifiant: String

    /// Nom affiche a l utilisateur.
    public let nom: String

    public let version: VersionDExtension

    /// Langue du catalogue, au format BCP 47.
    public let langue: String

    /// Capacites annoncees, avant intersection avec ce que les regles servent.
    public let capacitesAnnoncees: [NomDeCapacite]

    /// Domaines que l extension a le droit de joindre.
    public let domaines: [DomaineAutorise]

    /// Nom du fichier d icone dans le paquet, quand il y en a un.
    ///
    /// Ce n est qu un nom de fichier : un chemin permettrait de designer un
    /// fichier hors du paquet, et la section 4.3 interdit tout acces au systeme
    /// de fichiers.
    public let icone: String?

    public let regles: ReglesDExtension

    public init(
        format: Int = ManifesteDExtension.versionDeFormatAppliquee,
        identifiant: String,
        nom: String,
        version: VersionDExtension,
        langue: String,
        capacitesAnnoncees: [NomDeCapacite],
        domaines: [DomaineAutorise],
        icone: String? = nil,
        regles: ReglesDExtension
    ) {
        self.format = format
        self.identifiant = identifiant
        self.nom = nom
        self.version = version
        self.langue = langue
        self.capacitesAnnoncees = capacitesAnnoncees
        self.domaines = domaines
        self.icone = icone
        self.regles = regles
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case format
        case identifiant
        case nom
        case version
        case langue
        case capacitesAnnoncees = "capacites"
        case domaines
        case icone
        case regles
    }

    public init(from decodeur: any Decoder) throws {
        let conteneur = try decodeur.container(keyedBy: CodingKeys.self)

        format = try conteneur.decodeIfPresent(Int.self, forKey: .format) ?? Self.versionDeFormatAppliquee
        identifiant = try conteneur.decode(String.self, forKey: .identifiant)
        nom = try conteneur.decode(String.self, forKey: .nom)
        version = try conteneur.decode(VersionDExtension.self, forKey: .version)
        langue = try conteneur.decode(String.self, forKey: .langue)
        capacitesAnnoncees = try conteneur.decodeIfPresent([NomDeCapacite].self, forKey: .capacitesAnnoncees) ?? []
        domaines = try conteneur.decode([DomaineAutorise].self, forKey: .domaines)
        icone = try conteneur.decodeIfPresent(String.self, forKey: .icone)
        regles = try conteneur.decode(ReglesDExtension.self, forKey: .regles)
    }

    // MARK: Lecture

    /// Lit un manifeste depuis ses octets, en refusant tout ce qui depasse.
    ///
    /// - Throws: `ErreurDExtension`, dans le cas qui nomme le refus.
    public static func lire(_ donnees: Data) throws -> ManifesteDExtension {
        let arbre = try ValeurJson(donnees: donnees)

        try refuserLesClesInconnues(de: arbre)

        guard let manifeste = try? JSONDecoder().decode(ManifesteDExtension.self, from: donnees) else {
            throw ErreurDExtension.manifesteIllisible
        }

        try manifeste.valider()

        return manifeste
    }

    /// Leve des la premiere cle que le langage declaratif ne connait pas.
    private static func refuserLesClesInconnues(de arbre: ValeurJson) throws {
        let inconnues = arbre.clesPresentes.subtracting(MotsClesDuManifeste.connus)

        guard let premiere = inconnues.min() else {
            return
        }

        throw ErreurDExtension.cleInconnue(nom: premiere)
    }

    /// Verifie ce que le decodage ne sait pas verifier.
    ///
    /// - Throws: `ErreurDExtension`, dans le cas qui nomme le refus.
    public func valider() throws {
        guard format == Self.versionDeFormatAppliquee else {
            throw ErreurDExtension.formatNonPrisEnCharge(
                annoncee: format,
                appliquee: Self.versionDeFormatAppliquee
            )
        }
        guard Self.identifiantEstUtilisable(identifiant) else {
            throw ErreurDExtension.champManquant(nom: "identifiant")
        }
        guard nom.isEmpty == false else {
            throw ErreurDExtension.champManquant(nom: "nom")
        }
        guard langue.isEmpty == false else {
            throw ErreurDExtension.champManquant(nom: "langue")
        }
        guard icone.map(Self.nomDeFichierEstUtilisable) ?? true else {
            throw ErreurDExtension.champManquant(nom: "icone")
        }
        guard domaines.isEmpty == false else {
            throw ErreurDExtension.aucunDomaineDeclare
        }

        try validerLAdresseDeBase()
        try validerLAccordDesFormats()
    }

    /// Refuse une adresse de base en clair, ou hors de la liste blanche.
    ///
    /// La seconde verification compte autant que la premiere. Sans elle, une
    /// extension declarerait une liste blanche rassurante et poserait son
    /// adresse de base ailleurs, ce que l utilisateur n aurait jamais vu.
    private func validerLAdresseDeBase() throws {
        let adresse = regles.adresseDeBase

        guard adresse.scheme?.lowercased() == "https", let hote = adresse.host() else {
            throw ErreurDExtension.domaineMalForme(domaine: adresse.absoluteString)
        }
        guard ListeBlancheDeDomaines(domaines: domaines).autorise(hote) else {
            throw ErreurDExtension.domaineMalForme(domaine: hote)
        }
    }

    /// Refuse une regle dont le format annonce et les extractions divergent.
    private func validerLAccordDesFormats() throws {
        for accord in regles.accords {
            guard let fautive = accord.extractions.first(where: { $0.format != accord.format }) else {
                continue
            }

            throw ErreurDExtension.extractionMalFormee(texte: Self.texte(de: fautive))
        }
    }

    /// Les capacites que la source offrira reellement.
    ///
    /// C est l intersection de ce que le manifeste annonce et de ce que ses
    /// regles savent servir. Une capacite annoncee sans regle ferait offrir une
    /// action qui echouerait a tous les coups, ce que le premier critere de
    /// F026 interdit deja pour toutes les sources.
    public var capacites: SourceCapacites {
        let annoncees = capacitesAnnoncees.reduce(into: SourceCapacites()) { jeu, nom in
            jeu.insert(nom.capacite)
        }

        return annoncees.intersection(regles.capacitesServies)
    }

    /// La liste blanche que cette extension impose a ses requetes.
    public var listeBlanche: ListeBlancheDeDomaines {
        ListeBlancheDeDomaines(domaines: domaines)
    }

    /// Sous titre de la ligne de source, tableau 4.4 de DESIGN-SPEC.md.
    ///
    /// Le tableau ecrit `v1.4  multilingue` pour une extension de catalogue. Le
    /// second element est la langue du catalogue, et vaut multilingue quand
    /// l extension sert plusieurs langues.
    public var libelleDeVersion: String {
        "v" + version.texte
    }

    // MARK: Verifications de forme

    /// Vrai quand l identifiant ne contient que ce qu un nom de dossier accepte.
    ///
    /// Il sert de nom de dossier au paquet installe et de cle dans le journal.
    /// Un point d interrogation ou une barre oblique y designerait autre chose
    /// que l extension elle meme.
    static func identifiantEstUtilisable(_ identifiant: String) -> Bool {
        guard (1...64).contains(identifiant.count) else {
            return false
        }

        return identifiant.allSatisfy { $0.isLowercase && $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" }
    }

    /// Vrai quand le nom d icone designe un fichier du paquet et rien d autre.
    static func nomDeFichierEstUtilisable(_ nom: String) -> Bool {
        guard (1...128).contains(nom.count), nom.contains("/") == false, nom.contains("\\") == false else {
            return false
        }

        return nom.contains("..") == false
    }

    /// Forme textuelle d une extraction, pour un message de refus.
    private static func texte(de extraction: Extraction) -> String {
        switch extraction {
        case let .json(chemin): chemin.texte
        case let .html(selecteur, _): selecteur.texte
        }
    }
}

// MARK: - Vocabulaire du manifeste

/// Tous les noms de cles que le langage declaratif connait.
///
/// La liste est assemblee depuis les `CodingKeys` de chaque type plutot
/// qu ecrite a la main : une cle ajoutee a un type sans etre ajoutee ici ferait
/// refuser tous les manifestes qui l emploient, y compris les notres, et le
/// test de lecture d un manifeste complet le montrerait immediatement.
public enum MotsClesDuManifeste {
    /// Les cles connues, tous types confondus.
    public static let connus: Set<String> = {
        var assembles: Set<String> = []

        for jeu in jeuxDeCles {
            assembles.formUnion(jeu)
        }

        return assembles
    }()

    /// Les cles declarees par chaque type du langage, un jeu par type.
    ///
    /// La liste est ecrite type par type et non en un seul litteral : un
    /// litteral de quatorze appels a `map` sur autant de types differents ne se
    /// verifie pas en un temps raisonnable par le compilateur.
    private static let jeuxDeCles: [[String]] = {
        var jeux: [[String]] = []

        jeux.append(ManifesteDExtension.CodingKeys.allCases.map(\.rawValue))
        jeux.append(ReglesDExtension.CodingKeys.allCases.map(\.rawValue))
        jeux.append(RegleDeSection.CodingKeys.allCases.map(\.rawValue))
        jeux.append(RegleDeSeries.CodingKeys.allCases.map(\.rawValue))
        jeux.append(RegleDeDetail.CodingKeys.allCases.map(\.rawValue))
        jeux.append(RegleDeChapitres.CodingKeys.allCases.map(\.rawValue))
        jeux.append(RegleDePages.CodingKeys.allCases.map(\.rawValue))
        jeux.append(RegleDeRequete.CodingKeys.allCases.map(\.rawValue))
        jeux.append(ParametreDeRequete.CodingKeys.allCases.map(\.rawValue))
        jeux.append(CorrespondanceDeSerie.CodingKeys.allCases.map(\.rawValue))
        jeux.append(CorrespondanceDeChapitre.CodingKeys.allCases.map(\.rawValue))
        jeux.append(CorrespondanceDePage.CodingKeys.allCases.map(\.rawValue))
        jeux.append(ReglePagination.CodingKeys.allCases.map(\.rawValue))
        jeux.append(Extraction.CodingKeys.allCases.map(\.rawValue))

        return jeux
    }()
}
