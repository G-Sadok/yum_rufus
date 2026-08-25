import Core
import GRDB

//
// EnregistrementsGRDB
//
// Les entites de la section 3.1 vivent dans Core et ne connaissent pas SQL.
// C est ici, et seulement ici, qu elles apprennent a se lire et a s ecrire.
// Core reste ainsi sans dependance, conformement a la section 2.3.
//
// Core et Storage appartiennent au meme paquet SwiftPM, la conformance n est
// donc pas retroactive au sens du compilateur et n a pas a etre annotee.
// Storage reste malgre tout le seul module a la declarer.
//

extension Source: TableRecord, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "source"
}

extension Manga: TableRecord, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "manga"
}

extension Chapitre: TableRecord, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "chapitre"
}

extension Page: TableRecord, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "page"
}

extension Categorie: TableRecord, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "categorie"
}

extension MangaCategorie: TableRecord, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "mangaCategorie"
}

extension OrdreDeLecture: TableRecord, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "ordreDeLecture"
}

extension OrdreDeLectureChapitre: TableRecord, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "ordreDeLectureChapitre"
}

extension EntreeHistorique: TableRecord, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "entreeHistorique"
}

extension Signet: TableRecord, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "signet"
}

extension Telechargement: TableRecord, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "telechargement"
}

extension PrereglageLecture: TableRecord, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "prereglageLecture"
}

extension LiaisonSuivi: TableRecord, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "liaisonSuivi"
}

extension ReglageDeSensDeLecture: TableRecord, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "reglageDeSensDeLecture"
}

// Les enumerations du domaine sont ecrites en base sous leur representation
// textuelle. La conformance permet de les utiliser directement dans un filtre
// de requete, sans passer par leur rawValue a chaque appel.
extension SensDeLecture: DatabaseValueConvertible {}
extension FiltreDeChapitres: DatabaseValueConvertible {}
extension CritereDeTriDeChapitres: DatabaseValueConvertible {}
extension OrdreDeTri: DatabaseValueConvertible {}
extension TypeDeSource: DatabaseValueConvertible {}
extension EtatConnexion: DatabaseValueConvertible {}
extension StatutSerie: DatabaseValueConvertible {}
extension EtatTelechargement: DatabaseValueConvertible {}
extension ServiceDeSuivi: DatabaseValueConvertible {}
extension StatutDeSuivi: DatabaseValueConvertible {}
