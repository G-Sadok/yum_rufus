import Core
import Foundation
import GRDB

//
// TablesDeStatistiques
//
// Les deux tables de F059 : ce qu une journee a compte, et l objectif que
// l utilisateur s est donne.
//
// Le comptage est une table et non une agregation de l historique. Trois
// raisons, dans l ordre de gravite.
//
// 1. L historique s efface a la demande depuis la section 5.2. Un total calcule
//    depuis lui disparaitrait avec lui, alors que l utilisateur qui efface ses
//    traces de lecture ne demande pas d oublier combien il a lu.
// 2. L historique ne porte qu une ligne par chapitre et par jour, sans compter
//    les pages parcourues. La question de F059 n est pas la meme que la sienne.
// 3. Compter a la volee ramenerait le piege du compteur de non lus de la
//    section 3.2, sur un ecran qui defile.
//
// L objectif vit dans une table d une seule ligne, comme le sens de lecture
// global. Il n est pas une ligne du catalogue de reglages : la section 5.5 fixe
// dix sept sections et leur contenu, la section 3 y est imposee par le
// wireframe 05, et l inventaire de la section 9 du cahier de developpement, qui
// range `Objectif quotidien` dans General, entrerait en conflit avec elle. Le
// reglage est donc pose sur l ecran qu il gouverne, sous ecran que la section
// 5.5 confie a l implementation.
//

/// Cree la table des journees de lecture et celle de l objectif.
func creerLesTablesDeStatistiques(_ base: Database) throws {
    try base.create(table: JourneeDeLecturePersistee.databaseTableName) { table in
        // Une ligne par jour civil, la cle est le debut du jour.
        table.primaryKey("jour", .datetime)
        table.column("chapitresLus", .integer).notNull().defaults(to: 0)
        table.column("pagesLues", .integer).notNull().defaults(to: 0)
    }

    try base.create(table: ObjectifPersiste.databaseTableName) { table in
        // Reglage global, donc une seule ligne, comme le sens de lecture.
        table.primaryKey("id", .integer)
        table.check(sql: "id = \(ObjectifPersiste.identifiantDeLaLigneUnique)")

        // Nul veut dire `Desactive`, la valeur livree par l inventaire de la
        // section 9. Un zero voudrait dire un objectif de zero chapitre, qui
        // n existe pas.
        table.column("chapitresParJour", .integer)
        table.column("rappelActif", .boolean).notNull().defaults(to: false)
        table.column("heureDeRappel", .integer).notNull()
            .defaults(to: RappelDObjectif.heureParDefaut)
        table.column("minuteDeRappel", .integer).notNull()
            .defaults(to: RappelDObjectif.minuteParDefaut)
    }

    try ObjectifPersiste().insert(base)
}

/// Ce qu une journee civile a compte.
struct JourneeDeLecturePersistee: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "journeeDeLecture"

    /// Debut du jour civil.
    var jour: Date

    /// Chapitres passes a l etat lu ce jour la.
    var chapitresLus: Int

    /// Pages nouvelles parcourues ce jour la.
    var pagesLues: Int

    /// Forme metier de la ligne.
    var journee: JourneeDeLecture {
        JourneeDeLecture(jour: jour, chapitresLus: chapitresLus, pagesLues: pagesLues)
    }
}

/// Objectif quotidien et rappel, ligne unique.
struct ObjectifPersiste: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "objectifDeLecture"

    /// Identifiant de la ligne unique.
    static let identifiantDeLaLigneUnique = 1

    var id: Int
    var chapitresParJour: Int?
    var rappelActif: Bool
    var heureDeRappel: Int
    var minuteDeRappel: Int

    init(
        id: Int = ObjectifPersiste.identifiantDeLaLigneUnique,
        chapitresParJour: Int? = nil,
        rappelActif: Bool = false,
        heureDeRappel: Int = RappelDObjectif.heureParDefaut,
        minuteDeRappel: Int = RappelDObjectif.minuteParDefaut
    ) {
        self.id = id
        self.chapitresParJour = chapitresParJour
        self.rappelActif = rappelActif
        self.heureDeRappel = heureDeRappel
        self.minuteDeRappel = minuteDeRappel
    }

    /// Objectif tel que la couche metier le lit.
    var objectif: ObjectifQuotidien {
        ObjectifQuotidien(chapitresParJour: chapitresParJour)
    }

    /// Rappel tel que la couche metier le lit.
    var rappel: RappelDObjectif {
        RappelDObjectif(actif: rappelActif, heure: heureDeRappel, minute: minuteDeRappel)
    }
}
