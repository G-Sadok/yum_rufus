import Core
import Foundation
import GRDB

//
// MagasinDeCategories
//
// Seul point d acces aux categories persistees : la barre de la section 5.1 de
// DESIGN-SPEC.md, ses compteurs, et l appartenance d une serie a plusieurs
// categories a la fois.
//
// La categorie Tout n a pas de ligne. Aucune fonction de ce fichier ne peut la
// viser, ni pour la renommer, ni pour la supprimer, ni pour la deplacer : elle
// n a pas d identifiant a passer.
//

/// Lit et ecrit les categories de la bibliotheque.
public struct MagasinDeCategories: Sendable {
    private let base: BaseDeDonnees

    public init(base: BaseDeDonnees) {
        self.base = base
    }

    // MARK: Lecture

    /// Categories enregistrees, dans l ordre de la barre.
    public func categories() throws -> [Categorie] {
        try base.ecrivain.read { connexion in
            try Self.categories(connexion)
        }
    }

    /// Categories auxquelles une serie appartient, dans l ordre de la barre.
    public func categories(deLaSerie identifiant: UUID) throws -> [Categorie] {
        try base.ecrivain.read { connexion in
            let liaisons = try UUID.fetchAll(
                connexion,
                sql: "SELECT categorieId FROM mangaCategorie WHERE mangaId = ?",
                arguments: [identifiant]
            )

            let retenues = Set(liaisons)

            return try Self.categories(connexion).filter { retenues.contains($0.id) }
        }
    }

    /// Nombre de series par onglet, l onglet Tout compris.
    ///
    /// Une seule lecture pour toute la barre, et une seule agregation groupee
    /// pour toutes les categories. La grille, elle, ne compte jamais.
    public func compteurs() throws -> CompteursDeCategories {
        try base.ecrivain.read { connexion in
            let total = try Int.fetchOne(
                connexion,
                sql: "SELECT COUNT(*) FROM manga WHERE estDansBibliotheque = 1"
            ) ?? 0

            let lignes = try Row.fetchAll(connexion, sql: """
            SELECT mangaCategorie.categorieId AS categorieId, COUNT(*) AS nombre
            FROM mangaCategorie
            JOIN manga ON manga.id = mangaCategorie.mangaId
            WHERE manga.estDansBibliotheque = 1
            GROUP BY mangaCategorie.categorieId
            """)

            var parCategorie: [UUID: Int] = [:]

            for ligne in lignes {
                let identifiant: UUID = ligne["categorieId"]
                parCategorie[identifiant] = ligne["nombre"]
            }

            return CompteursDeCategories(total: total, parCategorie: parCategorie)
        }
    }

    /// Series affichees par la grille pour l onglet demande.
    ///
    /// L onglet Tout ne filtre rien, c est toute la bibliotheque.
    public func series(dans selection: SelectionDeCategorie) throws -> [MangaDeGrille] {
        try base.ecrivain.read { connexion in
            try MangaDeGrille.enBibliotheque(dans: selection).fetchAll(connexion)
        }
    }

    // MARK: Creation, renommage, suppression

    /// Cree une categorie et la pose en fin de barre.
    ///
    /// - Throws: `ErreurDeCategorie.nomVide` ou `.nomDejaPris`.
    @discardableResult
    public func creer(nom: String) throws -> Categorie {
        try base.ecrivain.write { connexion in
            let nettoye = try OrdreDesCategories.nomNettoye(nom)
            let existantes = try Self.categories(connexion)
            try OrdreDesCategories.verifierLaDisponibilite(de: nettoye, parmi: existantes)

            let categorie = Categorie(
                nom: nettoye,
                ordre: OrdreDesCategories.rangSuivant(apres: existantes)
            )
            try categorie.insert(connexion)

            return categorie
        }
    }

    /// Renomme une categorie sans toucher a son rang.
    @discardableResult
    public func renommer(_ identifiant: UUID, en nom: String) throws -> Categorie {
        try base.ecrivain.write { connexion in
            let nettoye = try OrdreDesCategories.nomNettoye(nom)
            let existantes = try Self.categories(connexion)

            guard var categorie = existantes.first(where: { $0.id == identifiant }) else {
                throw ErreurDeCategorie.categorieInconnue(identifiant: identifiant)
            }

            try OrdreDesCategories.verifierLaDisponibilite(
                de: nettoye,
                parmi: existantes,
                sauf: identifiant
            )

            categorie.nom = nettoye
            try categorie.update(connexion)

            return categorie
        }
    }

    /// Supprime une categorie et renumerote la barre.
    ///
    /// Les series ne sont pas touchees : la table de liaison est effacee en
    /// cascade, les series restent dans la bibliotheque et dans leurs autres
    /// categories.
    public func supprimer(_ identifiant: UUID) throws {
        try base.ecrivain.write { connexion in
            guard try Categorie.deleteOne(connexion, key: identifiant) else {
                throw ErreurDeCategorie.categorieInconnue(identifiant: identifiant)
            }

            try Self.ecrireLesRangs(connexion, OrdreDesCategories.renumeroter(Self.categories(connexion)))
        }
    }

