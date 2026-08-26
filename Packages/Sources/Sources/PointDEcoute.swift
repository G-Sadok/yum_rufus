import Core
import Foundation
import Network

//
// PointDEcoute
//
// Le port sur lequel la reception Wi-Fi attend, et la couture par laquelle les
// tests s en passent.
//
// Le protocole est volontairement etroit : ouvrir, rendre le port obtenu,
// arreter. Tout ce qui ressemble a du HTTP est deja decide ailleurs, dans le
// cadrage et dans le serveur. Ce qui reste ici est du socket, et du socket
// seulement.
//
// La separation sert deux choses. Elle laisse la suite de tests prouver le
// cycle de vie et le code obligatoire sans jamais ouvrir de port, ce qui evite
// des tests qui echouent quand la machine d integration en refuse un ou quand
// le port 8080 est deja pris. Et elle garde la promesse de la section 4.4
// verifiable au bon endroit : ce qui doit s arreter avec la feuille, c est
// l ecoute, et l ecoute est ce type la.
//

/// Ce qui porte la reception Wi-Fi sur un port.
public protocol PointDEcoute: Sendable {
    /// Ouvre l ecoute et rend le port reellement obtenu.
    ///
    /// Le traitement recoit les octets d une requete complete et rend les
    /// octets de la reponse.
    ///
    /// - Throws: `ErreurReseau` quand le port ne peut pas etre pris.
    func demarrer(_ traiter: @escaping @Sendable (Data) async -> Data) async throws -> UInt16

    /// Ferme l ecoute et coupe les connexions en cours.
    func arreter() async
}

