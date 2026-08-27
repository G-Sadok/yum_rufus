import Foundation

//
// FileDeTelechargements
//
// Ce que la file de la section 4.11 de DESIGN-SPEC.md porte, et les deux regles
// que le domaine tranche : l ordre de passage, et la progression affichee.
//
// L ordre est ici et non dans le moteur pour une raison simple. Deux endroits
// decident aujourd hui de ce qui passe en premier, l ecran de suivi qui dresse
// la liste et le moteur qui choisit la prochaine tache. Si chacun triait de son
// cote, la ligne montree en tete ne serait pas toujours celle qui demarre, et
// personne ne saurait dire laquelle des deux a raison.
//
// La progression est comptee en pages et non en octets. Le document fixe la
// sous ligne, `14 sur 24 pages`, et une source qui n annonce pas la taille de
// ses images est le cas ordinaire, pas l exception : une progression en octets
// resterait a zero jusqu a la derniere page chez la moitie des serveurs. Les
// octets restent portes a cote, pour la sous ligne de l etat termine.
//

/// Rang de passage d une tache dans la file.
///
/// Trois rangs et non un entier libre. Un entier laisserait deux appelants
/// inventer leurs propres echelles, et la file finirait par comparer des
/// priorites qui ne veulent pas dire la meme chose.
public enum PrioriteDeTelechargement: String, Sendable, Codable, CaseIterable, Hashable, Comparable {
    /// Ce que l utilisateur vient de demander explicitement, et qui doit partir
    /// avant la file deja en place.
    case haute

    /// Le cas ordinaire, un chapitre ajoute a la file par une action directe.
    case normale

    /// Ce que l application a decide toute seule, la precharge des chapitres a
    /// l avance du reglage 12. Elle ne prend jamais la place de ce que
    /// l utilisateur a demande.
    case basse

    /// Rang de passage, du plus prioritaire au moins prioritaire.
    public var rang: Int {
        switch self {
        case .haute: 0
        case .normale: 1
        case .basse: 2
        }
    }

    /// Priorite d un ajout ordinaire.
    public static let parDefaut = PrioriteDeTelechargement.normale

    public static func < (gauche: PrioriteDeTelechargement, droite: PrioriteDeTelechargement) -> Bool {
        gauche.rang < droite.rang
    }
}

extension EtatTelechargement {
    /// Vrai quand la tache occupe une des places simultanees.
    public var occupeUnePlace: Bool {
        self == .enCours
    }

    /// Vrai quand la tache attend son tour et peut demarrer.
    public var attendSonTour: Bool {
        self == .enAttente
    }

    /// Vrai quand plus rien ne se passera sans une action de l utilisateur.
    ///
    /// La suspension en fait partie. Le planificateur ne relance jamais une
    /// ligne mise en pause depuis la section 4.11 : le retour du Wi-Fi ne doit
    /// pas defaire un geste de l utilisateur.
    public var estArrete: Bool {
        switch self {
        case .termine, .echoue, .annule, .suspendu: true
        case .enAttente, .enCours: false
        }
    }
}

/// Une ligne de la file de telechargement, telle que l ecran de suivi
/// l affiche.
///
/// Le type est distinct de `Telechargement` pour la meme raison que
/// `SignetAffiche` l est de `Signet` : la table ne connait ni le titre de la
/// serie ni le numero du chapitre, et la vue ne doit pas avoir a les chercher.
public struct TelechargementAffiche: Sendable, Equatable, Hashable, Identifiable {
    /// Identifiant de la tache, cible des commandes de la ligne.
    public let id: UUID

    /// Chapitre telecharge.
    public let chapitreId: UUID

    /// Serie a laquelle le chapitre appartient.
    public let serieId: UUID

    /// Titre de la serie, titre de la ligne.
    public let titreDeLaSerie: String

    /// Numero du chapitre, seconde partie du titre de la ligne.
    public let numeroDeChapitre: Double

    /// Titre du chapitre, absent chez beaucoup de sources.
    public let titreDuChapitre: String?

    /// Etat de la tache, qui decide de l indicateur et de la sous ligne.
    public let etat: EtatTelechargement

    /// Rang de passage dans la file.
    public let priorite: PrioriteDeTelechargement

    /// Pages entierement recues et scellees.
    public let pagesTerminees: Int

    /// Nombre de pages du chapitre, zero tant que la source ne l annonce pas.
    public let nombreDePages: Int

    /// Octets deja recus, page en cours comprise.
    public let octetsRecus: Int

    /// Poids total attendu, quand la source l annonce.
    public let octetsTotal: Int?

    /// Instant de la mise en file.
    public let dateAjout: Date

    /// Message destine a l utilisateur, renseigne quand l etat vaut `echoue`.
    public let messageErreur: String?

