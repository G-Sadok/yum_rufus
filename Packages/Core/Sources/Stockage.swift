import Foundation

//
// Stockage
//
// Ce que les trois ecrans de detail de la section 15 de l ecran Reglages
// montrent, et la regle qui transforme un pesage de disque en ligne d ecran.
//
// Le modele ne porte aucun chiffre venu de la base. Une taille affichee est
// toujours celle que le disque a rendue, jamais la colonne `octetsRecus` de la
// table des telechargements. Les deux divergent des qu une page est rescellee,
// qu un fichier est supprime a la main, ou qu une tache echoue apres avoir
// annonce un poids : la base dit ce qui etait attendu, le disque dit ce qui est
// la, et c est le second que l ecran de stockage doit lire.
//
// Un poste est ce qu une ligne d ecran de detail designe, et ce que la
// suppression selective prend pour cible. Il ne recouvre pas toujours un seul
// element du disque : le cache d images est fait de fichiers dont le nom est un
// condensat, que rien ne permet de nommer a l utilisateur. Ces elements sont
// comptes ensemble dans un poste unique plutot que montres un a un, ce qui evite
// d etaler du vocabulaire technique a l ecran et laisse malgre tout leur poids
// visible et supprimable.
//

/// Une des trois familles de fichiers que la section 15 expose.
///
/// L ordre des cas est celui de l inventaire des reglages du cahier de
/// developpement, et donc celui des lignes de l ecran d ensemble.
public enum CategorieDeStockage: String, Sendable, Codable, CaseIterable, Hashable {
    /// Chapitres poses sur le disque par la file de telechargement.
    case chapitresTelecharges

    /// Conteneurs rapatries par les sources qui ne servent pas la page seule.
    case cacheDeChapitres

    /// Pages decodees gardees par le cache disque de la chaine d images.
    case cacheDImages

    /// Vrai quand la categorie peut etre videe sans rien perdre.
    ///
    /// Un cache se reconstruit a la lecture suivante. Un chapitre telecharge ne
    /// se reconstruit qu en repassant par sa source, ce que la description de la
    /// section 6.8 annonce a l utilisateur.
    public var estUnCache: Bool {
        self != .chapitresTelecharges
    }
}

// MARK: Pesage

/// Ce qu une mesure de disque rapporte d un element.
///
/// Le nom est celui du fichier ou du dossier sur le disque. Il sert de cle de
/// suppression : l ecran ne peut viser que ce que la mesure a vu, ce qui
/// interdit a une commande d atteindre un chemin que personne n a liste.
public struct PesageSurDisque: Sendable, Equatable, Hashable {
    /// Nom de l element dans le dossier de sa categorie.
    public let nom: String

    /// Poids de l element, octets de tout son contenu compris.
    public let octets: Int

    public init(nom: String, octets: Int) {
        self.nom = nom
        self.octets = octets
    }
}

// MARK: Postes

/// Chapitre telecharge, tel que la bibliotheque le nomme.
public struct ChapitreDeStockage: Sendable, Equatable, Hashable {
    /// Chapitre vise, cible de la suppression et du nettoyage apres lecture.
    public let chapitreId: UUID

    /// Titre de la serie, premiere partie du titre de la ligne.
    public let titreDeLaSerie: String

    /// Numero du chapitre, seconde partie du titre de la ligne.
    public let numeroDeChapitre: Double

    /// Vrai quand le chapitre a ete lu jusqu au bout.
    ///
    /// La sous ligne le dit en clair. Sans lui, l utilisateur qui a active la
    /// suppression apres lecture ne saurait pas lesquels de ses chapitres sont
    /// sur le point de partir.
    public let estLu: Bool

    public init(chapitreId: UUID, titreDeLaSerie: String, numeroDeChapitre: Double, estLu: Bool) {
        self.chapitreId = chapitreId
        self.titreDeLaSerie = titreDeLaSerie
        self.numeroDeChapitre = numeroDeChapitre
        self.estLu = estLu
    }
}

/// Ce qu un poste de stockage designe.
public enum ContenuDePoste: Sendable, Equatable, Hashable {
    /// Un chapitre telecharge, nomme par la bibliotheque.
    case chapitre(ChapitreDeStockage)

    /// Le cache d une source, nomme par la liste des sources.
    case source(nom: String)

    /// Des elements que rien ne nomme, comptes ensemble.
    case elementsAnonymes(nombre: Int)
}

/// Une ligne d un ecran de detail du stockage.
public struct PosteDeStockage: Sendable, Equatable, Hashable, Identifiable {
    /// Cle stable de la ligne.
    public let id: String

    /// Ce que la ligne designe, et donc comment elle se nomme.
    public let contenu: ContenuDePoste

    /// Poids reel du poste sur le disque.
    public let octets: Int

    /// Noms sur le disque que la suppression de ce poste emporte.
    public let elements: [String]

