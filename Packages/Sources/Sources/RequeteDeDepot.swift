import Core
import Foundation

//
// RequeteDeDepot
//
// La lecture d une requete HTTP entrante, et le cadrage qui dit quand elle est
// complete.
//
// Le reste du projet parle HTTP en client, par `TransportHttp`, ou le systeme
// se charge du cadrage. La reception Wi-Fi est le seul endroit ou nous sommes
// le serveur, et un serveur doit decider lui meme ou finit une requete. TCP ne
// rend pas des messages mais un flot d octets, exactement comme pour SMB : le
// navigateur peut envoyer les entetes dans un paquet et le corps dans dix
// autres, et un serveur qui repondrait des la premiere lecture repondrait a une
// requete tronquee.
//
// Le cadrage est ecrit ici, separe de l ecoute reelle, pour qu il se teste sans
// ouvrir de port. C est la meme couture que celle des partages reseau : le
// protocole se prouve sur des octets, le socket n a plus qu a les apporter.
//
// Deux limites sont posees, et les deux sont des refus de service potentiels
// s ils manquent. Une tete d entetes sans fin remplirait la memoire avant
// d avoir vu la premiere ligne vide. Un corps annonce a plusieurs gigaoctets
// ferait la meme chose plus lentement. Les deux sont donc plafonnees, et le
// depassement est un refus immediat, pas une attente.
//
// Le codage par morceaux n est pas lu. Aucun navigateur n envoie un formulaire
// de fichiers en `Transfer-Encoding: chunked`, tous annoncent une longueur, et
// accepter un cadrage que rien n exerce reviendrait a livrer du code jamais
// parcouru sur le chemin le plus expose de l application.
//

/// Une requete HTTP recue par la reception Wi-Fi.
struct RequeteDeDepot: Sendable, Equatable {
    /// Methode, en majuscules.
    let methode: String

    /// Chemin demande, sans la chaine de requete, decode.
    let chemin: String

    /// Entetes, noms ramenes en minuscules.
    let entetes: [String: String]

    /// Corps de la requete, vide quand elle n en porte pas.
    let corps: Data

    /// Valeur d un entete, quel que soit la casse du nom demande.
    func entete(_ nom: String) -> String? {
        entetes[nom.lowercased()]
    }

    /// Les biscuits presentes, par nom.
    var biscuits: [String: String] {
        guard let entete = entete("cookie") else {
            return [:]
        }

        var trouves: [String: String] = [:]

        for morceau in entete.split(separator: ";") {
            let paire = morceau.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)

            guard paire.count == 2 else {
                continue
            }

            let nom = paire[0].trimmingCharacters(in: .whitespaces)
            let valeur = paire[1].trimmingCharacters(in: .whitespaces)

            guard nom.isEmpty == false else {
                continue
            }

            trouves[nom] = valeur
        }

