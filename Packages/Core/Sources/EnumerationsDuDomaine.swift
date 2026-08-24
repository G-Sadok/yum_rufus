//
// EnumerationsDuDomaine
//
// Les enumerations citees entre parentheses par la section 3.1 du cahier de
// developpement. Toutes portent une representation textuelle stable, parce que
// cette representation est ecrite dans la base et doit survivre a un
// renommage de cas en Swift.
//

/// Nature d une source de contenu, telle qu enumeree par la section 4.2.
public enum TypeDeSource: String, Sendable, Codable, CaseIterable, Hashable {
    case fichiersLocaux
    case iCloudDrive
    case komga
    case kavita
    case jellyfin
    case opds
    case smb
    case nfs
    case webdav
    case depotExtensions
    /// Source pilotee par une extension declarative interpretee par nos soins.
    case extensionDeclarative
    case transfertWiFi
}

/// Resultat de la derniere verification de connexion d une source.
public enum EtatConnexion: String, Sendable, Codable, CaseIterable, Hashable {
    /// Aucune verification n a encore eu lieu.
    case nonVerifie
    case connecte
    case identifiantsInvalides
    case injoignable
    /// Echec qui n est ni une authentification ni une injoignabilite.
    case erreur
}

/// Statut editorial d une serie.
public enum StatutSerie: String, Sendable, Codable, CaseIterable, Hashable {
    case inconnu
    case enCours
    case termine
    case enPause
    case abandonne
}

/// Etat d une entree de la file de telechargement.
public enum EtatTelechargement: String, Sendable, Codable, CaseIterable, Hashable {
    case enAttente
    case enCours
    case suspendu
    case termine
    case echoue
    case annule
}

/// Service de suivi de lecture externe, d apres la section 9.
public enum ServiceDeSuivi: String, Sendable, Codable, CaseIterable, Hashable {
    case aniList
    case myAnimeList
    case kitsu
    case mangaUpdates
}

/// Statut d une serie tel qu il est publie vers un service de suivi.
public enum StatutDeSuivi: String, Sendable, Codable, CaseIterable, Hashable {
    case enLecture
    case termine
    case enPause
    case abandonne
    case prevu
    case relecture
}
