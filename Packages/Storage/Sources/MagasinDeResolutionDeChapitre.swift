import Core
import Foundation
import GRDB

//
// MagasinDeResolutionDeChapitre
//
// Rend, pour un chapitre de la bibliotheque, de quoi le retrouver a sa source.
//
// La base garde un chapitre par son identifiant interne, et la source ne
// connait que l identifiant distant qu elle a elle meme rendu. Ouvrir un
// chapitre depuis une fiche demande donc de traverser ce pont, et c est la
// seule chose que fait ce magasin.
//
// Il ne resout pas le fichier lui meme. Ou vit un chapitre depend de la source,
// et seule la source le sait : un dossier local le pose sous sa racine, un
// serveur le sert par le reseau. Le magasin rend les identifiants, la source
// rend l emplacement.
//

/// De quoi retrouver un chapitre a sa source.
public struct AdresseDeChapitre: Sendable, Equatable {
    /// Source qui a rendu ce chapitre.
    public let source: UUID

    /// Identifiant de la serie chez cette source.
    public let serie: String

    /// Identifiant du chapitre chez cette source.
    public let chapitre: String

    /// Identifiant interne de la serie, celui que la base emploie.
    ///
    /// Il voyage a cote de l identifiant distant parce que le sens de lecture
    /// est range par serie interne, et qu ouvrir un chapitre dans le mauvais
    /// sens est la faute que la section 13 nomme en premier.
    public let serieInterne: UUID

    public init(source: UUID, serie: String, chapitre: String, serieInterne: UUID) {
        self.source = source
        self.serie = serie
        self.chapitre = chapitre
        self.serieInterne = serieInterne
    }
}

/// Traduit un chapitre de la base en adresse a sa source.
public struct MagasinDeResolutionDeChapitre: Sendable {
    private let base: BaseDeDonnees

    public init(base: BaseDeDonnees) {
        self.base = base
    }

    /// Adresse d un chapitre, nulle quand la base ne le connait pas.
    ///
    /// Rend nul aussi quand la serie du chapitre n a pas de source, ce qui
    /// n arrive que sur une base incoherente. Lever ici obligerait chaque
    /// appelant a traiter un cas qui ne devrait pas exister.
    public func adresse(deChapitre identifiant: UUID) throws -> AdresseDeChapitre? {
        try base.ecrivain.read { connexion in
            guard let chapitre = try Chapitre.fetchOne(connexion, key: identifiant),
                  let serie = try Manga.fetchOne(connexion, key: chapitre.mangaId)
            else {
                return nil
            }

            return AdresseDeChapitre(
                source: serie.sourceId,
                serie: serie.identifiantDistant,
                chapitre: chapitre.identifiantDistant,
                serieInterne: serie.id
            )
        }
    }

    /// Adresse du premier chapitre d une serie, nulle quand elle n en a pas.
    ///
    /// C est ce qui sert de couverture aux series qui n en ont pas : un dossier
    /// local ne publie pas d image de couverture, et la premiere page du
    /// premier chapitre est la seule que la serie possede a coup sur.
    ///
    /// Le tri suit `ordreDansSerie` et jamais le numero. Un numero peut etre
    /// absent, duplique ou incoherent selon la source, le rang non.
    public func adresseDuPremierChapitre(deLaSerie identifiant: UUID) throws -> AdresseDeChapitre? {
        try base.ecrivain.read { connexion in
            guard let serie = try Manga.fetchOne(connexion, key: identifiant),
                  let chapitre = try Chapitre
                  .filter(Column("mangaId") == identifiant)
                  .order(Column("ordreDansSerie"))
                  .fetchOne(connexion)
            else {
                return nil
            }

            return AdresseDeChapitre(
                source: serie.sourceId,
                serie: serie.identifiantDistant,
                chapitre: chapitre.identifiantDistant,
                serieInterne: serie.id
            )
        }
    }
}
