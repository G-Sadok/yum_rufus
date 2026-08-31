import Core
import Foundation
import GRDB

//
// MagasinDuStockage
//
// Ce que la base sait dire des fichiers que l inspecteur a peses.
//
// Le magasin ne mesure rien et ne supprime aucun fichier. Il nomme. Un dossier
// de telechargement s appelle par l identifiant du chapitre, un dossier de cache
// de conteneurs par l identifiant de sa source, et ces identifiants ne veulent
// rien dire a l ecran. La jointure qui les transforme en `Berserk  Chapitre 43`
// est le seul apport de la base a la gestion du stockage, et elle se fait en une
// requete par ecran plutot qu en une par ligne.
//
// Un nom que la base ne resout pas n est jamais jete. Il retombe dans le poste
// anonyme que `AssemblageDesPostes` compose, ce qui garde son poids visible et
// supprimable : un chapitre retire de la bibliotheque dont le dossier est reste
// est precisement le cas ou l utilisateur cherche a liberer de la place.
//

/// Nomme les postes du stockage et sert le nettoyage apres lecture.
public struct MagasinDuStockage: Sendable {
    private let base: BaseDeDonnees

    public init(base: BaseDeDonnees) {
        self.base = base
    }

    // MARK: Nommage

    /// Postes d une categorie, nommes par la bibliotheque.
    ///
    /// - Parameters:
    ///   - pesages: ce que l inspecteur a mesure sur le disque.
    ///   - categorie: categorie mesuree, qui decide de la table interrogee.
    public func postes(
        depuis pesages: [PesageSurDisque],
        de categorie: CategorieDeStockage
    ) throws -> [PosteDeStockage] {
        let nommage = try nommage(pour: categorie, noms: pesages.map(\.nom))

        return AssemblageDesPostes.postes(depuis: pesages) { nommage[$0] }
    }

    /// Contenu de chaque nom que la base sait resoudre.
    private func nommage(
        pour categorie: CategorieDeStockage,
        noms: [String]
    ) throws -> [String: ContenuDePoste] {
        let identifiants = noms.compactMap(UUID.init(uuidString:))

        guard identifiants.isEmpty == false else {
            return [:]
        }

        return switch categorie {
        case .chapitresTelecharges: try chapitres(identifiants)
        case .cacheDeChapitres: try sources(identifiants)
        case .cacheDImages: [:]
        }
    }

    /// Chapitres nommes par leur serie, indexes par identifiant textuel.
    private func chapitres(_ identifiants: [UUID]) throws -> [String: ContenuDePoste] {
        let lignes = try base.ecrivain.read { connexion in
            try Row.fetchAll(
                connexion,
                sql: """
                SELECT chapitre.id AS id,
                       chapitre.numero AS numero,
                       chapitre.estLu AS estLu,
                       manga.titre AS titreDeLaSerie
                FROM chapitre
                JOIN manga ON manga.id = chapitre.mangaId
                WHERE chapitre.id IN (\(marqueurs(identifiants.count)))
                """,
                arguments: StatementArguments(identifiants.map(\.databaseValue))
            )
        }

        return lignes.reduce(into: [:]) { table, ligne in
            let identifiant: UUID = ligne["id"]

            table[identifiant.uuidString] = .chapitre(
                ChapitreDeStockage(
                    chapitreId: identifiant,
                    titreDeLaSerie: ligne["titreDeLaSerie"],
                    numeroDeChapitre: ligne["numero"],
                    estLu: ligne["estLu"]
                )
            )
        }
    }

    /// Sources nommees, indexees par identifiant textuel.
    private func sources(_ identifiants: [UUID]) throws -> [String: ContenuDePoste] {
        let lignes = try base.ecrivain.read { connexion in
            try Row.fetchAll(
                connexion,
                sql: """
                SELECT id, nom
                FROM source
                WHERE id IN (\(marqueurs(identifiants.count)))
                """,
                arguments: StatementArguments(identifiants.map(\.databaseValue))
            )
        }

        return lignes.reduce(into: [:]) { table, ligne in
            let identifiant: UUID = ligne["id"]

            table[identifiant.uuidString] = .source(nom: ligne["nom"])
        }
    }

    /// Suite de marqueurs d une clause `IN`.
    private func marqueurs(_ nombre: Int) -> String {
        Array(repeating: "?", count: nombre).joined(separator: ", ")
    }

    // MARK: Suppression en base

    /// Retire de la file les taches posees sur ces chapitres.
    ///
    /// Le dossier du chapitre n est pas touche ici. Storage n ecrit rien sur le
    /// disque en dehors de la base, c est l inspecteur du paquet Sources qui
    /// efface, avec la confirmation que l ecran impose.
    ///
    /// - Returns: le nombre de taches retirees.
    @discardableResult
    public func retirerLesTaches(desChapitres chapitres: [UUID]) throws -> Int {
        guard chapitres.isEmpty == false else {
            return 0
        }

        return try base.ecrivain.write { connexion in
            try Telechargement
                .filter(chapitres.contains(Column("chapitreId")))
                .deleteAll(connexion)
        }
    }
}

// MARK: Journal du nettoyage

extension MagasinDuStockage: JournalDuStockage {
    /// Chapitres lus parmi ceux dont le telechargement est pose sur le disque.
    ///
    /// La date rendue est `dateLecture`, celle que le marquage au passage
    /// ecrit. Un chapitre marque lu sans date reste dans la liste avec une date
    /// nulle : c est la regle de decision, et non la requete, qui tranche ce
    /// qu un reglage a delai en fait.
    public func chapitresLus(parmi chapitres: [UUID]) async throws -> [TelechargementLu] {
        guard chapitres.isEmpty == false else {
            return []
        }

        return try lignesDesChapitresLus(parmi: chapitres).map { ligne in
            TelechargementLu(chapitreId: ligne["id"], dateLecture: ligne["dateLecture"])
        }
    }

    /// Lignes brutes des chapitres lus, lues dans une fonction synchrone.
    ///
    /// La lecture est sortie de la fonction asynchrone a dessein. GRDB expose
    /// `read` en version synchrone et en version asynchrone, et dans un
    /// contexte asynchrone le choix depend de la version du compilateur : le
    /// notre retient la synchrone, celui de l integration continue exige
    /// l attente, et le fichier ne compilait que d un cote. Ici la question ne
    /// se pose plus, comme pour `chapitres` et `sources` plus haut.
    private func lignesDesChapitresLus(parmi chapitres: [UUID]) throws -> [Row] {
        try base.ecrivain.read { connexion in
            try Row.fetchAll(
                connexion,
                sql: """
                SELECT id, dateLecture
                FROM chapitre
                WHERE estLu = 1 AND id IN (\(marqueurs(chapitres.count)))
                """,
                arguments: StatementArguments(chapitres.map(\.databaseValue))
            )
        }
    }

    public func oublierLesTelechargements(de chapitres: [UUID]) async throws {
        try retirerLesTaches(desChapitres: chapitres)
    }
}
