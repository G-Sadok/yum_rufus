import Core
import Foundation
import Sources

//
// TransportFigeDeSuivi
//
// Le serveur des tests de suivi. Il ne parle a rien, il rend ce qu on lui a dit
// de rendre, et il retient ce qu on lui a demande.
//
// Les deux moities comptent autant l une que l autre, comme pour le transport
// fige des sources. Figer les reponses couvre la lecture des quatre dialectes.
// Retenir les requetes couvre ce qui part : une progression publiee sur la
// bonne serie mais au mauvais chapitre passerait tous les tests d analyse du
// monde sans que rien ne s en apercoive, et une requete partie pendant une
// session incognito ne se voit que la.
//
// Il est recopie plutot que partage avec les tests des sources : deux cibles de
// test SwiftPM ne partagent pas de code, et exposer un double de test dans les
// sources livrees pour eviter une recopie couterait plus cher que la recopie.
//

/// Ce qu une requete demandait, sous une forme qui se compare.
struct RequeteObservee: Sendable {
    let methode: String
    let hote: String
    let chemin: String
    let parametres: [URLQueryItem]
    let entetes: [String: String]
    let corps: Data?

    init(_ requete: URLRequest) {
        methode = requete.httpMethod ?? "GET"

        let composants = requete.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
        hote = composants?.host ?? ""
        chemin = composants?.path ?? ""
        parametres = composants?.queryItems ?? []
        entetes = (requete.allHTTPHeaderFields ?? [:]).reduce(into: [:]) { table, entete in
            table[entete.key.lowercased()] = entete.value
        }
        corps = requete.httpBody
    }

    /// La premiere valeur portee par ce parametre, ou nul.
    func parametre(_ nom: String) -> String? {
        parametres.first { $0.name == nom }?.value
    }

    func entete(_ nom: String) -> String? {
        entetes[nom.lowercased()]
    }

    /// Hote et chemin joints, sans barre finale.
    ///
    /// C est sur cette forme que les regles comparent. La barre finale tombe
    /// parce qu une adresse dont le chemin est vide s ecrit avec ou sans elle
    /// selon la facon dont elle a ete assemblee, et qu une regle qui
    /// dependrait de ce detail se casserait sans que rien n ait change au
    /// service interroge.
    var adresse: String {
        let complet = hote + chemin

        guard complet.count > 1, complet.hasSuffix("/") else {
            return complet
        }

        return String(complet.dropLast())
    }

    /// Le corps relu comme du texte, ce que sont les formulaires et le JSON.
    ///
    /// Un corps qui n est pas de l UTF 8 rend la chaine vide plutot qu une
    /// suite de caracteres de remplacement : aucune requete du projet n en
    /// envoie, et une comparaison contre du texte remplace passerait au vert en
    /// comparant deux erreurs.
    var texteDuCorps: String {
        guard let corps, let texte = String(bytes: corps, encoding: .utf8) else {
            return ""
        }

        return texte
    }

    /// Le corps relu comme un objet JSON de valeurs simples.
    func corpsJson() -> [String: any Sendable]? {
        guard let corps else {
            return nil
        }

        return (try? JSONSerialization.jsonObject(with: corps)) as? [String: any Sendable]
    }
}

/// Ce que le transport doit rendre pour une methode et un chemin donnes.
struct RegleDeSuivi: Sendable {
    let methode: MethodeHttp
    let chemin: String
    let reponse: ReponseHttp

    /// Entetes que la requete doit porter pour que la regle s applique.
    ///
    /// C est ce qui permet de refuser un jeton perime et d accepter le suivant
    /// sur le meme chemin. Sans lui, le test de renouvellement prouverait
    /// seulement qu une requete a ete rejouee, pas qu elle l a ete avec un
    /// jeton neuf.
    let entetesAttendus: [String: String]

