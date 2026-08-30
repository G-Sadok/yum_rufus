import Core
import Foundation
import GRDB

//
// TablesDeSynchronisation
//
// Les deux tables du journal de changements de la section 2.2 : ce qui attend
// de partir, et ou en est l echange avec le distant.
//
// Le journal est une table et non un fichier. Il est ecrit a chaque
// enregistrement de position, donc toutes les deux secondes pendant une
// lecture, et relu au lancement : un fichier reecrit en entier a cette cadence
// serait une reecriture complete toutes les deux secondes, et une coupure
// pendant l ecriture le tronquerait. La table donne l ecriture par ligne et la
// transaction, aux deux endroits ou le produit ne peut pas se permettre de
// perdre ce qui n est pas encore parti.
//
// La cle primaire est la cle de changement, exactement celle du journal en
// memoire. Le regroupement par cle est donc tenu par le schema lui meme : une
// insertion de la meme cle remplace, et aucune requete ne peut laisser deux
// versions du meme chapitre en attente.
//

/// Cree les tables du journal de synchronisation.
func creerLesTablesDeSynchronisation(_ base: Database) throws {
    try base.create(table: ChangementPersiste.databaseTableName) { table in
        table.primaryKey("cle", .text)
        table.column("charge", .blob).notNull()
        table.column("horodatage", .datetime).notNull()
        table.column("appareil", .text).notNull()
        table.column("supprime", .boolean).notNull().defaults(to: false)
    }

    try base.create(table: PointDeSynchronisation.databaseTableName) { table in
        table.primaryKey("cle", .text)
        table.column("valeur", .blob)
        table.column("date", .datetime)
    }

    try base.create(table: ChangementApplique.databaseTableName) { table in
        table.primaryKey("cle", .text)
        table.column("horodatage", .datetime).notNull()
        table.column("appareil", .text).notNull()
    }
}

/// Une ligne du journal de changements en attente d envoi.
struct ChangementPersiste: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "changementDeSynchronisation"

    /// Forme textuelle de la cle de changement.
    var cle: String

    /// Charge encodee par la couche metier de l entite.
    var charge: Data

    /// Instant du changement sur cet appareil.
    var horodatage: Date

    /// Appareil qui a produit le changement.
    var appareil: String

    /// Vrai quand la ligne dit que l objet a disparu.
    var supprime: Bool

    /// Projette une ligne de journal vers sa forme persistee.
    init(_ changement: ChangementSynchronise) {
        cle = changement.cle.texte
        charge = changement.charge
        horodatage = changement.horodatage
        appareil = changement.appareil
        supprime = changement.supprime
    }

    /// Ligne de journal relue, nulle quand la cle vient d une version du
    /// produit que celle ci ne connait pas.
    ///
    /// Une cle inconnue est ignoree et non supprimee. Elle vient forcement
    /// d une version plus recente, et l effacer ferait perdre pour de bon un
    /// changement qu une bascule de version en arriere aurait encore pu
    /// envoyer.
    func changement() -> ChangementSynchronise? {
        guard let cle = CleDeChangement.lire(cle) else {
            return nil
        }

        return ChangementSynchronise(
            cle: cle,
            charge: charge,
            horodatage: horodatage,
            appareil: appareil,
            supprime: supprime
        )
    }
}

/// Ce qu un changement recu a laisse comme trace, une ligne par cle.
///
/// La table repond a une question que les tables metier ne savent pas
/// repondre : quelle version d une serie cet appareil a t il deja appliquee.
/// La progression a sa date de lecture, qui suffit a arbitrer, mais la presence
/// d une serie dans la bibliotheque n a pas d horodatage propre. Sans cette
/// trace, un lot rejoue apres un jeton perime reappliquerait un retrait de
/// bibliotheque que l utilisateur venait d annuler.
struct ChangementApplique: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "changementApplique"

    /// Forme textuelle de la cle de changement.
    var cle: String

    /// Horodatage de la version appliquee.
    var horodatage: Date

    /// Appareil qui avait produit la version appliquee.
    var appareil: String
}

/// Un point de reprise de l echange avec le distant.
struct PointDeSynchronisation: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "pointDeSynchronisation"

    /// Nom du point de reprise.
    var cle: String

    /// Valeur opaque, le jeton de serveur quand il y en a un.
    var valeur: Data?

    /// Date, pour les points qui en sont une.
    var date: Date?

    /// Cle du jeton de reprise du distant.
    static let jetonDistant = "jetonDistant"

    /// Cle de l instant du dernier envoi accepte.
    static let dernierEnvoi = "dernierEnvoi"

    /// Cle de l identifiant stable de cet appareil.
    static let identifiantDAppareil = "identifiantDAppareil"
}