        return trouves
    }

    /// Type de contenu annonce, sans ses parametres.
    var typeDeContenu: String {
        guard let entete = entete("content-type"),
              let premier = entete.split(separator: ";").first
        else {
            return ""
        }

        return premier.trimmingCharacters(in: .whitespaces).lowercased()
    }

    /// Valeur d un parametre du type de contenu, `boundary` par exemple.
    func parametreDeContenu(_ nom: String) -> String? {
        guard let entete = entete("content-type") else {
            return nil
        }

        for morceau in entete.split(separator: ";").dropFirst() {
            let paire = morceau.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)

            guard paire.count == 2,
                  paire[0].trimmingCharacters(in: .whitespaces).lowercased() == nom.lowercased()
            else {
                continue
            }

            let valeur = paire[1].trimmingCharacters(in: .whitespaces)

            return valeur.hasPrefix("\"") && valeur.hasSuffix("\"") && valeur.count >= 2
                ? String(valeur.dropFirst().dropLast())
                : valeur
        }

        return nil
    }

    /// Lit une requete complete, entetes et corps compris.
    ///
    /// - Throws: `ErreurDeTransfert.requeteMalformee` quand la premiere ligne ou
    ///   un entete ne se lit pas.
    static func analyser(_ octets: Data) throws -> RequeteDeDepot {
        guard let separation = octets.range(of: Data(CadrageDeRequete.finDesEntetes.utf8)) else {
            throw ErreurDeTransfert.requeteMalformee
        }

        let tete = octets.subdata(in: octets.startIndex..<separation.lowerBound)

        guard let texte = String(data: tete, encoding: .utf8) else {
            throw ErreurDeTransfert.requeteMalformee
        }

        var lignes = texte.components(separatedBy: "\r\n")

        guard lignes.isEmpty == false else {
            throw ErreurDeTransfert.requeteMalformee
        }

        let premiere = lignes.removeFirst().split(separator: " ", omittingEmptySubsequences: true)

        guard premiere.count == 3, premiere[2].hasPrefix("HTTP/1.") else {
            throw ErreurDeTransfert.requeteMalformee
        }

        var entetes: [String: String] = [:]

        for ligne in lignes where ligne.isEmpty == false {
            let paire = ligne.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)

            guard paire.count == 2 else {
                throw ErreurDeTransfert.requeteMalformee
            }

            entetes[paire[0].trimmingCharacters(in: .whitespaces).lowercased()] =
                paire[1].trimmingCharacters(in: .whitespaces)
        }

        return RequeteDeDepot(
            methode: premiere[0].uppercased(),
            chemin: chemin(de: String(premiere[1])),
            entetes: entetes,
            corps: octets.subdata(in: separation.upperBound..<octets.endIndex)
        )
    }

    /// Le chemin d une cible de requete, sans chaine de requete ni fragment.
    ///
    /// Une cible absolue, `http://192.168.1.20:8080/depot`, est acceptee : un
    /// mandataire la reecrit ainsi, et la norme l autorise. Seul le chemin
    /// compte pour l acheminement.
    private static func chemin(de cible: String) -> String {
        var reste = Substring(cible)

        if let separation = reste.range(of: "://"), let barre = reste[separation.upperBound...].firstIndex(of: "/") {
            reste = reste[barre...]
        }
        if let interrogation = reste.firstIndex(of: "?") {
            reste = reste[reste.startIndex..<interrogation]
        }
        if let diese = reste.firstIndex(of: "#") {
            reste = reste[reste.startIndex..<diese]
        }

        let decode = String(reste).removingPercentEncoding ?? String(reste)

        return decode.isEmpty ? "/" : decode
    }
}

/// Accumule les octets d une connexion jusqu a tenir une requete entiere.
struct CadrageDeRequete {
    /// Ce qui separe les entetes du corps.
    static let finDesEntetes = "\r\n\r\n"

    /// Taille maximale de la tete d entetes.
    static let plafondDesEntetes = 16 * 1024

    private let plafondDuCorps: Int
    private var tampon = Data()

    init(plafondDuCorps: Int) {
        self.plafondDuCorps = plafondDuCorps
    }

    /// Ajoute ce qui vient d arriver, et rend les octets de la requete des
    /// qu elle est complete.
    ///
    /// Ce sont les octets et non la requete lue qui sortent d ici, parce que le
    /// transport ne connait pas HTTP : il porte des octets jusqu au serveur, qui
    /// est le seul a les interpreter. Le cadrage lit quand meme les entetes,
    /// puisqu il lui faut la longueur annoncee pour savoir ou finit la requete.
    ///
    /// - Throws: `ErreurDeTransfert.requeteMalformee` quand les entetes
    ///   depassent leur plafond ou ne se lisent pas, et
    ///   `ErreurDeTransfert.depotTropVolumineux` quand le corps annonce depasse
    ///   le plafond accepte.
    mutating func ajouter(_ octets: Data) throws -> Data? {
        tampon.append(octets)

        guard let separation = tampon.range(of: Data(Self.finDesEntetes.utf8)) else {
            guard tampon.count <= Self.plafondDesEntetes else {
                throw ErreurDeTransfert.requeteMalformee
            }

            return nil
        }

        let longueurDesEntetes = separation.upperBound - tampon.startIndex

        guard longueurDesEntetes <= Self.plafondDesEntetes else {
            throw ErreurDeTransfert.requeteMalformee
        }

        let requete = try RequeteDeDepot.analyser(tampon)
        let annoncee = requete.entete("content-length").flatMap(Int.init) ?? 0

        guard requete.entete("transfer-encoding") == nil else {
            throw ErreurDeTransfert.requeteMalformee
        }
        guard annoncee >= 0 else {
            throw ErreurDeTransfert.requeteMalformee
        }
        guard annoncee <= plafondDuCorps else {
            throw ErreurDeTransfert.depotTropVolumineux(plafondOctets: plafondDuCorps)
        }
        guard requete.corps.count >= annoncee else {
            return nil
        }

        // Ce qui suit le corps annonce appartient a une requete suivante, que la
        // reception ne servira pas : chaque connexion porte une requete et une
        // seule, entete `Connection: close` a l appui.
        let complete = tampon.subdata(in: tampon.startIndex..<(separation.upperBound + annoncee))

        tampon.removeAll(keepingCapacity: false)

        return complete
    }
}