    /// Fragment que le corps de la requete doit contenir.
    ///
    /// Un des quatre services repond a toutes ses questions sur la meme
    /// adresse, avec le meme verbe : seul le corps dit ce qui est demande.
    /// Sans ce critere, sa regle de recherche servirait aussi sa question de
    /// compte, et le test passerait au vert en analysant la mauvaise reponse.
    let corpsContient: String?

    init(
        methode: MethodeHttp = .get,
        chemin: String,
        reponse: ReponseHttp,
        entetesAttendus: [String: String] = [:],
        corpsContient: String? = nil
    ) {
        self.methode = methode
        self.chemin = chemin
        self.reponse = reponse
        self.entetesAttendus = entetesAttendus
        self.corpsContient = corpsContient
    }

    func correspond(_ requete: RequeteObservee) -> Bool {
        // La comparaison porte sur l hote suivi du chemin, et non sur le seul
        // chemin. Un des quatre services repond a une adresse unique dont le
        // chemin est vide : le designer par son chemin le confondrait avec
        // n importe quelle autre requete, et le designer par son hote demande
        // que l hote entre dans la comparaison.
        guard requete.methode == methode.rawValue, requete.adresse.hasSuffix(chemin) else {
            return false
        }
        if let corpsContient, requete.texteDuCorps.contains(corpsContient) == false {
            return false
        }

        return entetesAttendus.allSatisfy { requete.entete($0.key) == $0.value }
    }

    /// Une reponse JSON acceptee, dont la longueur annoncee est la bonne.
    static func json(
        _ methode: MethodeHttp = .get,
        _ chemin: String,
        _ corps: String,
        code: Int = 200,
        entetesAttendus: [String: String] = [:],
        corpsContient: String? = nil
    ) -> RegleDeSuivi {
        let octets = Data(corps.utf8)

        return RegleDeSuivi(
            methode: methode,
            chemin: chemin,
            reponse: ReponseHttp(
                code: code,
                entetes: ["Content-Type": "application/json", "Content-Length": String(octets.count)],
                corps: octets
            ),
            entetesAttendus: entetesAttendus,
            corpsContient: corpsContient
        )
    }

    /// Un code de statut sec, sans corps utile.
    static func statut(
        _ methode: MethodeHttp = .get,
        _ chemin: String,
        _ code: Int,
        entetesAttendus: [String: String] = [:]
    ) -> RegleDeSuivi {
        RegleDeSuivi(
            methode: methode,
            chemin: chemin,
            reponse: ReponseHttp(code: code, corps: Data("{}".utf8)),
            entetesAttendus: entetesAttendus
        )
    }
}

/// Transport qui rend des reponses figees sans ouvrir de connexion.
actor TransportFigeDeSuivi: TransportHttp {
    private var regles: [RegleDeSuivi]
    private var observees: [RequeteObservee] = []

    init(_ regles: [RegleDeSuivi] = []) {
        self.regles = regles
    }

    /// Les requetes recues, dans l ordre.
    var journal: [RequeteObservee] {
        observees
    }

    /// La derniere requete recue.
    var derniere: RequeteObservee? {
        observees.last
    }

    /// Les requetes recues sur une adresse qui se termine ainsi.
    func requetes(vers chemin: String) -> [RequeteObservee] {
        observees.filter { $0.adresse.hasSuffix(chemin) }
    }

    /// Ajoute une regle devant les autres, pour surcharger un chemin deja servi.
    func prioriser(_ regle: RegleDeSuivi) {
        regles.insert(regle, at: 0)
    }

    func executer(_ requete: URLRequest) async throws -> ReponseHttp {
        let observee = RequeteObservee(requete)
        observees.append(observee)

        guard let regle = regles.first(where: { $0.correspond(observee) }) else {
            // Un chemin qu aucune regle ne sert est un chemin que le test n a
            // pas prevu. Le 404 le dit sans faire echouer le transport, ce qui
            // laisse le test constater l erreur plutot qu un plantage.
            return ReponseHttp(code: 404, corps: Data("{}".utf8))
        }

        return regle.reponse
    }
}
