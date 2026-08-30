import Core
import Foundation
@testable import Sources

//
// ReceptionDeTest
//
// Les doubles de la reception Wi-Fi : l ecoute qui n ouvre aucun port, et la
// reception qui n ecrit sur aucun disque.
//
// L ecoute simulee refuse de porter une requete quand elle n ecoute pas. C est
// ce qui rend le premier critere de la section 4.4 reellement verifiable : un
// double qui repondrait quand meme apres l arret prouverait seulement que le
// serveur dit non, alors que ce qui est promis est qu il n y a plus personne
// pour entendre.
//

/// Ce que l ecoute simulee leve quand plus personne n ecoute.
///
/// Une erreur a elle, et non celle d un des deux serveurs qui passent par cette
/// ecoute : ce que le double represente est un port ferme, pas un refus rendu
/// par une application. Un test qui attend cette erreur la prouve donc bien
/// qu il n y a plus personne, et non qu on lui a repondu non.
enum RienNEcoute: Error, Equatable {
    case portFerme
}

/// Ecoute qui n ouvre aucun port et transporte les requetes a la main.
actor EcouteSimulee: PointDEcoute {
    /// Port annonce a l ouverture.
    let portAnnonce: UInt16

    /// Vrai entre le demarrage et l arret.
    private(set) var enEcoute = false

    /// Nombre de demarrages et d arrets vus.
    private(set) var demarrages = 0
    private(set) var arrets = 0

    private var traitement: (@Sendable (Data, AdresseDuPair) async -> Data)?

    init(portAnnonce: UInt16 = ServeurDeTransfertWifi.portParDefaut) {
        self.portAnnonce = portAnnonce
    }

    func demarrer(_ traiter: @escaping @Sendable (Data, AdresseDuPair) async -> Data) async throws -> UInt16 {
        enEcoute = true
        demarrages += 1
        traitement = traiter

        return portAnnonce
    }

    func arreter() async {
        enEcoute = false
        arrets += 1
        traitement = nil
    }

    /// Porte une requete jusqu au serveur, comme le ferait la machine dont
    /// l adresse est donnee.
    ///
    /// L adresse par defaut est le bouclage, celle d une requete venue de cet
    /// appareil : la reception Wi-Fi ne la regarde pas, et les tests du pont
    /// qui veulent une machine du reseau la nomment.
    ///
    /// - Throws: `RienNEcoute.portFerme` quand plus rien n ecoute, ce qui est la
    ///   forme que prend un port ferme vu du reseau.
    func envoyer(_ octets: Data, depuis adresse: AdresseDuPair = .bouclageIPv4) async throws -> ReponseDeTest {
        guard enEcoute, let traitement else {
            throw RienNEcoute.portFerme
        }

        return try await ReponseDeTest.lire(traitement(octets, adresse))
    }
}

/// Reception qui garde ce qu on lui donne, sans rien ecrire.
actor ReceptionSimulee: ReceptionDeDepot {
    /// Ce qui a ete recu, dans l ordre.
    private(set) var recus: [(nom: String, octets: Int)] = []

    /// Nombre de fois ou la reception a ete conclue.
    private(set) var conclusions = 0

    /// Refus a lever au prochain appel, pour exercer le chemin d erreur.
    var refusAOpposer: ErreurDeTransfert?

    func recevoir(nomPropose: String, octets: Data) async throws -> String {
        if let refusAOpposer {
            throw refusAOpposer
        }

        recus.append((nom: nomPropose, octets: octets.count))

        return nomPropose
    }

    func conclure() async {
        conclusions += 1
    }

    func opposer(_ refus: ErreurDeTransfert?) {
        refusAOpposer = refus
    }
}

/// Une reponse HTTP relue depuis les octets rendus par le serveur.
struct ReponseDeTest {
    let code: Int
    let entetes: [String: String]
    let corps: String

    /// Valeur d un entete, quelle que soit la casse du nom demande.
    func entete(_ nom: String) -> String? {
        entetes[nom.lowercased()]
    }

