import Core
import Foundation

//
// RequetesKomga
//
// Les chemins de l API et les parametres de requete de la source Komga.
//
// Ils vivent a part parce qu ils forment le vocabulaire du serveur, et non sa
// logique : c est la seule partie de la source qui change quand une version de
// Komga renomme un point d entree, et la reunir en un endroit rend ce
// changement lisible dans un diff.
//
// Rien ici n est prive : les membres sont lus depuis `SourceKomga.swift`, et le
// niveau prive est limite au fichier.
//

extension SourceKomga {
    // MARK: Parametres

    /// Les deux parametres de tranche, communs a toutes les listes.
    func parametresDePage(_ page: Int) -> [URLQueryItem] {
        [
            URLQueryItem(name: "page", value: String(max(0, page))),
            URLQueryItem(name: "size", value: String(tailleDePage)),
        ]
    }

    /// Le tri qui correspond a la section demandee.
    ///
    /// La section recentes trie sur la derniere modification et non sur la date
    /// d ajout : la section 4.1 la definit comme les series recemment ajoutees
    /// ou mises a jour, et un nouveau chapitre dans une vieille serie compte
    /// autant qu une serie neuve.
    static func parametresDeTri(_ section: SectionCatalogue) -> [URLQueryItem] {
        switch section {
        case .tout: [URLQueryItem(name: "sort", value: "metadata.titleSort,asc")]
        case .recentes: [URLQueryItem(name: "sort", value: "lastModified,desc")]
        case .populaires: []
        }
    }

    /// Les filtres traduits en parametres de requete.
    ///
    /// Un statut que Komga ne connait pas est omis plutot qu envoye : le
    /// serveur repondrait 400 sur un mot inconnu, et une requete refusee est un
    /// resultat plus deroutant qu un filtre sans effet.
    static func parametresDeFiltre(_ filtres: FiltresDeRecherche) -> [URLQueryItem] {
        var parametres = filtres.genres.compactMap { genre in
            genre.sansBlancs.map { URLQueryItem(name: "genre", value: $0) }
        }

        if let statut = filtres.statut?.motDeKomga {
            parametres.append(URLQueryItem(name: "status", value: statut))
        }

        return parametres
    }

    /// Les parametres qui demandent une tranche de livres, dans l ordre de
    /// numero.
    ///
    /// Le tri est demande explicitement plutot que laisse au serveur : l ordre
    /// par defaut d une liste de livres a change d une version de Komga a
    /// l autre, et une liste de chapitres melangee ne se remarque pas avant
    /// d avoir ouvert le mauvais.
    static func parametresDeLivres(page: Int) -> [URLQueryItem] {
        [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "size", value: String(tailleDePageDesLivres)),
            URLQueryItem(name: "sort", value: "metadata.numberSort,asc"),
        ]
    }

    // MARK: Chemins

    static let cheminDuCompte = "api/v1/users/me"
    static let cheminDesSeries = "api/v1/series"

    static func cheminDeSerie(_ identifiant: String) -> String {
        "api/v1/series/\(identifiant)"
    }

    static func cheminDesLivres(_ serie: String) -> String {
        "api/v1/series/\(serie)/books"
    }

    static func cheminDuLivre(_ livre: String) -> String {
        "api/v1/books/\(livre)"
    }

    static func cheminDesPages(_ livre: String) -> String {
        "api/v1/books/\(livre)/pages"
    }

    static func cheminDeProgression(_ livre: String) -> String {
        "api/v1/books/\(livre)/read-progress"
    }
}