    public init(id: String, contenu: ContenuDePoste, octets: Int, elements: [String]) {
        self.id = id
        self.contenu = contenu
        self.octets = octets
        self.elements = elements
    }

    /// Chapitre du poste, nul quand il n en designe pas un.
    public var chapitre: ChapitreDeStockage? {
        guard case let .chapitre(chapitre) = contenu else {
            return nil
        }

        return chapitre
    }
}

/// Contenu d un ecran de detail, une categorie et ses postes.
public struct DetailDuStockage: Sendable, Equatable {
    /// Categorie montree.
    public let categorie: CategorieDeStockage

    /// Postes, du plus lourd au plus leger.
    public let postes: [PosteDeStockage]

    public init(categorie: CategorieDeStockage, postes: [PosteDeStockage]) {
        self.categorie = categorie
        self.postes = postes
    }

    /// Poids de la categorie entiere.
    public var octets: Int {
        postes.reduce(0) { $0 + $1.octets }
    }

    /// Tous les noms de disque de la categorie, cible de la suppression totale.
    public var elements: [String] {
        postes.flatMap(\.elements)
    }
}

/// Ce que l ecran d ensemble du stockage montre.
///
/// Les trois categories y figurent toujours, meme a zero octet. L etat vide de
/// la section 5.5 le demande explicitement : la colonne reste complete, ce sont
/// les valeurs qui disent l absence.
public struct InventaireDuStockage: Sendable, Equatable {
    /// Poids de chaque categorie, dans l ordre de l enumeration.
    public let octetsParCategorie: [CategorieDeStockage: Int]

    public init(octetsParCategorie: [CategorieDeStockage: Int]) {
        self.octetsParCategorie = octetsParCategorie
    }

    /// Inventaire ou tout est a zero, celui d une installation neuve.
    public static let vide = InventaireDuStockage(
        octetsParCategorie: Dictionary(uniqueKeysWithValues: CategorieDeStockage.allCases.map { ($0, 0) })
    )

    /// Poids d une categorie, zero quand elle n a rien rendu.
    public func octets(de categorie: CategorieDeStockage) -> Int {
        octetsParCategorie[categorie] ?? 0
    }

    /// Poids des trois categories reunies.
    public var octetsTotal: Int {
        CategorieDeStockage.allCases.reduce(0) { $0 + octets(de: $1) }
    }
}

// MARK: Assemblage

/// Transformation des pesages du disque en postes d ecran.
public enum AssemblageDesPostes {
    /// Cle du poste qui regroupe les elements que rien ne nomme.
    public static let clesDesAnonymes = "stockage.elementsAnonymes"

    /// Postes d une categorie, du plus lourd au plus leger.
    ///
    /// Le nommage est une fonction et non une table pour une raison de cout :
    /// un dossier de telechargements porte autant d elements que de chapitres
    /// gardes, et l appelant sait resoudre les noms en une requete plutot qu en
    /// une par element.
    ///
    /// Les elements qu il ne resout pas ne sont pas jetes. Ils forment un poste
    /// unique, qui porte leur nombre et leur poids cumule : un cache d images
    /// entier tient dans une ligne, sans montrer un condensat que personne ne
    /// sait lire, et sans faire disparaitre du compte des octets bien reels.
    ///
    /// - Parameters:
    ///   - pesages: ce que la mesure du disque a rendu.
    ///   - nommage: ce que l appelant sait dire d un nom de disque.
    public static func postes(
        depuis pesages: [PesageSurDisque],
        nommage: (String) -> ContenuDePoste?
    ) -> [PosteDeStockage] {
        var nommes: [PosteDeStockage] = []
        var anonymes: [PesageSurDisque] = []

        for pesage in pesages {
            guard let contenu = nommage(pesage.nom) else {
                anonymes.append(pesage)
                continue
            }

            nommes.append(
                PosteDeStockage(
                    id: pesage.nom,
                    contenu: contenu,
                    octets: pesage.octets,
                    elements: [pesage.nom]
                )
            )
        }

        if anonymes.isEmpty == false {
            nommes.append(
                PosteDeStockage(
                    id: clesDesAnonymes,
                    contenu: .elementsAnonymes(nombre: anonymes.count),
                    octets: anonymes.reduce(0) { $0 + $1.octets },
                    elements: anonymes.map(\.nom).sorted()
                )
            )
        }

        return trier(nommes)
    }

    /// Postes ranges du plus lourd au plus leger.
    ///
    /// Le poids d abord, parce que l ecran sert a liberer de la place et que la
    /// ligne utile est la plus grosse. La cle departe deux postes de meme poids,
    /// ce qui rend l ordre total : deux lectures du meme disque rendent la meme
    /// liste, et une ligne ne saute pas d une place a l autre entre deux
    /// affichages.
    public static func trier(_ postes: [PosteDeStockage]) -> [PosteDeStockage] {
        postes.sorted { premier, second in
            premier.octets == second.octets
                ? premier.id < second.id
                : premier.octets > second.octets
        }
    }
}
