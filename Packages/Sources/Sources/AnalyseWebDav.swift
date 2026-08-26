import Foundation

//
// AnalyseWebDav
//
// La lecture d une reponse `207 Multi-Status`, seul document que WebDAV renvoie
// pour decrire un dossier.
//
// L analyse passe par `XMLParser` comme celle des flux OPDS, et pour les memes
// raisons : l encodage se deduit de la declaration du document, les entites se
// resolvent, et une reponse tronquee laisse valables les elements deja fermes.
// Les noms d espaces restent desactives, et la comparaison porte sur le nom
// local : la moitie des serveurs WebDAV en service prefixent `D:`, l autre
// moitie `d:` ou `lp1:`, et aucun ne porte deux elements de meme nom local dans
// deux espaces differents.
//
// Deux pieges du format decident de la structure du collecteur.
//
// Le premier est le `propstat`. Une meme reponse peut en porter plusieurs, un
// par code de statut, et les proprietes d un `propstat` a 404 decrivent ce que
// le serveur ne sait pas plutot que ce qu il sait. Les retenir ferait passer une
// taille absente pour une taille nulle. Seul le bloc a 200 est lu.
//
// Le second est le `href`. Il est encode en pourcentage, il peut etre absolu ou
// relatif, et un dossier y porte une barre oblique finale que le nom de l entree
// ne doit pas garder. Les trois cas sont normalises ici, une fois, pour que le
// partage n ait plus qu un chemin relatif a manipuler.
//

/// Une entree decrite par une reponse `207 Multi-Status`.
struct ReponseWebDav: Sendable, Hashable {
    /// Chemin absolu sur le serveur, deja decode.
    let chemin: String

    let estDossier: Bool
    let taille: UInt64
    let dateModification: Date?
}

/// Lecture d un document `207 Multi-Status`.
enum AnalyseWebDav {
    /// Analyse les octets d une reponse multi statuts.
    ///
    /// - Returns: les entrees decrites, ou nul quand le document n en decrit
    ///   aucune, ce qui veut dire qu il n etait pas une reponse WebDAV.
    static func analyser(_ donnees: Data) -> [ReponseWebDav]? {
        guard donnees.isEmpty == false else {
            return nil
        }

        let collecteur = CollecteurWebDav()
        let analyseur = XMLParser(data: donnees)
        analyseur.delegate = collecteur

        // Le verdict est ignore volontairement : un document coupe en cours de
        // route laisse exploitables toutes les reponses deja fermees, et un
        // dossier ampute de sa fin vaut mieux qu un dossier vide.
        _ = analyseur.parse()

        let reponses = collecteur.reponses()

        return reponses.isEmpty ? nil : reponses
    }

    /// Normalise un `href` en chemin absolu decode, sans barre finale.
    static func chemin(de href: String) -> String {
        let brut = URL(string: href)?.path ?? href.removingPercentEncoding ?? href

        guard brut.count > 1 else {
            return brut
        }

        return brut.hasSuffix("/") ? String(brut.dropLast()) : brut
    }

    /// Lit une date au format impose par la norme HTTP.
    ///
    /// Le fuseau et la locale sont fixes : `getlastmodified` est toujours en GMT
    /// et en anglais, et laisser la locale de l appareil decider ferait echouer
    /// la lecture sur un appareil configure en francais.
    static func date(_ texte: String?) -> Date? {
        guard let texte = texte?.trimmingCharacters(in: .whitespacesAndNewlines), texte.isEmpty == false else {
            return nil
        }

        return formateur.date(from: texte)
    }

    private static let formateur: DateFormatter = {
        let formateur = DateFormatter()
        formateur.locale = Locale(identifier: "en_US_POSIX")
        formateur.timeZone = TimeZone(secondsFromGMT: 0)
        formateur.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"

        return formateur
    }()
}

///
/// Le collecteur est une classe parce que `XMLParserDelegate` l exige. Il ne
/// sort jamais de `analyser(_:)`, n est jamais partage entre taches, et n a donc
/// pas a etre `Sendable`.
///
private final class CollecteurWebDav: NSObject, XMLParserDelegate {
    /// Les elements dont le texte est retenu.
    private static let champsRetenus: Set<String> = [
        "href",
        "status",
        "getcontentlength",
        "getlastmodified",
    ]

