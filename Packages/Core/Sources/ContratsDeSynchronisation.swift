import Foundation

//
// ContratsDeSynchronisation
//
// Les deux coutures par lesquelles le moteur de synchronisation touche le
// reste du produit : la ou le journal survit a l extinction de l appareil, et
// la ou un changement recu devient un etat visible.
//
// Elles sont definies par `Core` et non par `Sync`, comme `EnregistreurDePosition`
// l est deja. La raison est la meme : le moteur ne doit pas dependre de la
// base de donnees, et un test doit pouvoir lui donner un magasin en memoire
// sans ouvrir un fichier SQLite pour verifier une regle de cadence.
//

/// La ou le journal de changements survit a la fermeture de l application.
///
/// Le journal doit etre persiste, et pas seulement tenu en memoire. Un
/// utilisateur qui lit six chapitres dans un train sans reseau puis ferme
/// l application perdrait sinon les six, et decouvrirait la perte sur l autre
/// appareil, sans message et sans moyen de la rattraper.
public protocol MagasinDuJournalDeChangements: Sendable {
    /// Changements produits localement et pas encore accuses.
    func journal() async throws -> JournalDeChangements

    /// Ajoute des changements au journal, en regroupant par cle.
    func consigner(_ changements: [ChangementSynchronise]) async throws

    /// Retire du journal ce que le distant a accuse.
    func retirer(_ envoyes: [ChangementSynchronise]) async throws

    /// Point de reprise du distant, opaque, tel que l entrepot l a rendu.
    ///
    /// Il est traite comme une suite d octets et jamais interprete : c est un
    /// jeton de serveur CloudKit, dont la forme appartient au systeme et peut
    /// changer d une version a l autre.
    func jetonDistant() async throws -> Data?

    /// Enregistre le point de reprise rendu par le dernier echange.
    func definirLeJetonDistant(_ jeton: Data?) async throws

    /// Instant du dernier envoi accepte par le distant, pour la ligne
    /// `Dernier envoi` de la section iCloud des reglages.
    func dernierEnvoi() async throws -> Date?

    /// Enregistre l instant du dernier envoi accepte.
    func definirLeDernierEnvoi(_ date: Date) async throws
}

/// La ou un changement recu d un autre appareil devient un etat local.
///
/// L applicateur est separe du moteur parce que les deux repondent a deux
/// questions differentes. Le moteur decide de ce qui circule et quand ;
/// l applicateur sait ce qu une progression veut dire pour la base. Un moteur
/// qui ecrirait lui meme dans les tables devrait connaitre chaque entite, et il
/// faudrait le modifier pour en ajouter une.
public protocol ApplicateurDeChangements: Sendable {
    /// Applique les changements recus et rend ceux qui ont reellement change
    /// quelque chose.
    ///
    /// Un changement portant sur un chapitre absent de cet appareil est ignore
    /// sans erreur : la serie n y est pas encore, ou n y sera jamais, et faire
    /// echouer tout le lot pour cela bloquerait la synchronisation des autres.
    /// Un changement plus ancien que l etat local est ignore de meme, selon la
    /// regle de `ResolutionDeConflit`.
    @discardableResult
    func appliquer(_ changements: [ChangementSynchronise]) async throws -> [ChangementSynchronise]
}
