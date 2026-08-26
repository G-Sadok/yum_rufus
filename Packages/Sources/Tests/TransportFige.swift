import Core
import Foundation
@testable import Sources

//
// TransportFige
//
// Le serveur des tests. Il ne parle a rien, il rend ce qu on lui a dit de
// rendre, et il retient ce qu on lui a demande.
//
// Les deux moities comptent autant l une que l autre. Figer les reponses
// couvre l analyse, c est le troisieme critere de la fonctionnalite. Retenir
// les requetes couvre ce que la source demande : une progression publiee sur la
// bonne page mais au mauvais chapitre passerait tous les tests d analyse du
// monde sans que rien ne s en apercoive.
//

/// Ce qu une requete demandait, sous une forme qui se compare.
struct RequeteObservee: Sendable {
    let methode: String
    let chemin: String
    let parametres: [URLQueryItem]
    let entetes: [String: String]
    let corps: Data?

    init(_ requete: URLRequest) {
        methode = requete.httpMethod ?? "GET"

        let composants = requete.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
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

    /// Toutes les valeurs portees par ce parametre, dans l ordre d envoi.
    func valeurs(_ nom: String) -> [String] {
        parametres.filter { $0.name == nom }.compactMap(\.value)
    }

    func entete(_ nom: String) -> String? {
        entetes[nom.lowercased()]
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
struct RegleDeTransport: Sendable {
    let methode: MethodeHttp

    /// Fin du chemin demande. Le debut varie avec l adresse du serveur du test.
    let chemin: String

    let reponse: ReponseHttp

    /// Parametres que la requete doit porter pour que la regle s applique.
    ///
    /// C est ce qui permet de servir deux tranches differentes sur le meme
    /// chemin. Sans lui, une source qui demande la page suivante recevrait la
    /// premiere indefiniment, et le test de pagination passerait au vert en
    /// prouvant le contraire de ce qu il annonce.
    let parametresAttendus: [String: String]

    /// Entetes que la requete doit porter pour que la regle s applique.
    ///
    /// C est ce qui permet de refuser un jeton perime et d accepter le suivant
    /// sur le meme chemin. Sans lui, un serveur de test ne saurait pas
    /// distinguer les deux, et le test de rafraichissement prouverait seulement
    /// qu une requete a ete rejouee, pas qu elle l a ete avec un jeton neuf.
    let entetesAttendus: [String: String]

    /// Panne de transport a lever au lieu de rendre la reponse.
    let panne: ErreurReseau?

    init(
        methode: MethodeHttp,
        chemin: String,
        reponse: ReponseHttp,
        parametresAttendus: [String: String] = [:],
        entetesAttendus: [String: String] = [:],
        panne: ErreurReseau? = nil
    ) {
        self.methode = methode
        self.chemin = chemin
        self.reponse = reponse
        self.parametresAttendus = parametresAttendus
        self.entetesAttendus = entetesAttendus
        self.panne = panne
    }

    func correspond(_ requete: RequeteObservee) -> Bool {
        guard requete.methode == methode.rawValue, requete.chemin.hasSuffix(chemin) else {
            return false
        }
        guard parametresAttendus.allSatisfy({ requete.parametre($0.key) == $0.value }) else {
            return false
        }

        return entetesAttendus.allSatisfy { requete.entete($0.key) == $0.value }
    }

    /// La meme regle, restreinte aux requetes qui portent cet entete.
    func exigeant(entete nom: String, _ valeur: String) -> RegleDeTransport {
        RegleDeTransport(
            methode: methode,
            chemin: chemin,
            reponse: reponse,
            parametresAttendus: parametresAttendus,
            entetesAttendus: entetesAttendus.merging([nom: valeur]) { _, ajoute in ajoute },
            panne: panne
        )
    }

    // MARK: Fabriques

    /// Une reponse JSON acceptee, dont la longueur annoncee est la bonne.
    static func json(
        _ methode: MethodeHttp = .get,
        _ chemin: String,
        _ corps: String,
        code: Int = 200,
        quand parametres: [String: String] = [:],
        entetes: [String: String] = [:]
    ) -> RegleDeTransport {
        let octets = Data(corps.utf8)
        let communs = ["Content-Type": "application/json", "Content-Length": String(octets.count)]

        return RegleDeTransport(
            methode: methode,
            chemin: chemin,
            reponse: ReponseHttp(
                code: code,
                entetes: communs.merging(entetes) { _, ajoute in ajoute },
                corps: octets
            ),
            parametresAttendus: parametres
        )
    }

    /// Une reponse acceptee sans aucun corps, celle d une ecriture reussie.
    static func sansContenu(_ methode: MethodeHttp, _ chemin: String) -> RegleDeTransport {
        RegleDeTransport(methode: methode, chemin: chemin, reponse: ReponseHttp(code: 204))
    }

    /// Une reponse acceptee mais vide, la ou des donnees etaient attendues.
    static func vide(_ chemin: String) -> RegleDeTransport {
        RegleDeTransport(methode: .get, chemin: chemin, reponse: ReponseHttp(code: 200))
    }

    /// Une reponse dont le corps s arrete avant la longueur annoncee.
    static func tronquee(_ chemin: String, _ corps: String, annonce: Int) -> RegleDeTransport {
        RegleDeTransport(
            methode: .get,
            chemin: chemin,
            reponse: ReponseHttp(
                code: 200,
                entetes: ["Content-Length": String(annonce)],
                corps: Data(corps.utf8)
            )
        )
    }

    /// Un code de statut sec, sans corps utile.
    static func statut(
        _ chemin: String,
        _ code: Int,
        entetes: [String: String] = [:],
        methode: MethodeHttp = .get
    ) -> RegleDeTransport {
        RegleDeTransport(
            methode: methode,
            chemin: chemin,
            reponse: ReponseHttp(code: code, entetes: entetes, corps: Data("{}".utf8))
        )
    }

    /// Une panne de transport, avant meme qu un serveur reponde.
    static func panne(
        _ chemin: String,
        _ panne: ErreurReseau,
        methode: MethodeHttp = .get
    ) -> RegleDeTransport {
        RegleDeTransport(
            methode: methode,
            chemin: chemin,
            reponse: ReponseHttp(code: 0),
            panne: panne
        )
    }
}

/// Transport qui rend des reponses figees sans ouvrir de connexion.
actor TransportFige: TransportHttp {
    private var regles: [RegleDeTransport]
    private var observees: [RequeteObservee] = []

    init(_ regles: [RegleDeTransport] = []) {
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

    /// Ajoute une regle devant les autres, pour surcharger un chemin deja servi.
    func prioriser(_ regle: RegleDeTransport) {
        regles.insert(regle, at: 0)
    }

    func executer(_ requete: URLRequest) async throws -> ReponseHttp {
        let observee = RequeteObservee(requete)
        observees.append(observee)

        guard let regle = regles.first(where: { $0.correspond(observee) }) else {
            // Un chemin qu aucune regle ne sert est un chemin que le test n a
            // pas prevu. Le 404 le dit sans faire echouer le transport, ce qui
            // laisse le test constater l erreur de source plutot qu un plantage.
            return ReponseHttp(code: 404, corps: Data("{}".utf8))
        }
        if let panne = regle.panne {
            throw panne
        }

        return regle.reponse
    }
}