    // MARK: Ordre

    /// Ecrit l ordre de la barre a partir de la suite d identifiants donnee.
    ///
    /// Une categorie absente de la suite est reportee a la fin, dans son ordre
    /// courant. Une barre partiellement decrite ne perd donc aucun onglet.
    @discardableResult
    public func reordonner(_ identifiants: [UUID]) throws -> [Categorie] {
        try base.ecrivain.write { connexion in
            let existantes = try Self.categories(connexion)

            if let inconnue = identifiants.first(where: { identifiant in
                !existantes.contains { $0.id == identifiant }
            }) {
                throw ErreurDeCategorie.categorieInconnue(identifiant: inconnue)
            }

            let demandees = identifiants.compactMap { identifiant in
                existantes.first { $0.id == identifiant }
            }
            let restantes = existantes.filter { categorie in
                !identifiants.contains(categorie.id)
            }

            let ordonnees = (demandees + restantes).enumerated().map { rang, categorie in
                var renumerotee = categorie
                renumerotee.ordre = rang
                return renumerotee
            }

            try Self.ecrireLesRangs(connexion, ordonnees)

            return ordonnees
        }
    }

    /// Deplace une categorie vers un autre rang de la barre.
    @discardableResult
    public func deplacer(_ identifiant: UUID, vers rang: Int) throws -> [Categorie] {
        try base.ecrivain.write { connexion in
            let existantes = try Self.categories(connexion)

            guard let depart = existantes.firstIndex(where: { $0.id == identifiant }) else {
                throw ErreurDeCategorie.categorieInconnue(identifiant: identifiant)
            }

            let ordonnees = OrdreDesCategories.deplacer(existantes, de: depart, vers: rang)
            try Self.ecrireLesRangs(connexion, ordonnees)

            return ordonnees
        }
    }

    // MARK: Appartenance

    /// Remplace les categories d une serie.
    ///
    /// Une serie peut appartenir a plusieurs categories, la liste passee est
    /// donc un ensemble et non un choix unique. Une liste vide retire la serie
    /// de toutes ses categories, elle reste dans la bibliotheque et donc dans
    /// l onglet Tout.
    public func definirLesCategories(_ identifiants: [UUID], pourSerie serie: UUID) throws {
        try base.ecrivain.write { connexion in
            try Self.verifierLaSerie(connexion, serie)

            let existantes = try Self.categories(connexion)
            let voulues = Set(identifiants)

            if let inconnue = voulues.first(where: { identifiant in
                !existantes.contains { $0.id == identifiant }
            }) {
                throw ErreurDeCategorie.categorieInconnue(identifiant: inconnue)
            }

            try connexion.execute(
                sql: "DELETE FROM mangaCategorie WHERE mangaId = ?",
                arguments: [serie]
            )

            for identifiant in voulues {
                try MangaCategorie(mangaId: serie, categorieId: identifiant).insert(connexion)
            }
        }
    }

    /// Ajoute une serie a une categorie, sans toucher aux autres.
    public func ajouter(_ serie: UUID, a categorie: UUID) throws {
        try base.ecrivain.write { connexion in
            try Self.verifierLaSerie(connexion, serie)
            try Self.verifierLaCategorie(connexion, categorie)

            // La liaison existe peut etre deja : une serie ajoutee deux fois a
            // la meme categorie n est pas une erreur, c est un geste repete.
            try connexion.execute(
                sql: "INSERT OR IGNORE INTO mangaCategorie (mangaId, categorieId) VALUES (?, ?)",
                arguments: [serie, categorie]
            )
        }
    }

    /// Retire une serie d une categorie, sans toucher aux autres.
    public func retirer(_ serie: UUID, de categorie: UUID) throws {
        try base.ecrivain.write { connexion in
            try connexion.execute(
                sql: "DELETE FROM mangaCategorie WHERE mangaId = ? AND categorieId = ?",
                arguments: [serie, categorie]
            )
        }
    }

    // MARK: Acces a la connexion

    private static func categories(_ connexion: Database) throws -> [Categorie] {
        try OrdreDesCategories.trier(Categorie.fetchAll(connexion))
    }

    private static func ecrireLesRangs(_ connexion: Database, _ categories: [Categorie]) throws {
        for categorie in categories {
            try connexion.execute(
                sql: "UPDATE categorie SET ordre = ? WHERE id = ?",
                arguments: [categorie.ordre, categorie.id]
            )
        }
    }

    private static func verifierLaSerie(_ connexion: Database, _ identifiant: UUID) throws {
        guard try Manga.exists(connexion, key: identifiant) else {
            throw ErreurDeCategorie.serieInconnue(identifiant: identifiant)
        }
    }

    private static func verifierLaCategorie(_ connexion: Database, _ identifiant: UUID) throws {
        guard try Categorie.exists(connexion, key: identifiant) else {
            throw ErreurDeCategorie.categorieInconnue(identifiant: identifiant)
        }
    }
}
