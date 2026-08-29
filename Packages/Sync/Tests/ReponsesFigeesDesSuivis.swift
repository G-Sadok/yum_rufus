import Core
import Foundation
import Sources

//
// ReponsesFigeesDesSuivis
//
// Une reponse par service, figee, plus les regles de transport qui les servent.
//
// Les corps sont ecrits a la main, reduits aux champs que les dialectes lisent.
// Ils ne sont pas captures depuis les vrais services : un enregistrement reel
// porterait des identifiants de compte et des titres d oeuvres sous droit, ce
// que la section 11 et les contraintes juridiques du projet interdisent de
// deposer ici.
//

/// Ce qu un service repond, par service.
enum ReponsesFigeesDesSuivis {
    /// Reponse du point d echange de jeton, forme de la norme OAuth 2.
    static let jetonOAuth = """
    {"access_token": "jeton-neuf", "refresh_token": "renouvellement", "expires_in": 3600}
    """

    /// Reponse du point de connexion par identifiants.
    static let jetonDeSession = """
    {"status": "success", "context": {"session_token": "jeton-de-session", "uid": 4242}}
    """

    // MARK: Comptes

    static let compteAniList = """
    {"data": {"Viewer": {"id": 501, "name": "lectrice"}}}
    """

    static let compteMyAnimeList = """
    {"id": 502, "name": "lectrice"}
    """

    static let compteKitsu = """
    {"data": [{"id": "503", "type": "users", "attributes": {"name": "lectrice"}}]}
    """

    static let compteMangaUpdates = """
    {"user_id": 504, "username": "lectrice"}
    """

    // MARK: Recherches

    static let rechercheAniList = """
    {"data": {"Page": {"media": [
      {"id": 11, "title": {"romaji": "Le Voyage du Heros", "english": "The Hero Journey", "native": null},
       "startDate": {"year": 2014}, "chapters": 120},
      {"id": 12, "title": {"romaji": "Le Voyage du Heros II", "english": null, "native": null},
       "startDate": {"year": 2019}, "chapters": 40}
    ]}}}
    """

    static let rechercheMyAnimeList = """
    {"data": [
      {"node": {"id": 21, "title": "Le Voyage du Heros",
                "alternative_titles": {"synonyms": ["Voyage du Heros"], "en": "The Hero Journey", "ja": null},
                "start_date": "2014-05-01", "num_chapters": 120}},
      {"node": {"id": 22, "title": "Chroniques du Sud", "start_date": "2001", "num_chapters": 60}}
    ]}
    """

    static let rechercheKitsu = """
    {"data": [
      {"id": "31", "type": "manga", "attributes": {"canonicalTitle": "Le Voyage du Heros",
        "titles": {"en": "The Hero Journey"}, "startDate": "2014-05-01", "chapterCount": 120}},
      {"id": "32", "type": "manga", "attributes": {"canonicalTitle": "Chroniques du Sud",
        "titles": {}, "startDate": "2001-01-01", "chapterCount": 60}}
    ]}
    """

    static let rechercheMangaUpdates = """
    {"total_hits": 2, "results": [
      {"record": {"series_id": 41, "title": "Le Voyage du Heros", "year": "2014"}},
      {"record": {"series_id": 42, "title": "Chroniques du Sud", "year": "2001"}}
    ]}
    """

    // MARK: Ecritures

    /// Entree de bibliotheque deja posee, pour le service qui en tient une.
    static let entreeKitsuExistante = """
    {"data": [{"id": "9001", "type": "libraryEntries"}]}
    """

    /// Aucune entree de bibliotheque posee.
    static let entreeKitsuAbsente = """
    {"data": []}
    """

    static let publicationAniList = """
    {"data": {"SaveMediaListEntry": {"id": 700, "progress": 12}}}
    """

    static let publicationVide = "{}"
}

/// Les regles de transport d un service, connexion et lecture comprises.
enum RegleDeService {
    /// Ce qu il faut servir pour qu un service se connecte et reponde.
    static func regles(pour service: ServiceDeSuivi) -> [RegleDeSuivi] {
        switch service {
        case .aniList:
            [
                .json(.post, "/oauth/token", ReponsesFigeesDesSuivis.jetonOAuth),
                .json(
                    .post,
                    "graphql.anilist.co",
                    ReponsesFigeesDesSuivis.compteAniList,
                    corpsContient: "Viewer"
                ),
            ]
        case .myAnimeList:
            [
                .json(.post, "/oauth2/token", ReponsesFigeesDesSuivis.jetonOAuth),
                .json(.get, "/users/@me", ReponsesFigeesDesSuivis.compteMyAnimeList),
            ]
        case .kitsu:
            [
                .json(.post, "/oauth/token", ReponsesFigeesDesSuivis.jetonOAuth),
                .json(.get, "/users", ReponsesFigeesDesSuivis.compteKitsu),
            ]
        case .mangaUpdates:
            [
                .json(.put, "/account/login", ReponsesFigeesDesSuivis.jetonDeSession),
                .json(.get, "/account/profile", ReponsesFigeesDesSuivis.compteMangaUpdates),
            ]
        }
    }

    /// Le corps d une recherche, service par service.
    static func recherche(pour service: ServiceDeSuivi) -> String {
        switch service {
        case .aniList: ReponsesFigeesDesSuivis.rechercheAniList
        case .myAnimeList: ReponsesFigeesDesSuivis.rechercheMyAnimeList
        case .kitsu: ReponsesFigeesDesSuivis.rechercheKitsu
        case .mangaUpdates: ReponsesFigeesDesSuivis.rechercheMangaUpdates
        }
    }
}
