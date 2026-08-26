import Core
import Foundation

//
// CatalogueJellyfin
//
// Le parcours et la recherche du catalogue Jellyfin, separes de la source parce
// qu ils portent a eux seuls tout le filtrage sur le type de media livre.
//
// Deux points meritent d etre lus avant de toucher a ce fichier.
//
// Le premier est la racine. Jellyfin n a pas de catalogue unique : il a des
// bibliotheques, dont chacune annonce son type de collection. Une seule requete
// les rend toutes, et celles qui ne sont pas des bibliotheques de livres sont
// ecartees la, une fois pour toutes. Aucune requete d element ne part ensuite
// vers une bibliotheque de films, ce qui est a la fois le critere du tableau 4.2
// et la seule facon de ne pas payer un serveur entier pour trouver trois mangas.
//
// Le second est la pagination. Le protocole de la section 4.1 numerote ses
// pages, Jellyfin compte les elements sautes, et la source parcourt plusieurs
// bibliotheques a la suite comme si elles n en formaient qu une. Le decalage
// demande est donc consomme bibliotheque par bibliotheque : chacune en absorbe
// autant qu elle contient d elements, et la suivante repart de ce qui reste.
// Toutes sont interrogees a chaque tranche, meme quand la tranche est deja
// pleine, parce que le total qu elles annoncent est la seule facon de savoir
// s il reste une page. Les bibliotheques de livres d un serveur se comptent sur
// les doigts d une main, et ce cout se voit moins qu une derniere page perdue.
//

extension SourceJellyfin {
    /// Les identifiants des bibliotheques de livres, demandes une fois.
    ///
    /// - Throws: `ErreurReseau` telle que le client la leve. La traduction est
    ///   faite par l appelant, qui sait de quelle operation il s agit.
    func bibliothequesDeLivres() async throws -> [String] {
        if let bibliothequesEnCache {
            return bibliothequesEnCache
        }

        let tranche = try await client().lire(
            TrancheDeJellyfin.self,
            chemin: CheminsJellyfin.bibliotheques
        )
        let livres = tranche.bibliothequesDeLivres
        bibliothequesEnCache = livres

        return livres
    }

    /// Interroge les bibliotheques de livres et rend la tranche demandee.
    ///
    /// - Parameters:
    ///   - recherche: le texte cherche, ou nul pour le catalogue complet. Le
    ///     meme chemin sert aux deux : Jellyfin filtre sa liste sur un terme au
    ///     lieu d avoir un point d entree de recherche a part, et la pagination
    ///     y vaut donc pareillement.
    ///   - taille: nombre de series demandees. La verification de connexion en
    ///     demande une seule, sans quoi elle ramenerait cinquante fiches a
    ///     chaque ouverture de l ecran Parcourir, pour chaque serveur.
    func series(
        tri: TriDeJellyfin,
        recherche: String?,
        page: Int,
        taille: Int
    ) async throws -> PageResultats<MangaDistant> {
        do {
            let bibliotheques = try await bibliothequesDeLivres()
            let demandee = max(1, taille)
            var aSauter = max(0, page) * demandee
            var elements: [MangaDistant] = []
            var total = 0

            for bibliotheque in bibliotheques {
                try Task.checkCancellation()

                let tranche = try await tranche(
                    bibliotheque: bibliotheque,
                    tri: tri,
                    recherche: recherche,
                    depart: aSauter,
                    taille: demandee - elements.count
                )
                let compte = tranche.total ?? tranche.elements.count

                total += compte
                aSauter = max(0, aSauter - compte)
                elements.append(contentsOf: tranche.series(base: base).prefix(demandee - elements.count))
            }

            return PageResultats(
                elements: elements,
                page: max(0, page),
                ilResteDesPages: (max(0, page) + 1) * demandee < total
            )
        } catch {
            throw ErreurDeSource.depuis(error, source: nom)
        }
    }

    /// Une tranche de series dans une seule bibliotheque.
    ///
    /// Le type demande est le dossier, et non le livre : une serie est un
    /// dossier chez Jellyfin, et ses livres sont ses chapitres. Demander les
    /// livres ici rendrait un catalogue ou chaque chapitre serait une serie.
    private func tranche(
        bibliotheque: String,
        tri: TriDeJellyfin,
        recherche: String?,
        depart: Int,
        taille: Int
    ) async throws -> TrancheDeJellyfin {
        try await client().lire(
            TrancheDeJellyfin.self,
            chemin: CheminsJellyfin.elements,
            parametres: ParametresJellyfin.tranche(
                portee: .series(de: bibliotheque),
                tri: tri,
                pagination: PaginationJellyfin(depart: depart, taille: taille),
                recherche: recherche
            )
        )
    }
}
