import Core
import Darwin
import Foundation

//
// SessionDeTransfertWifi
//
// La duree de vie de la reception Wi-Fi, c est a dire la duree de la feuille.
//
// La section 4.4 ne demande pas seulement un serveur, elle demande un serveur
// qui n existe pas en dehors d une feuille ouverte. Cette promesse ne peut pas
// tenir dans une vue : une vue peut disparaitre sans prevenir, etre remplacee,
// ou lever une erreur au milieu de sa presentation, et l ecoute resterait alors
// ouverte sur le reseau jusqu a la fin du processus.
//
// La promesse tient donc ici, en trois points.
//
// Une session ne sert qu une fois. Ouverte puis fermee, elle refuse de se
// rouvrir : rouvrir la feuille fabrique une session neuve, donc un code neuf.
// Un code qui survivrait a la fermeture serait un code affiche une fois et
// valable indefiniment.
//
// La fermeture arrete l ecoute avant de fermer le serveur, et non l inverse.
// Fermer le serveur d abord laisserait un port ouvert repondre 503 a des
// requetes pendant le temps de l arret, ce qui annonce au reseau qu il y a bien
// quelque chose ici.
//
// `pendantLaFeuille` est la forme a preferer partout ou c est possible. Le
// corps recoit une session deja ouverte, et la fermeture est ecrite une fois,
// sur les deux sorties : la normale et celle par erreur, annulation comprise.
//

/// Une reception Wi-Fi, vivante le temps d une feuille.
public actor SessionDeTransfertWifi {
    /// Etat de la session, qui ne recule jamais.
    private enum Etat: Equatable {
        case neuve
        case ouverte(port: UInt16)
        case fermee
    }

    /// Le code a six chiffres a afficher sur l appareil.
    ///
    /// Il est tire a la construction et ne change plus : l afficher puis le
    /// changer ferait echouer une saisie deja commencee.
    public nonisolated let code: CodeDeTransfert

    private let serveur: ServeurDeTransfertWifi
    private let ecoute: any PointDEcoute

    private var etat: Etat = .neuve

    public init(
        reception: any ReceptionDeDepot,
        ecoute: any PointDEcoute = EcouteHttpLocale(),
        code: CodeDeTransfert = CodeDeTransfert.tire(),
        libelles: LibellesDeLaPageDeDepot = LibellesDeLaPageDeDepot()
    ) {
        self.code = code
        self.ecoute = ecoute
        serveur = ServeurDeTransfertWifi(code: code, reception: reception, libelles: libelles)
    }

    /// Port ouvert, ou nul tant que la feuille n a rien ouvert.
    public var port: UInt16? {
        guard case let .ouverte(port) = etat else {
            return nil
        }

        return port
    }

    /// Vrai tant que l ecoute tourne.
    public var estOuverte: Bool {
        port != nil
    }

    /// Adresse a afficher sur l appareil, ou nul si aucune adresse locale n est
    /// joignable.
    public var adresse: String? {
        guard let port else {
            return nil
        }

        return AdresseDeReception.adresse(pour: port)
    }

    /// Ouvre l ecoute et rend le port obtenu.
    ///
    /// - Throws: `ErreurDeTransfert.receptionFermee` quand la session a deja
    ///   servi, et `ErreurReseau` quand le port ne peut pas etre pris.
    @discardableResult
    public func ouvrir() async throws -> UInt16 {
        switch etat {
        case let .ouverte(port):
            return port
        case .fermee:
            throw ErreurDeTransfert.receptionFermee
        case .neuve:
            break
        }

        let serveur = serveur
        let obtenu = try await ecoute.demarrer { octets in
            await serveur.repondre(auxOctets: octets)
        }

        etat = .ouverte(port: obtenu)

        return obtenu
    }

    /// Ferme l ecoute et le serveur, definitivement.
    public func fermer() async {
        guard etat != .fermee else {
            return
        }

        etat = .fermee

        await ecoute.arreter()
        await serveur.fermer()
    }

    /// Ouvre une reception, la confie au corps, et la referme quoi qu il arrive.
    ///
    /// C est la forme qui tient la promesse de la section 4.4 sans rien demander
    /// a l appelant : le corps peut lever, etre annule, ou sortir normalement,
    /// l ecoute est fermee dans les trois cas.
    public static func pendantLaFeuille<T: Sendable>(
        reception: any ReceptionDeDepot,
        ecoute: any PointDEcoute = EcouteHttpLocale(),
        code: CodeDeTransfert = CodeDeTransfert.tire(),
        libelles: LibellesDeLaPageDeDepot = LibellesDeLaPageDeDepot(),
        _ corps: (SessionDeTransfertWifi) async throws -> T
    ) async throws -> T {
        let session = SessionDeTransfertWifi(
            reception: reception,
            ecoute: ecoute,
            code: code,
            libelles: libelles
        )

        do {
            try await session.ouvrir()

            let resultat = try await corps(session)

            await session.fermer()

            return resultat
        } catch {
            await session.fermer()

            throw error
        }
    }
}

