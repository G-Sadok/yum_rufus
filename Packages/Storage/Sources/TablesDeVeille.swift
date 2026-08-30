import Core
import Foundation
import GRDB

//
// TablesDeVeille
//
// Les deux tables de F060 : ce que la veille a deja vu de chaque serie, et
// l etat de ses quotas.
//
// La liste des chapitres connus n est pas recopiee ici. La table `chapitre`
// porte deja tout ce que l appareil connait d une serie, et la dupliquer ferait
// deux verites qui divergeraient au premier import. La table de veille ne
// retient que les identifiants annonces par une notification et absents de la
// base, c est a dire ce que l utilisateur a deja vu passer sans l avoir encore
// importe. Sans eux, la meme nouveaute repartirait a chaque execution.
//
// L etat des quotas vit dans une table d une seule ligne, comme l objectif de
// lecture. Il ne peut pas vivre dans le catalogue de reglages : ce n est pas un
// choix de l utilisateur, c est une comptabilite interne, et la section 5.5 de
// DESIGN-SPEC.md fixe le contenu de cet ecran.
//

/// Cree la table de veille par serie et celle de l etat des quotas.
func creerLesTablesDeVeille(_ base: Database) throws {
    try base.create(table: VeilleDeSeriePersistee.databaseTableName) { table in
        // Une ligne par serie surveillee, la cle est celle de la serie.
        table.primaryKey("mangaId", .blob)
            .references("manga", onDelete: .cascade)
        table.column("derniereVerification", .datetime)

        // JSON des identifiants annonces mais pas encore importes.
        table.column("chapitresAnnonces", .text).notNull().defaults(to: "[]")
    }

    try base.create(table: EtatDeVeillePersiste.databaseTableName) { table in
        table.primaryKey("id", .integer)
        table.check(sql: "id = \(EtatDeVeillePersiste.identifiantDeLaLigneUnique)")

        table.column("derniereTentative", .datetime)
        table.column("derniereReussite", .datetime)
        table.column("echecsConsecutifs", .integer).notNull().defaults(to: 0)
        table.column("jourCompte", .datetime)
        table.column("executionsDuJour", .integer).notNull().defaults(to: 0)
    }

    try EtatDeVeillePersiste().insert(base)
}

/// Ce que la veille a retenu d une serie.
struct VeilleDeSeriePersistee: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "veilleDeSerie"

    var mangaId: UUID
    var derniereVerification: Date?

    /// Identifiants annonces, encodes en JSON.
    ///
    /// Une colonne de texte plutot qu une table de liaison : la liste ne se
    /// requete jamais, elle se lit et se remplace entierement a chaque
    /// verification de la serie.
    var chapitresAnnonces: String

    init(mangaId: UUID, derniereVerification: Date? = nil, chapitresAnnonces: String = "[]") {
        self.mangaId = mangaId
        self.derniereVerification = derniereVerification
        self.chapitresAnnonces = chapitresAnnonces
    }

    /// Identifiants annonces, tels que le domaine les lit.
    ///
    /// Un JSON illisible rend un ensemble vide plutot que de lever. La
    /// consequence d une lecture ratee est une notification repetee une fois,
    /// celle d une erreur remontee serait une veille definitivement arretee.
    var identifiants: Set<String> {
        guard let octets = chapitresAnnonces.data(using: .utf8),
              let liste = try? JSONDecoder().decode([String].self, from: octets)
        else {
            return []
        }

        return Set(liste)
    }

    /// Encode des identifiants pour la colonne, dans un ordre stable.
    static func encoder(_ identifiants: Set<String>) -> String {
        guard let octets = try? JSONEncoder().encode(identifiants.sorted()),
              let texte = String(data: octets, encoding: .utf8)
        else {
            return "[]"
        }

        return texte
    }
}

/// Etat des quotas de la veille, ligne unique.
struct EtatDeVeillePersiste: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "etatDeVeille"

    /// Identifiant de la ligne unique.
    static let identifiantDeLaLigneUnique = 1

    var id: Int
    var derniereTentative: Date?
    var derniereReussite: Date?
    var echecsConsecutifs: Int
    var jourCompte: Date?
    var executionsDuJour: Int

    init(
        id: Int = EtatDeVeillePersiste.identifiantDeLaLigneUnique,
        derniereTentative: Date? = nil,
        derniereReussite: Date? = nil,
        echecsConsecutifs: Int = 0,
        jourCompte: Date? = nil,
        executionsDuJour: Int = 0
    ) {
        self.id = id
        self.derniereTentative = derniereTentative
        self.derniereReussite = derniereReussite
        self.echecsConsecutifs = echecsConsecutifs
        self.jourCompte = jourCompte
        self.executionsDuJour = executionsDuJour
    }

    /// Construit la ligne depuis l etat du domaine.
    init(_ etat: EtatDeVeille) {
        self.init(
            derniereTentative: etat.derniereTentative,
            derniereReussite: etat.derniereReussite,
            echecsConsecutifs: etat.echecsConsecutifs,
            jourCompte: etat.jourCompte,
            executionsDuJour: etat.executionsDuJour
        )
    }

    /// Etat tel que la couche metier le lit.
    var etat: EtatDeVeille {
        EtatDeVeille(
            derniereTentative: derniereTentative,
            derniereReussite: derniereReussite,
            echecsConsecutifs: echecsConsecutifs,
            jourCompte: jourCompte,
            executionsDuJour: executionsDuJour
        )
    }
}
