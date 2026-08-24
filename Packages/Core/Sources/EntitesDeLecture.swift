import Foundation

//
// EntitesDeLecture
//
// Historique, signets, telechargements, prereglages et liaisons de suivi,
// d apres la section 3.1 du cahier de developpement.
//

/// Passage de lecture consigne dans l historique.
///
/// Le mode incognito de la section 9 n ecrit aucune entree ici.
public struct EntreeHistorique: Sendable, Codable, Identifiable, Hashable {
    public var id: UUID
    public var chapitreId: UUID
    public var dateLecture: Date

    /// Duree de la session de lecture, en secondes.
    public var dureeSeconde: Int

    /// Page atteinte a la fin du passage, indexee a partir de zero.
    public var pageAtteinte: Int

    public init(
        id: UUID = UUID(),
        chapitreId: UUID,
        dateLecture: Date = Date(),
        dureeSeconde: Int = 0,
        pageAtteinte: Int = 0
    ) {
        self.id = id
        self.chapitreId = chapitreId
        self.dateLecture = dateLecture
        self.dureeSeconde = dureeSeconde
        self.pageAtteinte = pageAtteinte
    }
}

/// Marque posee par l utilisateur sur une page precise.
public struct Signet: Sendable, Codable, Identifiable, Hashable {
    public var id: UUID
    public var chapitreId: UUID

    /// Page marquee, indexee a partir de zero.
    public var pageIndex: Int

    public var note: String?
    public var dateCreation: Date

    /// Chemin de la vignette produite au moment de la pose du signet.
    public var vignetteLocale: String?

    public init(
        id: UUID = UUID(),
        chapitreId: UUID,
        pageIndex: Int,
        note: String? = nil,
        dateCreation: Date = Date(),
        vignetteLocale: String? = nil
    ) {
        self.id = id
        self.chapitreId = chapitreId
        self.pageIndex = pageIndex
        self.note = note
        self.dateCreation = dateCreation
        self.vignetteLocale = vignetteLocale
    }
}

/// Entree de la file de telechargement d un chapitre.
public struct Telechargement: Sendable, Codable, Identifiable, Hashable {
    public var id: UUID
    public var chapitreId: UUID
    public var etat: EtatTelechargement

    /// Avancement entre zero et un.
    public var progression: Double

    /// Poids total attendu en octets, quand la source l annonce.
    public var octetsTotal: Int?

    public var dateAjout: Date

    /// Message d erreur destine a l utilisateur, renseigne quand l etat vaut
    /// `echoue`. Il nomme la cause et indique la sortie.
    public var messageErreur: String?

    public init(
        id: UUID = UUID(),
        chapitreId: UUID,
        etat: EtatTelechargement = .enAttente,
        progression: Double = 0,
        octetsTotal: Int? = nil,
        dateAjout: Date = Date(),
        messageErreur: String? = nil
    ) {
        self.id = id
        self.chapitreId = chapitreId
        self.etat = etat
        self.progression = progression
        self.octetsTotal = octetsTotal
        self.dateAjout = dateAjout
        self.messageErreur = messageErreur
    }
}

/// Jeu de reglages du lecteur enregistre sous un nom.
public struct PrereglageLecture: Sendable, Codable, Identifiable, Hashable {
    public var id: UUID
    public var nom: String

    /// Ensemble des reglages du lecteur encode en JSON. Le format reste
    /// opaque a la base pour que l ajout d un reglage n impose pas une
    /// migration de schema.
    public var donneesReglages: Data

    public init(id: UUID = UUID(), nom: String, donneesReglages: Data) {
        self.id = id
        self.nom = nom
        self.donneesReglages = donneesReglages
    }
}

/// Lien entre une serie locale et son entree chez un service de suivi.
public struct LiaisonSuivi: Sendable, Codable, Identifiable, Hashable {
    public var id: UUID
    public var mangaId: UUID
    public var service: ServiceDeSuivi

    /// Identifiant de la serie chez le service de suivi.
    public var identifiantDistant: String

    public var statut: StatutDeSuivi

    /// Dernier chapitre declare comme vu au service.
    public var chapitreVu: Double

    /// Note attribuee par l utilisateur, dans l echelle du service.
    public var note: Double?

    public var dateSynchronisation: Date?

    public init(
        id: UUID = UUID(),
        mangaId: UUID,
        service: ServiceDeSuivi,
        identifiantDistant: String,
        statut: StatutDeSuivi = .enLecture,
        chapitreVu: Double = 0,
        note: Double? = nil,
        dateSynchronisation: Date? = nil
    ) {
        self.id = id
        self.mangaId = mangaId
        self.service = service
        self.identifiantDistant = identifiantDistant
        self.statut = statut
        self.chapitreVu = chapitreVu
        self.note = note
        self.dateSynchronisation = dateSynchronisation
    }
}
