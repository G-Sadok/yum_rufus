import Core
import Foundation
import GRDB

//
// MagasinDeSensDeLecture
//
// Seul point d acces au sens de lecture persiste : reglage global d un cote,
// surcharge par serie de l autre, et resolution des deux au meme endroit.
//

/// Erreurs que la lecture ou l ecriture du sens de lecture peut remonter.
public enum ErreurDeSensDeLecture: Error, Sendable, Equatable {
    /// La serie visee n existe pas ou plus en base. L appelant doit revenir a
    /// la bibliotheque plutot que d afficher une serie avec un sens invente.
    case serieInconnue(identifiant: UUID)
}

/// Lit et ecrit le sens de lecture persiste.
///
/// Rien ici ne devine un sens : la valeur retournee vient toujours d une
/// colonne, celle de la serie quand elle est renseignee, celle du reglage
/// global sinon.
public struct MagasinDeSensDeLecture: Sendable {
    private let base: BaseDeDonnees

    public init(base: BaseDeDonnees) {
        self.base = base
    }

    /// Reglage global tel qu il est ecrit en base.
    public func reglageGlobal() throws -> ReglageDeSensDeLecture {
        try base.ecrivain.write { connexion in
            try Self.reglageGlobal(connexion)
        }
    }

    /// Sens de lecture applique aux series qui n en imposent aucun.
    public func sensGlobal() throws -> SensDeLecture {
        try reglageGlobal().sensGlobal
    }

    /// Remplace le sens de lecture global.
    public func definirLeSensGlobal(_ sens: SensDeLecture) throws {
        try base.ecrivain.write { connexion in
            var reglage = try Self.reglageGlobal(connexion)
            reglage.sensGlobal = sens
            try reglage.save(connexion)
        }
    }

    /// Sens impose par une serie, nul quand elle suit le reglage global.
    public func surcharge(pourSerie identifiant: UUID) throws -> SensDeLecture? {
        try base.ecrivain.read { connexion in
            try Self.surcharge(connexion, pourSerie: identifiant)
        }
    }

    /// Impose un sens de lecture a une serie, ou retire la surcharge quand la
    /// valeur passee est nulle.
    public func definirLaSurcharge(
        _ sens: SensDeLecture?,
        pourSerie identifiant: UUID
    ) throws {
        try base.ecrivain.write { connexion in
            let lignesTouchees = try Int.fetchOne(
                connexion,
                sql: """
                UPDATE manga SET sensLectureForce = ? WHERE id = ?
                RETURNING 1
                """,
                arguments: [sens, identifiant]
            )

            guard lignesTouchees != nil else {
                throw ErreurDeSensDeLecture.serieInconnue(identifiant: identifiant)
            }
        }
    }

    /// Sens de lecture applique a une serie, surcharge comprise.
    ///
    /// La surcharge de la serie et le reglage global sont lus dans la meme
    /// transaction : les deux valeurs sont donc toujours coherentes entre
    /// elles, meme si un reglage change pendant la lecture.
    public func sens(pourSerie identifiant: UUID) throws -> SensDeLecture {
        try base.ecrivain.write { connexion in
            guard try Manga.exists(connexion, key: identifiant) else {
                throw ErreurDeSensDeLecture.serieInconnue(identifiant: identifiant)
            }

            let reglage = try Self.reglageGlobal(connexion)
            let surcharge = try Self.surcharge(connexion, pourSerie: identifiant)

            return reglage.sens(surchargeDeSerie: surcharge)
        }
    }

    /// Reglage global, reinstalle a sa valeur par defaut s il a disparu.
    ///
    /// La migration ecrit cette ligne, donc son absence signale une base
    /// abimee. On la reecrit plutot que de retourner une valeur qui ne serait
    /// nulle part persistee, ce qui ferait diverger la vue de la base au
    /// prochain redemarrage.
    static func reglageGlobal(_ connexion: Database) throws -> ReglageDeSensDeLecture {
        let identifiant = ReglageDeSensDeLecture.identifiantDeLaLigneUnique

        if let reglage = try ReglageDeSensDeLecture.fetchOne(connexion, key: identifiant) {
            return reglage
        }

        let reglage = ReglageDeSensDeLecture()
        try reglage.insert(connexion)

        return reglage
    }

    private static func surcharge(
        _ connexion: Database,
        pourSerie identifiant: UUID
    ) throws -> SensDeLecture? {
        let ligne = try Row.fetchOne(
            connexion,
            sql: "SELECT sensLectureForce FROM manga WHERE id = ?",
            arguments: [identifiant]
        )

        guard let ligne else {
            return nil
        }

        return ligne["sensLectureForce"]
    }
}
