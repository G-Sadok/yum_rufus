import Core
import Foundation
@testable import Sources

//
// ExtensionDeTest
//
// De quoi jouer une extension installee sans depot, sans reseau et sans cle de
// publication reelle, et de quoi observer ce que le transport a reellement
// laisse passer.
//
// Le transport espion retient l adresse complete de chaque requete, et non son
// seul chemin comme `TransportFige`. C est indispensable ici : tout ce que ces
// tests verifient porte sur l hote, et un espion qui ne le retiendrait pas ne
// pourrait pas distinguer une requete bloquee d une requete servie.
//

/// Transport qui retient les adresses demandees et rend des reponses figees.
actor TransportEspion: TransportHttp {
    /// Reponse a rendre pour une adresse dont le debut correspond.
    struct Regle: Sendable {
        let prefixe: String
        let reponse: ReponseHttp

        init(_ prefixe: String, _ reponse: ReponseHttp) {
            self.prefixe = prefixe
            self.reponse = reponse
        }

        /// Une redirection vers une autre adresse.
        static func redirection(de prefixe: String, vers destination: String, code: Int = 302) -> Regle {
            Regle(prefixe, ReponseHttp(code: code, entetes: ["Location": destination]))
        }

        /// Une reponse JSON acceptee.
        static func json(_ prefixe: String, _ corps: String) -> Regle {
            Regle(prefixe, ReponseHttp(code: 200, corps: Data(corps.utf8)))
        }
    }

    private let regles: [Regle]
    private let attente: Duration?
    private var demandees: [URL] = []

    init(_ regles: [Regle] = [], attente: Duration? = nil) {
        self.regles = regles
        self.attente = attente
    }

    /// Les adresses que le transport a reellement recues, dans l ordre.
    var adressesDemandees: [URL] {
        demandees
    }

    /// Les hotes que le transport a reellement joints, dans l ordre.
    var hotesJoints: [String] {
        demandees.compactMap { $0.host() }
    }

    func executer(_ requete: URLRequest) async throws -> ReponseHttp {
        if let adresse = requete.url {
            demandees.append(adresse)
        }
        if let attente {
            try await Task.sleep(for: attente)
        }

        let adresse = requete.url?.absoluteString ?? ""

        guard let regle = regles.first(where: { adresse.hasPrefix($0.prefixe) }) else {
            return ReponseHttp(code: 404, corps: Data("{}".utf8))
        }

        return regle.reponse
    }
}

/// Une liste blanche construite depuis des domaines ecrits en clair.
func listeBlancheDeTest(_ domaines: String...) throws -> ListeBlancheDeDomaines {
    try ListeBlancheDeDomaines(domaines: domaines.map(DomaineAutorise.init))
}

/// Une requete de lecture vers cette adresse.
func requeteDeTest(_ adresse: String) throws -> URLRequest {
    guard let url = URL(string: adresse) else {
        throw ErreurReseau.serveurIntrouvable
    }

    var requete = URLRequest(url: url)
    requete.httpMethod = MethodeHttp.get.rawValue
    requete.setValue("application/json", forHTTPHeaderField: "Accept")

    return requete
}
