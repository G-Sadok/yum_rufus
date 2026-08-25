import Core
import Foundation
import GRDB
@testable import Storage

/// Petit jeu de donnees coherent, insere dans une base deja migree.
///
/// Il sert aux tests qui ont besoin d une serie reelle plutot que d un schema
/// vide : cascades de suppression, compteur de non lus, aller retour de
/// persistance.
enum JeuDeDonneesDeTest {
    /// Ce que l insertion a depose en base, pour que le test puisse s y
    /// referer sans le relire.
    struct Contenu {
        var source: Source
        var manga: Manga
        var chapitres: [Chapitre]
    }

    /// Insere une source, une serie et le nombre de chapitres demande.
    ///
    /// Les chapitres sont crees non lus, avec `pagesParChapitre` pages chacun,
    /// et numerotes de un a `nombreDeChapitres`. Les tests de seuil de lecture
    /// ont besoin de chapitres assez longs pour que quatre vingt quinze pour
    /// cent tombe ailleurs que sur la premiere page.
    @discardableResult
    static func inserer(
        dans base: BaseDeDonnees,
        nombreDeChapitres: Int,
        pagesParChapitre: Int = 1,
        titre: String = "Serie de test"
    ) throws -> Contenu {
        let source = Source(type: .fichiersLocaux, nom: "Dossier de test")
        let manga = Manga(
            sourceId: source.id,
            identifiantDistant: "serie-\(UUID().uuidString)",
            titre: titre,
            estDansBibliotheque: true
        )

        let chapitres = (0..<nombreDeChapitres).map { rang in
            Chapitre(
                mangaId: manga.id,
                identifiantDistant: "chapitre-\(rang)",
                numero: Double(rang + 1),
                nombrePages: pagesParChapitre,
                ordreDansSerie: rang
            )
        }

        try base.ecrivain.write { connexion in
            try source.insert(connexion)
            try manga.insert(connexion)

            for chapitre in chapitres {
                try chapitre.insert(connexion)

                for index in 0..<pagesParChapitre {
                    try Page(chapitreId: chapitre.id, index: index).insert(connexion)
                }
            }
        }

        return Contenu(source: source, manga: manga, chapitres: chapitres)
    }

    /// Lit le compteur denormalise de chapitres non lus d une serie.
    static func chapitresNonLus(de manga: UUID, dans base: BaseDeDonnees) throws -> Int? {
        try base.ecrivain.read { connexion in
            try Int.fetchOne(
                connexion,
                sql: "SELECT chapitresNonLus FROM manga WHERE id = ?",
                arguments: [manga]
            )
        }
    }
}
