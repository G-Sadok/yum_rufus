import Core
import Foundation
import GRDB

//
// MagasinDeDoublePage
//
// Seul point d acces au decalage de couverture persiste : reglage global d un
// cote, surcharge par serie de l autre, et resolution des deux au meme endroit.
//

/// Erreurs que la lecture ou l ecriture du decalage de couverture peut
/// remonter.
public enum ErreurDeDoublePage: Error, Sendable, Equatable {
    /// La serie visee n existe pas ou plus en base. L appelant doit revenir a
    /// la bibliotheque plutot que d afficher une serie avec un decalage
    /// invente.
    case serieInconnue(identifiant: UUID)
}

/// Lit et ecrit le decalage de couverture persiste.
///
/// Rien ici ne devine un decalage : la valeur retournee vient toujours d une
/// colonne, celle de la serie quand elle est renseignee, celle du reglage
/// global sinon.
public struct MagasinDeDoublePage: Sendable {
    private let base: BaseDeDonnees

    public init(base: BaseDeDonnees) {
        self.base = base
    }

    /// Reglage global tel qu il est ecrit en base.
    public func reglageGlobal() throws -> ReglageDeDoublePage {
        try base.ecrivain.write { connexion in
            try Self.reglageGlobal(connexion)
        }
    }

    /// Decalage applique aux series qui n en imposent aucun.
    public func decalageGlobal() throws -> DecalageDeCouverture {
        try reglageGlobal().decalageGlobal
    }

    /// Remplace le decalage de couverture global.
    public func definirLeDecalageGlobal(_ decalage: DecalageDeCouverture) throws {
        try base.ecrivain.write { connexion in
            var reglage = try Self.reglageGlobal(connexion)
            reglage.decalageGlobal = decalage
            try reglage.save(connexion)
        }
    }

    /// Decalage impose par une serie, nul quand elle suit le reglage global.
    public func surcharge(pourSerie identifiant: UUID) throws -> DecalageDeCouverture? {
        try base.ecrivain.read { connexion in
            try Self.surcharge(connexion, pourSerie: identifiant)
        }
    }

    /// Impose un decalage a une serie, ou retire la surcharge quand la valeur
    /// passee est nulle.
    public func definirLaSurcharge(
        _ decalage: DecalageDeCouverture?,
        pourSerie identifiant: UUID
    ) throws {
        try base.ecrivain.write { connexion in
            let lignesTouchees = try Int.fetchOne(
                connexion,
                sql: """
                UPDATE manga SET decalageDeCouvertureForce = ? WHERE id = ?
                RETURNING 1
                """,
                arguments: [decalage, identifiant]
            )

            guard lignesTouchees != nil else {
                throw ErreurDeDoublePage.serieInconnue(identifiant: identifiant)
            }
        }
    }

    /// Decalage applique a une serie, surcharge comprise.
    ///
    /// La surcharge de la serie et le reglage global sont lus dans la meme
    /// transaction : les deux valeurs sont donc toujours coherentes entre
    /// elles, meme si un reglage change pendant la lecture.
    public func decalage(pourSerie identifiant: UUID) throws -> DecalageDeCouverture {
        try base.ecrivain.write { connexion in
            guard try Manga.exists(connexion, key: identifiant) else {
                throw ErreurDeDoublePage.serieInconnue(identifiant: identifiant)
            }

            let reglage = try Self.reglageGlobal(connexion)
            let surcharge = try Self.surcharge(connexion, pourSerie: identifiant)

            return reglage.decalage(surchargeDeSerie: surcharge)
        }
    }

    /// Reglage global, reinstalle a sa valeur par defaut s il a disparu.
    ///
    /// La migration ecrit cette ligne, donc son absence signale une base
    /// abimee. On la reecrit plutot que de retourner une valeur qui ne serait
    /// nulle part persistee, ce qui ferait diverger la vue de la base au
    /// prochain redemarrage.
    private static func reglageGlobal(_ connexion: Database) throws -> ReglageDeDoublePage {
        let identifiant = ReglageDeDoublePage.identifiantDeLaLigneUnique

        if let reglage = try ReglageDeDoublePage.fetchOne(connexion, key: identifiant) {
            return reglage
        }

        let reglage = ReglageDeDoublePage()
        try reglage.insert(connexion)

        return reglage
    }

    private static func surcharge(
        _ connexion: Database,
        pourSerie identifiant: UUID
    ) throws -> DecalageDeCouverture? {
        let ligne = try Row.fetchOne(
            connexion,
            sql: "SELECT decalageDeCouvertureForce FROM manga WHERE id = ?",
            arguments: [identifiant]
        )

        guard let ligne else {
            return nil
        }

        return ligne["decalageDeCouvertureForce"]
    }
}