//
// AdresseDeReception
//
// L adresse que l utilisateur tape dans le navigateur de l autre machine.
//
// Le nom d hote Bonjour serait plus joli, mais il n est pas resolu par tous les
// navigateurs ni par tous les systemes, et une adresse qui ne repond pas fait
// croire que la reception est en panne. L adresse numerique de l interface
// locale marche partout.
//
// Les interfaces sont filtrees sur leur nom parce que le seul drapeau ne suffit
// pas : une machine porte regulierement des interfaces virtuelles montees et
// actives, celles des machines virtuelles ou des reseaux prives, dont l adresse
// n est joignable par personne d autre. Les interfaces `en` et `bridge` sont
// celles du Wi-Fi et de l Ethernet.
//

/// L adresse locale a afficher pour joindre la reception.
public enum AdresseDeReception {
    /// La premiere adresse IPv4 d une interface Wi-Fi ou Ethernet active.
    public static func adresseIPv4Locale() -> String? {
        var premier: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&premier) == 0, let liste = premier else {
            return nil
        }

        defer { freeifaddrs(premier) }

        for interface in sequence(first: liste, next: { $0.pointee.ifa_next }) {
            let drapeaux = Int32(interface.pointee.ifa_flags)

            guard drapeaux & IFF_UP != 0,
                  drapeaux & IFF_LOOPBACK == 0,
                  let adresse = interface.pointee.ifa_addr,
                  adresse.pointee.sa_family == UInt8(AF_INET),
                  estUneInterfaceLocale(String(cString: interface.pointee.ifa_name)),
                  let lisible = texte(de: adresse)
            else {
                continue
            }

            return lisible
        }

        return nil
    }

    /// L adresse complete a taper dans un navigateur.
    public static func adresse(pour port: UInt16) -> String? {
        adresseIPv4Locale().map { "http://\($0):\(port)" }
    }

    /// Vrai pour une interface Wi-Fi ou Ethernet.
    static func estUneInterfaceLocale(_ nom: String) -> Bool {
        nom.hasPrefix("en") || nom.hasPrefix("bridge")
    }

    /// Forme lisible d une adresse de socket, sans passer par une chaine C
    /// terminee que Swift 6 ne relit plus.
    private static func texte(de adresse: UnsafeMutablePointer<sockaddr>) -> String? {
        var tampon = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let obtenu = getnameinfo(
            adresse,
            socklen_t(adresse.pointee.sa_len),
            &tampon,
            socklen_t(tampon.count),
            nil,
            0,
            NI_NUMERICHOST
        )

        guard obtenu == 0 else {
            return nil
        }

        let octets = Data(tampon.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) })

        guard octets.isEmpty == false else {
            return nil
        }

        // Une adresse numerique mal formee n existe pas en pratique, mais la
        // conversion faillible est la bonne : elle refuse au lieu de fabriquer
        // une chaine de remplacement a partir d octets qui n en sont pas.
        return String(bytes: octets, encoding: .utf8)
    }
}
