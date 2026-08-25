import Core
import Foundation
import GRDB

//
// MagasinDeSources
//
// Seul point d acces aux sources persistees. Il existe pour deux raisons, et la
// seconde est la plus importante.
//
// La premiere est l ecran Parcourir, qui a besoin de relire ses sources dans
// l ordre choisi par l utilisateur.
//
// La seconde est la suppression. La base efface en cascade tout ce qui pend a
// une source, series, chapitres et pages, mais rien dans SQLite ne connait le
// trousseau du systeme. Le magasin conforme donc a `TraceDeSource`, ce qui le
// rend parcourable par `SuppressionDeSource` au meme titre que le trousseau :
// un seul appel efface la ligne et le mot de passe, et il devient impossible
// d effacer l une en oubliant l autre.
//
// Aucune fonction de ce fichier n ecrit un identifiant de connexion. Elle ne
// saurait pas comment : la colonne de configuration ne se remplit que par
// `Source.definirLaConfiguration(_:)`, dont le parametre est un type ferme sans
// champ secret.
//

/// Lit et ecrit les sources configurees.
public struct MagasinDeSources: Sendable {
    private let base: BaseDeDonnees

    public init(base: BaseDeDonnees) {
        self.base = base
    }

    // MARK: Lecture

    /// Les sources, dans l ordre de la liste de l ecran Parcourir.
    ///
    /// Le nom departage les sources de meme rang, pour qu une liste ou rien
    /// n a encore ete reordonne garde un ordre stable entre deux ouvertures.
    public func sources() throws -> [Source] {
        try base.ecrivain.read { connexion in
            try Source
                .order(Column("ordreAffichage"), Column("nom"))
                .fetchAll(connexion)
        }
    }

    public func source(_ identifiant: UUID) throws -> Source? {
        try base.ecrivain.read { connexion in
            try Source.fetchOne(connexion, key: identifiant)
        }
    }

    // MARK: Ecriture

    /// Ecrit une source, en remplacant celle qui portait deja cet identifiant.
    public func enregistrer(_ source: Source) throws {
        try base.ecrivain.write { connexion in
            try source.save(connexion)
        }
    }

    /// Efface une source et tout ce qui en depend.
    ///
    /// Les series, chapitres et pages partent en cascade, comme le declare le
    /// schema. Les identifiants de connexion, eux, ne partent pas d ici :
    /// passe par `SuppressionDeSource` pour purger aussi le trousseau.
    ///
    /// - Returns: vrai quand une ligne a ete effacee.
    @discardableResult
    public func supprimer(_ identifiant: UUID) throws -> Bool {
        try base.ecrivain.write { connexion in
            try Source.deleteOne(connexion, key: identifiant)
        }
    }
}

extension MagasinDeSources: TraceDeSource {
    public var nomDeLaTrace: String {
        "base"
    }

    public func effacer(_ source: SourceID) throws {
        try supprimer(source.brut)
    }
}
