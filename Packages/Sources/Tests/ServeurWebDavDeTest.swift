import Core
import Foundation
@testable import Sources

//
// ServeurWebDavDeTest
//
// Un serveur WebDAV qui verifie lui meme l authentification qu on lui presente.
//
// C est ce qui rend le troisieme critere reellement prouve. Un transport fige
// qui rendrait 207 des qu un entete `Authorization` est present dirait seulement
// qu un entete a ete pose, pas qu il etait juste. Ce serveur la recalcule la
// reponse attendue a partir de la formule de la norme, avec sa propre
// implementation, et refuse quand elle ne correspond pas. Une erreur d ordre
// dans les termes haches, un compteur mal ecrit ou une adresse de requete mal
// formee se solderaient par une boucle de refus, donc par un test rouge.
//
// Il sert aussi les octets par plages, avec le meme plafond qu un vrai serveur
// derriere un proxy, pour que la lecture en flux soit exercee jusqu au bout de
// la chaine WebDAV et pas seulement contre un double de partage.
//

/// Ce qu un chemin porte sur le serveur de test.
enum NoeudWebDav: Sendable {
    case dossier
    case fichier(ContenuSimule)
}

/// Serveur WebDAV minimal, qui ne s ouvre sur aucun port.
actor ServeurWebDavDeTest: TransportHttp {
    /// Nombre maximal d octets rendus par reponse.
    static let plafondParReponse = 512 * 1024

    let compte: String
    let motDePasse: String
    let domaine: String
    let nonce: String
    let algorithme: AlgorithmeDigest

    /// Vrai quand le serveur n annonce que l authentification basique.
    let seulementBasique: Bool

    private var arbre: [String: NoeudWebDav]

    /// Les requetes recues, dans l ordre.
    private(set) var requetes: [RequeteObservee] = []

    /// Les valeurs de compteur presentees par les reponses Digest acceptees.
    private(set) var compteursAcceptes: [String] = []

    /// Nombre d octets reellement rendus par les lectures.
    private(set) var octetsServis: UInt64 = 0

    init(
        compte: String = "utilisateur",
        motDePasse: String = "mot de passe",
        domaine: String = "partage@exemple.test",
        nonce: String = "nonce-fige-du-serveur",
        algorithme: AlgorithmeDigest = .md5,
        seulementBasique: Bool = false,
        arbre: [String: NoeudWebDav] = [:]
    ) {
        self.compte = compte
        self.motDePasse = motDePasse
        self.domaine = domaine
        self.nonce = nonce
        self.algorithme = algorithme
        self.seulementBasique = seulementBasique
        self.arbre = arbre
    }

    func poser(_ chemin: String, _ noeud: NoeudWebDav) {
        arbre[chemin] = noeud
    }

    // MARK: Transport

    func executer(_ requete: URLRequest) async throws -> ReponseHttp {
        requetes.append(RequeteObservee(requete))

        guard let adresse = requete.url,
              let composants = URLComponents(url: adresse, resolvingAgainstBaseURL: false)
        else {
            return ReponseHttp(code: 400)
        }

        let methode = requete.httpMethod ?? "GET"
        let cible = composants.percentEncodedPath
        let chemin = composants.path

        guard verifier(requete.value(forHTTPHeaderField: "Authorization"), methode: methode, cible: cible) else {
            return ReponseHttp(code: 401, entetes: ["WWW-Authenticate": defi()])
        }
        guard let noeud = arbre[chemin] else {
            return ReponseHttp(code: 404)
        }

        switch methode {
        case "PROPFIND":
            return multiStatuts(chemin, noeud: noeud, profondeur: requete.value(forHTTPHeaderField: "Depth") ?? "1")
        case "HEAD":
            return entetesSeuls(noeud)
        case "GET":
            return octets(noeud, plage: requete.value(forHTTPHeaderField: "Range"))
        default:
            return ReponseHttp(code: 405)
        }
    }

    // MARK: Authentification

    /// Le defi que le serveur annonce a une requete anonyme.
    private func defi() -> String {
        guard seulementBasique == false else {
            return "Basic realm=\"\(domaine)\""
        }

        return "Digest realm=\"\(domaine)\", qop=\"auth\", algorithm=\(algorithme.nom), nonce=\"\(nonce)\""
    }

    /// Verifie la preuve presentee, en recalculant ce qui etait attendu.
    private func verifier(_ entete: String?, methode: String, cible: String) -> Bool {
        guard let entete else {
            return false
        }
        if entete.hasPrefix("Basic ") {
            let attendu = Data("\(compte):\(motDePasse)".utf8).base64EncodedString()

            return seulementBasique && entete == "Basic " + attendu
        }
        guard entete.hasPrefix("Digest "), seulementBasique == false else {
            return false
        }

        let champs = ParametresDEntete.lire(String(entete.dropFirst("Digest ".count)))

        guard champs["username"] == compte,
              champs["realm"] == domaine,
              champs["nonce"] == nonce,
              champs["uri"] == cible,
              let compteur = champs["nc"],
              let cnonce = champs["cnonce"],
              champs["qop"] == "auth",
              champs["response"] == attendue(methode: methode, cible: cible, compteur: compteur, cnonce: cnonce)
        else {
            return false
        }

        compteursAcceptes.append(compteur)

        return true
    }

    /// La reponse que la norme impose pour ces entrees.
    ///
    /// Le calcul est ecrit ici, a partir de la formule de la RFC 7616, et ne
    /// passe par aucune ligne du code teste.
    private func attendue(methode: String, cible: String, compteur: String, cnonce: String) -> String {
        func hacher(_ texte: String) -> String {
            algorithme == .md5 ? ReferenceDigest.hacherMd5(texte) : ReferenceDigest.hacherSha(texte)
        }

        let premier = hacher("\(compte):\(domaine):\(motDePasse)")
        let second = hacher("\(methode):\(cible)")

        return hacher("\(premier):\(nonce):\(compteur):\(cnonce):auth:\(second)")
    }

    // MARK: Reponses

    /// Le document `207 Multi-Status` decrivant un chemin et son contenu direct.
    private func multiStatuts(_ chemin: String, noeud: NoeudWebDav, profondeur: String) -> ReponseHttp {
        var corps = "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<D:multistatus xmlns:D=\"DAV:\">\n"
        corps += reponse(chemin, noeud: noeud)

        if profondeur != "0" {
            for cle in arbre.keys.sorted() where Self.parent(de: cle) == chemin {
                guard let enfant = arbre[cle] else {
                    continue
                }

                corps += reponse(cle, noeud: enfant)
            }
        }

        corps += "</D:multistatus>\n"

        return Self.xml(corps, code: 207)
    }

    /// Une entree du document multi statuts.
    ///
    /// Le `href` est encode en pourcentage, comme la norme l impose, ce qui fait
    /// exercer le decodage par le partage : les noms de tomes portent des
    /// espaces sur toutes les bibliotheques reelles.
    private func reponse(_ chemin: String, noeud: NoeudWebDav) -> String {
        let href = chemin.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? chemin

        switch noeud {
        case .dossier:
            return """
                <D:response><D:href>\(href)/</D:href><D:propstat>\
            <D:prop><D:resourcetype><D:collection/></D:resourcetype></D:prop>\
            <D:status>HTTP/1.1 200 OK</D:status></D:propstat>\
            <D:propstat><D:prop><D:getcontentlength/></D:prop>\
            <D:status>HTTP/1.1 404 Not Found</D:status></D:propstat></D:response>

            """
        case let .fichier(contenu):
            return """
                <D:response><D:href>\(href)</D:href><D:propstat>\
            <D:prop><D:resourcetype/><D:getcontentlength>\(contenu.taille)</D:getcontentlength>\
            <D:getlastmodified>Tue, 15 Nov 1994 12:45:26 GMT</D:getlastmodified></D:prop>\
            <D:status>HTTP/1.1 200 OK</D:status></D:propstat></D:response>

            """
        }
    }

    private func entetesSeuls(_ noeud: NoeudWebDav) -> ReponseHttp {
        guard case let .fichier(contenu) = noeud else {
            return ReponseHttp(code: 405)
        }

        return ReponseHttp(code: 200, entetes: ["Content-Length": String(contenu.taille)])
    }

    /// Les octets d une plage, bornes comme le ferait un proxy.
    private func octets(_ noeud: NoeudWebDav, plage: String?) -> ReponseHttp {
        guard case let .fichier(contenu) = noeud else {
            return ReponseHttp(code: 405)
        }
        guard let plage, let bornes = Self.bornes(de: plage) else {
            return ReponseHttp(code: 416)
        }

        let longueur = Int(min(bornes.fin - bornes.debut + 1, UInt64(Self.plafondParReponse)))
        let rendus = contenu.octets(a: bornes.debut, longueur: longueur)
        octetsServis += UInt64(rendus.count)

        return ReponseHttp(
            code: 206,
            entetes: ["Content-Length": String(rendus.count)],
            corps: rendus
        )
    }

    private static func xml(_ corps: String, code: Int) -> ReponseHttp {
        let octets = Data(corps.utf8)

        return ReponseHttp(
            code: code,
            entetes: ["Content-Type": "application/xml", "Content-Length": String(octets.count)],
            corps: octets
        )
    }

    /// Lit un en tete `Range` de la forme `bytes=debut-fin`.
    private static func bornes(de plage: String) -> (debut: UInt64, fin: UInt64)? {
        let valeurs = plage.replacingOccurrences(of: "bytes=", with: "").split(separator: "-")

        guard valeurs.count == 2, let debut = UInt64(valeurs[0]), let fin = UInt64(valeurs[1]), fin >= debut else {
            return nil
        }

        return (debut, fin)
    }

    /// Le dossier qui porte ce chemin absolu.
    private static func parent(de chemin: String) -> String {
        guard let separateur = chemin.lastIndex(of: "/") else {
            return ""
        }

        return String(chemin[chemin.startIndex..<separateur])
    }
}
