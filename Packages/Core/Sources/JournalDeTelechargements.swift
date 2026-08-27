import Foundation

//
// JournalDeTelechargements et DepotDeChapitres
//
// Les deux dependances du moteur de telechargement, declarees ici pour la meme
// raison que `SourceProvider` : le moteur vit dans le paquet Sources, la file
// vit dans Storage, et Sources ne depend pas de Storage. Sans ces deux
// protocoles il faudrait ou bien inverser la dependance, ou bien remonter le
// moteur dans une couche qui voit tout, ce qui reviendrait a le mettre dans
// l application.
//
// Les methodes sont declarees asynchrones bien que le magasin les serve de
// facon synchrone. Une fonction synchrone satisfait une exigence asynchrone, et
// l inverse serait faux : ecrire l exigence en synchrone interdirait toute autre
// implementation, a commencer par un journal pose sur un acteur.
//

/// Ce que le moteur ecrit et relit de la file.
///
/// Le protocole ne porte que ce dont le moteur a besoin. Les commandes de
/// l ecran de suivi, pause, priorite, retrait, n y figurent pas : le moteur ne
/// les declenche jamais, il les subit au tour de file suivant.
public protocol JournalDeTelechargements: Sendable {
    /// File entiere, dans son ordre de passage.
    func taches() async throws -> [TelechargementAffiche]

    /// Reglages du sous ecran, limite simultanee comprise.
    func reglages() async throws -> ReglagesDeTelechargement

    /// Marque une tache comme demarree.
    func demarrer(_ identifiant: UUID) async throws

    /// Renvoie une tache en cours dans la file.
    func remettreEnAttente(_ identifiant: UUID) async throws

    /// Enregistre la longueur du chapitre annoncee par la source.
    func noterLaLongueur(de identifiant: UUID, nombreDePages: Int, octetsTotal: Int?) async throws

    /// Enregistre une page scellee et les octets recus depuis le debut.
    func noterUnePageScellee(de identifiant: UUID, pagesTerminees: Int, octetsRecus: Int) async throws

    /// Marque une tache comme terminee.
    func terminer(_ identifiant: UUID) async throws

    /// Marque une tache comme echouee, avec le message destine a l utilisateur.
    func echouer(_ identifiant: UUID, message: String) async throws
}

/// Ou le moteur pose les pages telechargees.
///
/// Le protocole distingue ecrire et sceller, et cette distinction est le coeur
/// de la reprise. Une page a moitie ecrite au moment d une coupure ne doit
/// jamais etre prise pour une page complete au lancement suivant : elle reste un
/// fragment jusqu a ce que le moteur la scelle, et l inventaire ne compte que ce
/// qui est scelle.
public protocol DepotDeChapitres: Sendable {
    /// Ce qui est deja pose sur le disque pour ce chapitre.
    func inventaire(du chapitre: UUID) async throws -> InventaireDeTelechargement

    /// Ecrit ou complete le fragment d une page.
    ///
    /// - Parameter enPoursuivant: vrai pour ajouter les octets a la suite du
    ///   fragment, faux pour remplacer ce qui s y trouve. Le second cas est
    ///   celui du serveur qui a ignore la demande de tranche.
    func ecrire(_ octets: Data, page: Int, du chapitre: UUID, enPoursuivant: Bool) async throws

    /// Fait du fragment la page definitive.
    ///
    /// - Returns: le poids de la page scellee, en octets.
    func sceller(page: Int, du chapitre: UUID) async throws -> Int
}

/// Ce qui rapporte les requetes de pages d un chapitre de la bibliotheque.
///
/// Le moteur ne connait pas les sources. Un chapitre de la base porte un
/// identifiant local, la source porte un identifiant distant, et faire le lien
/// entre les deux demande la base : c est le travail de l appelant, pas celui du
/// moteur.
public protocol FournisseurDePagesATelecharger: Sendable {
    /// Requetes qui rapportent les pages du chapitre, dans l ordre de lecture.
    ///
    /// - Throws: `ErreurDeTelechargement.chapitreInconnu` quand le chapitre
    ///   n existe plus, `ErreurDeSource` quand la source refuse de repondre.
    func requetesDePages(duChapitre chapitre: UUID) async throws -> [URLRequest]
}
