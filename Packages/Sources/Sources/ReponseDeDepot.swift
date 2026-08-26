import Core
import Foundation

//
// ReponseDeDepot
//
// Ce que la reception Wi-Fi renvoie au navigateur, et la facon dont elle
// l ecrit sur le fil.
//
// Quatre entetes sont poses sur toutes les reponses, et aucun n est decoratif.
//
// `Connection: close` parce que la reception ne garde aucune connexion vivante
// entre deux requetes : une connexion persistante obligerait a suivre un etat
// par fil, alors que la feuille peut se fermer a tout instant et que la
// promesse est justement que rien ne survit a sa fermeture.
//
// `Content-Length` parce que sans elle un navigateur attend la fermeture pour
// savoir qu il a tout recu, ce qui fait paraitre lente une page instantanee.
//
// `Cache-Control: no-store` parce que la page de depot porte le nom des
// fichiers deposes et le formulaire de code. Un cache de navigateur qui la
// garde la ressort apres la fin de la reception, sur une machine qui n est pas
// forcement celle de l utilisateur.
//
// `X-Content-Type-Options: nosniff` parce que le nom des fichiers deposes est
// reaffiche dans la page. L echappement du nom est fait a l ecriture, mais un
// navigateur qui devine le type malgre l annonce peut reinterpreter une reponse
// texte comme du HTML, et l echappement ne protege alors plus de rien.
//

/// Une reponse HTTP servie par la reception Wi-Fi.
struct ReponseDeDepot: Sendable, Equatable {
    /// Code de statut.
    let code: Int

    /// Entetes propres a cette reponse, sans ceux poses pour toutes.
    let entetes: [String: String]

    /// Corps servi, deja encode.
    let corps: Data

    init(code: Int, entetes: [String: String] = [:], corps: Data = Data()) {
        self.code = code
        self.entetes = entetes
        self.corps = corps
    }

    /// Une page HTML.
    static func page(_ html: String, code: Int = 200, entetes: [String: String] = [:]) -> ReponseDeDepot {
        var complets = entetes
        complets["Content-Type"] = "text/html; charset=utf-8"

        return ReponseDeDepot(code: code, entetes: complets, corps: Data(html.utf8))
    }

    /// Une redirection qui fait recharger la page par une requete GET.
    ///
    /// Le code 303 et non 302 : apres un depot en POST, un 302 laisse certains
    /// navigateurs rejouer le POST, donc redeposer les fichiers, au rechargement
    /// de la page.
    static func redirection(vers cible: String, entetes: [String: String] = [:]) -> ReponseDeDepot {
        var complets = entetes
        complets["Location"] = cible

        return ReponseDeDepot(code: 303, entetes: complets)
    }

    /// Les octets a ecrire sur la connexion.
    var octets: Data {
        var tete = "HTTP/1.1 \(code) \(Self.raison(code))\r\n"

        var complets = entetes
        complets["Content-Length"] = String(corps.count)
        complets["Connection"] = "close"
        complets["Cache-Control"] = "no-store"
        complets["X-Content-Type-Options"] = "nosniff"

        for nom in complets.keys.sorted() {
            guard let valeur = complets[nom] else {
                continue
            }

            tete += "\(nom): \(valeur)\r\n"
        }

        tete += "\r\n"

        var sortie = Data(tete.utf8)
        sortie.append(corps)

        return sortie
    }

    /// Les raisons de la norme, par code servi.
    ///
    /// Une table et non une suite de cas : la correspondance entre un code et sa
    /// raison est une donnee, pas une decision, et une donnee ecrite en branches
    /// se compte comme une complexite de code alors qu elle n en est pas une.
    private static let raisons: [Int: String] = [
        200: "OK",
        201: "Created",
        303: "See Other",
        400: "Bad Request",
        401: "Unauthorized",
        404: "Not Found",
        405: "Method Not Allowed",
        413: "Payload Too Large",
        415: "Unsupported Media Type",
        423: "Locked",
        500: "Internal Server Error",
        503: "Service Unavailable",
    ]

    /// La raison qui accompagne le code de statut.
    private static func raison(_ code: Int) -> String {
        raisons[code] ?? "Status"
    }
}

extension ErreurDeTransfert {
    /// Code de statut qui correspond a ce refus.
    ///
    /// La correspondance vit ici et non dans Core : le domaine n a pas a
    /// connaitre HTTP, et la reception Wi-Fi est le seul endroit du projet ou
    /// ces erreurs deviennent des reponses.
    var codeHttp: Int {
        switch self {
        case .receptionFermee: 503
        case .codeRefuse: 401
        case .tropDEssais: 423
        case .nomDeFichierRefuse, .requeteMalformee: 400
        case .formatNonRecevable: 415
        case .depotTropVolumineux: 413
        case .ecritureImpossible: 500
        }
    }
}