    /// Vrai quand le corps porte ce fragment.
    func corpsContient(_ fragment: String) -> Bool {
        corps.contains(fragment)
    }

    /// Le jeton pose par un entete `Set-Cookie`, s il y en a un.
    var biscuitPose: String? {
        guard let entete = entete("set-cookie"),
              let premier = entete.split(separator: ";").first,
              let valeur = premier.split(separator: "=", maxSplits: 1).last
        else {
            return nil
        }

        return String(valeur)
    }

    static func lire(_ octets: Data) throws -> ReponseDeTest {
        guard let separation = octets.range(of: Data("\r\n\r\n".utf8)),
              let tete = String(data: octets.subdata(in: octets.startIndex..<separation.lowerBound), encoding: .utf8)
        else {
            throw ErreurDeTransfert.requeteMalformee
        }

        var lignes = tete.components(separatedBy: "\r\n")
        let premiere = lignes.removeFirst().split(separator: " ")

        guard premiere.count >= 2, let code = Int(premiere[1]) else {
            throw ErreurDeTransfert.requeteMalformee
        }

        var entetes: [String: String] = [:]

        for ligne in lignes where ligne.isEmpty == false {
            let paire = ligne.split(separator: ":", maxSplits: 1)

            guard paire.count == 2 else { continue }

            entetes[paire[0].trimmingCharacters(in: .whitespaces).lowercased()] =
                paire[1].trimmingCharacters(in: .whitespaces)
        }

        let corps = octets.subdata(in: separation.upperBound..<octets.endIndex)

        return ReponseDeTest(
            code: code,
            entetes: entetes,
            corps: String(data: corps, encoding: .utf8) ?? ""
        )
    }
}

/// Ecriture des requetes envoyees a la reception pendant les tests.
enum RequeteDeTest {
    /// Frontiere multipartie utilisee par les tests.
    static let frontiere = "----frontiere-de-test"

    /// Une requete GET.
    static func obtenir(_ chemin: String, biscuit: String? = nil) -> Data {
        var tete = "GET \(chemin) HTTP/1.1\r\nHost: 192.168.1.20:8080\r\n"

        if let biscuit {
            tete += "Cookie: \(ServeurDeTransfertWifi.nomDuBiscuit)=\(biscuit)\r\n"
        }

        return Data((tete + "\r\n").utf8)
    }

    /// Le formulaire de code.
    static func presenterLeCode(_ valeur: String) -> Data {
        let corps = "\(PageDeDepot.champDuCode)=\(valeur)"

        return Data(
            """
            POST \(CheminsDeLaReception.session) HTTP/1.1\r
            Host: 192.168.1.20:8080\r
            Content-Type: application/x-www-form-urlencoded\r
            Content-Length: \(corps.utf8.count)\r
            \r
            \(corps)
            """.utf8
        )
    }

    /// Le formulaire de fichiers.
    static func deposer(_ fichiers: [(nom: String, contenu: Data)], biscuit: String? = nil) -> Data {
        var corps = Data()

        for fichier in fichiers {
            corps.append(Data("--\(frontiere)\r\n".utf8))
            corps.append(
                Data(
                    "Content-Disposition: form-data; name=\"\(PageDeDepot.champDesFichiers)\";"
                        .appending(" filename=\"\(fichier.nom)\"\r\nContent-Type: application/octet-stream\r\n\r\n")
                        .utf8
                )
            )
            corps.append(fichier.contenu)
            corps.append(Data("\r\n".utf8))
        }

        corps.append(Data("--\(frontiere)--\r\n".utf8))

        var tete = "POST \(CheminsDeLaReception.depot) HTTP/1.1\r\nHost: 192.168.1.20:8080\r\n"
        tete += "Content-Type: multipart/form-data; boundary=\(frontiere)\r\n"
        tete += "Content-Length: \(corps.count)\r\n"

        if let biscuit {
            tete += "Cookie: \(ServeurDeTransfertWifi.nomDuBiscuit)=\(biscuit)\r\n"
        }

        var requete = Data((tete + "\r\n").utf8)
        requete.append(corps)

        return requete
    }
}
