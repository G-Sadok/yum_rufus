import Core
import Foundation
import GRDB

//
// MagasinDImportDeSource
//
// Range dans la bibliotheque ce qu une source vient de rendre.
//
// C est le maillon qui manquait entre les sources et la bibliotheque : les
// douze sources savaient parcourir leur catalogue, les tables savaient tenir
// des series, et rien n allait des unes aux autres.
//
// L import est idempotent. Une serie deja connue est mise a jour au lieu d etre
// dupliquee, et un chapitre deja lu garde son etat : reanalyser un dossier ne
// doit jamais faire perdre la progression, qui est ce que l utilisateur a de
// plus precieux dans l application.
//
// L identite d une serie est le couple source et identifiant distant, jamais
// son titre. Un titre corrige a la source renommerait la serie, il ne la
// remplacerait pas.
//

/// Range en base ce qu une source rend.
public struct MagasinDImportDeSource: Sendable {
    private let base: BaseDeDonnees

    public init(base: BaseDeDonnees) {
        self.base = base
    }

    /// Ce qu un import a change.
    public struct Bilan: Sendable, Equatable {
        public let seriesAjoutees: Int
        public let seriesMisesAJour: Int
        public let chapitresAjoutes: Int

        public init(seriesAjoutees: Int, seriesMisesAJour: Int, chapitresAjoutes: Int) {
            self.seriesAjoutees = seriesAjoutees
            self.seriesMisesAJour = seriesMisesAJour
            self.chapitresAjoutes = chapitresAjoutes
        }
    }

    /// Identifiant interne d une serie, nul quand la base ne la connait pas.
    ///
    /// L identite est le couple source et identifiant distant, jamais le
    /// titre. Un ecran qui vient d importer une serie s en sert pour ouvrir sa
    /// fiche, qui ne connait que les identifiants internes.
    public func identifiant(deLaSerie distant: String, source: UUID) throws -> UUID? {
        try base.ecrivain.read { connexion in
            try Manga
                .filter(Column("sourceId") == source)
                .filter(Column("identifiantDistant") == distant)
                .fetchOne(connexion)?
                .id
        }
    }

    /// Range une serie et ses chapitres, en preservant ce qui est deja connu.
    ///
    /// - Parameters:
    ///   - serie: serie telle que la source la rend.
    ///   - chapitres: chapitres de cette serie.
    ///   - source: identifiant de la source qui les a rendus.
    /// - Returns: ce que l import a change.
    @discardableResult
    public func importer(
        _ serie: MangaDistant,
        chapitres: [ChapitreDistant],
        de source: UUID
    ) throws -> Bilan {
        try base.ecrivain.write { connexion in
            let existante = try Manga
                .filter(Column("sourceId") == source)
                .filter(Column("identifiantDistant") == serie.identifiant)
                .fetchOne(connexion)

            var rangee = existante ?? Manga(
                sourceId: source,
                identifiantDistant: serie.identifiant,
                titre: serie.titre
            )

            rangee.titre = serie.titre
            rangee.auteurs = serie.auteurs
            rangee.resume = serie.resume
            rangee.genres = serie.genres
            rangee.statut = serie.statut
            rangee.langue = serie.langue
            rangee.urlCouverture = serie.urlCouverture

            try rangee.save(connexion)

            var ajoutes = 0

            // L ordre suit celui que la source rend, qui est deja trie. Le
            // deduire du numero ferait remonter un chapitre 7.5 entre le 7 et
            // le 8, ce qui est juste, mais casserait les series dont les
            // numeros ne sont pas monotones.
            for (rang, chapitre) in chapitres.enumerated() {
                let deja = try Chapitre
                    .filter(Column("mangaId") == rangee.id)
                    .filter(Column("identifiantDistant") == chapitre.identifiant)
                    .fetchOne(connexion)

                // Un chapitre connu ne repasse pas par l ecriture. Le
                // sauvegarder rejouerait les declencheurs de non lus, qui
                // recompteraient un chapitre deja compte.
                guard deja == nil else { continue }

                var neuf = Chapitre(
                    mangaId: rangee.id,
                    identifiantDistant: chapitre.identifiant,
                    numero: chapitre.numero,
                    ordreDansSerie: rang
                )

                neuf.titre = chapitre.titre
                neuf.langue = chapitre.langue
                neuf.datePublication = chapitre.datePublication
                neuf.nombrePages = chapitre.nombrePages ?? 0

                try neuf.save(connexion)
                ajoutes += 1
            }

            return Bilan(
                seriesAjoutees: existante == nil ? 1 : 0,
                seriesMisesAJour: existante == nil ? 0 : 1,
                chapitresAjoutes: ajoutes
            )
        }
    }
}
