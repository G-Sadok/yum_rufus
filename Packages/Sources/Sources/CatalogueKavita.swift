import Core
import Foundation

//
// CatalogueKavita
//
// Le parcours et la recherche du catalogue Kavita, separes de la source parce
// qu ils n empruntent pas le meme chemin sur le serveur.
//
// Le parcours passe par la liste paginee, la recherche par un point d entree
// dedie qui rend une enveloppe differente et ne pagine pas. Les reunir dans une
// seule fonction aurait demande un drapeau, et un drapeau aurait cache le fait
// que la pagination ne veut pas dire la meme chose des deux cotes.
//
// La pagination est le point delicat. Kavita ne la met pas dans le corps mais
// dans un entete, ce qui est la seule reponse du projet dont une partie utile
// arrive hors du corps, et ce qu un proxy inverse mal regle supprime sans le
// dire. Le repli sur le comptage des elements recus existe pour ce cas la, et
// il est volontairement optimiste : promettre une page de trop coute une requete
// vide, en promettre une de moins perd la moitie d un catalogue.
//

extension SourceKavita {
    /// Interroge le catalogue et traduit la tranche rendue.
    func series(tri: TriDeKavita, page: Int, taille: Int) async throws -> PageResultats<MangaDistant> {
        do {
            let charge = try JSONEncoder().encode(FiltreDeKavita(tri: tri))
            let lu = try await client().lireAvecReponse(
                [SerieDeKavita].self,
                chemin: CheminsKavita.toutesLesSeries,
                parametres: ParametresKavita.tranche(page: page, taille: taille),
                methode: .post,
                corpsJson: charge
            )
            let cleDApi = await session.cleDApi()

            return PageResultats(
                elements: lu.valeur.map { $0.mangaDistant(base: base, cleDApi: cleDApi) },
                page: page,
                ilResteDesPages: Self.ilResteDesPages(lu.reponse, recues: lu.valeur.count, taille: taille)
            )
        } catch {
            throw ErreurDeSource.depuis(error, source: nom)
        }
    }

    /// Interroge le point d entree de recherche.
    ///
    /// La recherche de Kavita n est pas paginee : elle rend une liste unique,
    /// deja bornee par le serveur. La premiere page porte donc tout, et les
    /// suivantes sont vides plutot que refusees, pour qu un defilement infini
    /// s arrete au lieu de lever au premier point d arret.
    func rechercher(texte: String, page: Int) async throws -> PageResultats<MangaDistant> {
        guard page == 0 else {
            return PageResultats(elements: [], page: page, ilResteDesPages: false)
        }

        do {
            let trouves = try await client().lire(
                ResultatsDeRechercheDeKavita.self,
                chemin: CheminsKavita.recherche,
                parametres: ParametresKavita.recherche(texte)
            )
            let cleDApi = await session.cleDApi()

            return PageResultats(
                elements: (trouves.series ?? []).map { $0.mangaDistant(base: base, cleDApi: cleDApi) },
                page: 0,
                ilResteDesPages: false
            )
        } catch {
            throw ErreurDeSource.depuis(error, source: nom)
        }
    }

    /// Vrai quand une page suivante existe.
    ///
    /// L entete de pagination du serveur fait autorite quand il est la. Sans
    /// lui, une tranche pleine laisse esperer une suite : c est le repli qui
    /// coute une requete vide quand le total tombe juste, plutot que de perdre
    /// la moitie d un catalogue derriere un proxy qui filtre les entetes.
    private static func ilResteDesPages(_ reponse: ReponseHttp, recues: Int, taille: Int) -> Bool {
        if let tranche = TrancheDeKavita(entete: reponse.entete("X-Pagination")) {
            return tranche.ilResteDesPages
        }

        return recues > 0 && recues >= taille
    }
}