/// L ecoute reelle, posee sur le cadre Network.
///
/// C est un acteur parce que l ecouteur et la liste des connexions vivantes
/// sont un etat partage : une connexion peut arriver pendant que la feuille se
/// ferme, et la fermeture doit voir cette connexion la pour la couper.
public actor EcouteHttpLocale: PointDEcoute {
    /// Delai au dela duquel une connexion qui n a pas fini sa requete est
    /// coupee.
    ///
    /// Sans lui, une machine du reseau garde une connexion ouverte sans jamais
    /// terminer sa requete, et le tampon correspondant reste en memoire aussi
    /// longtemps que la feuille. Trente secondes laissent le temps a un depot de
    /// plusieurs centaines de megaoctets d arriver sur un Wi-Fi mediocre.
    public static let delaiParConnexion: TimeInterval = 30

    private let port: UInt16
    private let plafondDuCorps: Int

    private var ecouteur: NWListener?
    private var connexions: [NWConnection] = []

    public init(
        port: UInt16 = ServeurDeTransfertWifi.portParDefaut,
        plafondDuCorps: Int = ServeurDeTransfertWifi.plafondParDepot
    ) {
        self.port = port
        self.plafondDuCorps = plafondDuCorps
    }

    public func demarrer(_ traiter: @escaping @Sendable (Data) async -> Data) async throws -> UInt16 {
        if let ecouteur, let obtenu = ecouteur.port {
            return obtenu.rawValue
        }

        guard let portReseau = NWEndpoint.Port(rawValue: port) else {
            throw ErreurReseau.serveurIntrouvable
        }

        let parametres = NWParameters.tcp
        // Une feuille refermee puis rouverte aussitot retrouve le meme port,
        // alors que le precedent est encore en attente de fermeture cote noyau.
        parametres.allowLocalEndpointReuse = true
        parametres.includePeerToPeer = false

        let ouvert: NWListener

        do {
            ouvert = try NWListener(using: parametres, on: portReseau)
        } catch {
            throw Self.traduire(error)
        }

        ouvert.newConnectionHandler = { [plafondDuCorps] connexion in
            Task { [weak self] in
                await self?.accueillir(connexion, plafondDuCorps: plafondDuCorps, traiter: traiter)
            }
        }

        try await Self.attendreLEtatPret(de: ouvert)

        ecouteur = ouvert

        return ouvert.port?.rawValue ?? port
    }

    public func arreter() async {
        for connexion in connexions {
            connexion.cancel()
        }

        connexions.removeAll()
        ecouteur?.newConnectionHandler = nil
        ecouteur?.stateUpdateHandler = nil
        ecouteur?.cancel()
        ecouteur = nil
    }

    // MARK: Connexions

    /// Sert une connexion entrante, puis la ferme.
    private func accueillir(
        _ connexion: NWConnection,
        plafondDuCorps: Int,
        traiter: @escaping @Sendable (Data) async -> Data
    ) async {
        guard ecouteur != nil else {
            // La feuille s est fermee entre l acceptation et ici.
            return connexion.cancel()
        }

        connexions.append(connexion)
        connexion.start(queue: .global(qos: .userInitiated))

        do {
            try await withThrowingTaskGroup(of: Void.self) { groupe in
                groupe.addTask {
                    try await Self.servir(connexion, plafondDuCorps: plafondDuCorps, traiter: traiter)
                }
                groupe.addTask {
                    try await Task.sleep(for: .seconds(Self.delaiParConnexion))

                    throw ErreurReseau.delaiDepasse
                }

                // La premiere des deux taches qui aboutit decide, l autre est
                // annulee. Sans cette course, une requete jamais terminee
                // garderait son tampon aussi longtemps que la feuille.
                try await groupe.next()
                groupe.cancelAll()
            }
        } catch {
            // Une connexion coupee ou muette au milieu d une requete n a
            // personne a qui se plaindre. Elle est simplement fermee.
        }

        oublier(connexion)
    }

    /// Lit une requete entiere, la fait traiter, et rend la reponse.
    private static func servir(
        _ connexion: NWConnection,
        plafondDuCorps: Int,
        traiter: @escaping @Sendable (Data) async -> Data
    ) async throws {
        var cadrage = CadrageDeRequete(plafondDuCorps: plafondDuCorps)

        while true {
            try Task.checkCancellation()

            let octets = try await recevoir(sur: connexion)

            guard octets.isEmpty == false else {
                // La machine d en face a ferme sans terminer sa requete.
                return
            }
            guard let requete = try cadrage.ajouter(octets) else {
                continue
            }

            return try await envoyer(traiter(requete), sur: connexion)
        }
    }

    private func oublier(_ connexion: NWConnection) {
        connexion.cancel()
        connexions.removeAll { $0 === connexion }
    }

    // MARK: Cadre Network

    /// Attend que l ecouteur soit pret, ou echoue.
    private static func attendreLEtatPret(de ecouteur: NWListener) async throws {
        let sentinelle = SentinelleDOuvertureDEcoute()

        try await withCheckedThrowingContinuation { (reprise: CheckedContinuation<Void, any Error>) in
            ecouteur.stateUpdateHandler = { etat in
                switch etat {
                case .ready:
                    Task { await sentinelle.conclure(reprise, avec: nil) }
                case let .failed(erreur):
                    Task { await sentinelle.conclure(reprise, avec: traduire(erreur)) }
                case .cancelled:
                    Task { await sentinelle.conclure(reprise, avec: ErreurReseau.annulee) }
                default:
                    break
                }
            }
            ecouteur.start(queue: .global(qos: .userInitiated))
        }
    }

    /// Rend ce qui arrive sur la connexion, ou un bloc vide a sa fermeture.
    private static func recevoir(sur connexion: NWConnection) async throws -> Data {
        try await withCheckedThrowingContinuation { (reprise: CheckedContinuation<Data, any Error>) in
            connexion.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { octets, _, _, erreur in
                if let erreur {
                    return reprise.resume(throwing: traduire(erreur))
                }

                // Un bloc vide, avec ou sans fin de flot, veut dire la meme
                // chose ici : il n y aura pas d autre octet pour l instant, et
                // l appelant en tire la fin de la requete.
                reprise.resume(returning: octets ?? Data())
            }
        }
    }

    private static func envoyer(_ octets: Data, sur connexion: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (reprise: CheckedContinuation<Void, any Error>) in
            connexion.send(
                content: octets,
                completion: .contentProcessed { erreur in
                    guard let erreur else {
                        return reprise.resume()
                    }

                    reprise.resume(throwing: traduire(erreur))
                }
            )
        }
    }

    /// Traduit une erreur du cadre Network en cas nomme du domaine.
    private static func traduire(_ erreur: any Error) -> ErreurReseau {
        guard let reseau = erreur as? NWError, case let .posix(code) = reseau else {
            return .echecDeTransport(code: 0)
        }

        switch code {
        case .EADDRINUSE, .EACCES:
            // Le port est deja pris, ou le systeme refuse de le prendre.
            return .accesRefuse
        case .ECONNRESET, .EPIPE:
            return .reponseTronquee
        case .ETIMEDOUT:
            return .delaiDepasse
        default:
            return .echecDeTransport(code: Int(code.rawValue))
        }
    }
}

/// Garde qu une reprise d attente d ecoute ne soit pas conclue deux fois.
///
/// Meme raison que pour l ouverture d une connexion : le gestionnaire d etat
/// est rappele plusieurs fois, et un ecouteur qui devient pret puis annule
/// conclurait deux fois la meme continuation, ce qui est une faute fatale.
private actor SentinelleDOuvertureDEcoute {
    private var conclue = false

    func conclure(_ reprise: CheckedContinuation<Void, any Error>, avec erreur: ErreurReseau?) {
        guard conclue == false else {
            return
        }

        conclue = true

        guard let erreur else {
            return reprise.resume()
        }

        reprise.resume(throwing: erreur)
    }
}