    public init(
        id: UUID = UUID(),
        chapitreId: UUID,
        serieId: UUID,
        titreDeLaSerie: String,
        numeroDeChapitre: Double,
        titreDuChapitre: String? = nil,
        etat: EtatTelechargement = .enAttente,
        priorite: PrioriteDeTelechargement = .parDefaut,
        pagesTerminees: Int = 0,
        nombreDePages: Int = 0,
        octetsRecus: Int = 0,
        octetsTotal: Int? = nil,
        dateAjout: Date,
        messageErreur: String? = nil
    ) {
        self.id = id
        self.chapitreId = chapitreId
        self.serieId = serieId
        self.titreDeLaSerie = titreDeLaSerie
        self.numeroDeChapitre = numeroDeChapitre
        self.titreDuChapitre = titreDuChapitre
        self.etat = etat
        self.priorite = priorite
        self.pagesTerminees = pagesTerminees
        self.nombreDePages = nombreDePages
        self.octetsRecus = octetsRecus
        self.octetsTotal = octetsTotal
        self.dateAjout = dateAjout
        self.messageErreur = messageErreur
    }

    /// Avancement entre zero et un.
    ///
    /// Une tache terminee vaut un meme quand le compte de pages est reste a
    /// zero, ce qui arrive avec une source qui n annonce pas sa longueur : la
    /// ligne dirait sinon qu il reste tout a faire sur un chapitre deja pose sur
    /// le disque.
    public var progression: Double {
        guard etat != .termine else {
            return 1
        }
        guard nombreDePages > 0 else {
            return 0
        }

        return AvancementDeTelechargement.part(pagesTerminees, sur: nombreDePages)
    }

    /// Vrai quand la tache occupe une des places simultanees.
    public var occupeUnePlace: Bool {
        etat.occupeUnePlace
    }

    /// Vrai quand la tache attend son tour et peut demarrer.
    public var attendSonTour: Bool {
        etat.attendSonTour
    }

    /// Vrai quand plus rien ne se passera sans une action de l utilisateur.
    public var estArretee: Bool {
        etat.estArrete
    }
}

// MARK: Avancement

/// Calcul de la part d avancement d une tache.
///
/// Il vit a part parce que trois couches en ont besoin et doivent trouver le
/// meme chiffre : le magasin qui persiste la colonne `progression`, le moteur
/// qui la met a jour page par page, et la vue qui dessine l anneau.
///
/// Le nom evite `ProgressionDeTelechargement`, deja pris par le suivi du
/// rapatriement d un fichier iCloud de la section 4.2. Les deux types ne
/// parlent pas de la meme chose et cohabitent dans le meme module d appel.
public enum AvancementDeTelechargement {
    /// Part d avancement, toujours ramenee entre zero et un.
    ///
    /// Le plafonnement n est pas une precaution de style. Une source qui annonce
    /// vingt pages puis en sert vingt deux ferait dessiner un anneau de plus
    /// d un tour, et la sous ligne annoncerait `22 sur 20 pages`.
    public static func part(_ faites: Int, sur total: Int) -> Double {
        guard total > 0 else {
            return 0
        }

        return min(1, max(0, Double(faites) / Double(total)))
    }

    /// Nombre de pages faites, ramene dans les bornes du chapitre.
    public static func pagesFaites(_ faites: Int, sur total: Int) -> Int {
        guard total > 0 else {
            return max(0, faites)
        }

        return min(total, max(0, faites))
    }
}

// MARK: Ordre de la file

/// Ordre de passage des taches de la file.
public enum OrdreDeLaFile {
    /// File rangee dans son ordre de passage.
    ///
    /// La priorite decide d abord, la date de mise en file ensuite. Sans le
    /// second critere, deux chapitres de meme priorite passeraient dans un ordre
    /// que rien ne fixe, et un utilisateur qui met une serie entiere en file la
    /// verrait arriver dans le desordre.
    ///
    /// L identifiant departe deux taches par ailleurs egales, ce qui rend
    /// l ordre total : deux lectures de la meme base rendent la meme file.
    public static func trier(_ taches: [TelechargementAffiche]) -> [TelechargementAffiche] {
        taches.sorted(by: passeAvant)
    }

    /// Vrai quand la premiere tache doit passer avant la seconde.
    public static func passeAvant(_ premiere: TelechargementAffiche, _ seconde: TelechargementAffiche) -> Bool {
        if premiere.priorite != seconde.priorite {
            return premiere.priorite < seconde.priorite
        }

        if premiere.dateAjout != seconde.dateAjout {
            return premiere.dateAjout < seconde.dateAjout
        }

        return premiere.id.uuidString < seconde.id.uuidString
    }
}

// MARK: Erreurs

/// Ce qui peut faire echouer la gestion de la file.
///
/// Chaque cas nomme la cause. La traduction en message utilisateur se fait dans
/// la couche vue, avec le catalogue de chaines.
public enum ErreurDeTelechargement: Error, Sendable, Equatable {
    /// La tache visee ne figure plus dans la file.
    case tacheInconnue(identifiant: UUID)

    /// Le chapitre vise n existe pas ou plus.
    case chapitreInconnu(identifiant: UUID)

    /// La source a servi une page dont le compte ne correspond a rien.
    case chapitreSansPage(identifiant: UUID)

    /// Le serveur a refuse de reprendre la ou le fichier partiel s arretait.
    ///
    /// Le cas est distinct d une panne reseau : il ne se repare pas en
    /// reessayant a l identique, il se repare en repartant de zero sur la page.
    case repriseRefusee(page: Int)
}