    private var trouvees: [ReponseWebDav] = []

    private var href: String?
    private var statutDuBloc: String?
    private var estDossier = false
    private var taille: UInt64?
    private var date: Date?

    /// Ce que le bloc `propstat` en cours a lu, avant de savoir s il est a 200.
    private var dossierDuBloc = false
    private var tailleDuBloc: UInt64?
    private var dateDuBloc: Date?

    private var elementCourant: String?
    private var texteCourant = ""

    func reponses() -> [ReponseWebDav] {
        trouvees
    }

    func parser(
        _: XMLParser,
        didStartElement elementName: String,
        namespaceURI _: String?,
        qualifiedName _: String?,
        attributes _: [String: String]
    ) {
        switch Self.nomLocal(elementName) {
        case "response":
            commencerUneReponse()
        case "propstat":
            commencerUnBloc()
        case "collection":
            dossierDuBloc = true
        case let nom where Self.champsRetenus.contains(nom):
            elementCourant = nom
            texteCourant = ""
        default:
            break
        }
    }

    func parser(_: XMLParser, foundCharacters chaine: String) {
        guard elementCourant != nil else {
            return
        }

        texteCourant += chaine
    }

    func parser(_: XMLParser, foundCDATA donnees: Data) {
        guard elementCourant != nil, let texte = String(data: donnees, encoding: .utf8) else {
            return
        }

        texteCourant += texte
    }

    func parser(
        _: XMLParser,
        didEndElement elementName: String,
        namespaceURI _: String?,
        qualifiedName _: String?
    ) {
        let nom = Self.nomLocal(elementName)

        if nom == elementCourant {
            poser(nom, texteCourant.trimmingCharacters(in: .whitespacesAndNewlines))
            elementCourant = nil
            texteCourant = ""
        }

        switch nom {
        case "propstat":
            terminerUnBloc()
        case "response":
            terminerUneReponse()
        default:
            break
        }
    }

    // MARK: Assemblage

    private func commencerUneReponse() {
        href = nil
        estDossier = false
        taille = nil
        date = nil
        commencerUnBloc()
    }

    private func commencerUnBloc() {
        statutDuBloc = nil
        dossierDuBloc = false
        tailleDuBloc = nil
        dateDuBloc = nil
    }

    /// Retient ce que le bloc a lu, mais seulement s il annonce un succes.
    ///
    /// Un serveur qui ne connait pas `getcontentlength` sur un dossier le range
    /// dans un bloc a 404. Le lire ferait passer l absence pour une taille
    /// nulle, ce qui est vrai pour un dossier et faux pour un fichier.
    private func terminerUnBloc() {
        guard Self.estUnSucces(statutDuBloc) else {
            return
        }

        estDossier = estDossier || dossierDuBloc
        taille = tailleDuBloc ?? taille
        date = dateDuBloc ?? date
    }

    private func terminerUneReponse() {
        guard let href, href.isEmpty == false else {
            return
        }

        trouvees.append(
            ReponseWebDav(
                chemin: AnalyseWebDav.chemin(de: href),
                estDossier: estDossier,
                taille: estDossier ? 0 : (taille ?? 0),
                dateModification: date
            )
        )
    }

    private func poser(_ nom: String, _ texte: String) {
        switch nom {
        case "href":
            href = texte
        case "status":
            statutDuBloc = texte
        case "getcontentlength":
            tailleDuBloc = UInt64(texte)
        case "getlastmodified":
            dateDuBloc = AnalyseWebDav.date(texte)
        default:
            break
        }
    }

    /// Vrai quand la ligne de statut d un bloc annonce un succes.
    ///
    /// Un bloc sans ligne de statut est accepte : la norme l exige, mais des
    /// serveurs l omettent, et refuser leurs proprietes rendrait leurs dossiers
    /// vides plutot que de signaler leur ecart.
    private static func estUnSucces(_ statut: String?) -> Bool {
        guard let statut else {
            return true
        }

        return statut.contains(" 2")
    }

    /// Nom local d un element, prefixe de nom d espace retire.
    private static func nomLocal(_ nom: String) -> String {
        guard let separateur = nom.lastIndex(of: ":") else {
            return nom.lowercased()
        }

        return String(nom[nom.index(after: separateur)...]).lowercased()
    }
}
