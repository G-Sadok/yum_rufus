import Core
import Foundation
import Network

//
// CanalReseau
//
// Le fil sur lequel parlent SMB et NFS, et la couture par laquelle les tests le
// remplacent.
//
// WebDAV n en a pas besoin : il parle HTTP, donc il passe par `TransportHttp`,
// qui rend deja une reponse complete par requete. SMB et NFS, eux, sont des
// protocoles a trames sur TCP. Ce qui les separe d une requete HTTP tient en
// deux points, et les deux imposent cette abstraction.
//
// D abord la session. Une lecture SMB n a de sens qu apres une negociation, une
// ouverture de session, une connexion a l arborescence et une ouverture de
// fichier. Les quatre etats vivent dans la connexion, pas dans la requete, et un
// transport sans memoire les perdrait a chaque appel.
//
// Ensuite le decoupage. TCP ne rend pas des messages mais un flot d octets. Les
// deux protocoles portent donc leur propre longueur en tete de trame, et lire
// une trame veut dire lire exactement le nombre d octets annonce, ni un de plus,
// ni un de moins. C est ce que `recevoir(exactement:)` promet, et c est ce qui
// permet aux tests de rejouer des trames enregistrees sans ouvrir de port.
//

/// Un flot d octets bidirectionnel vers un serveur.
public protocol CanalReseau: Sendable {
    /// Ouvre la connexion, ou ne fait rien si elle est deja ouverte.
    ///
    /// - Throws: `ErreurReseau`, dans le cas nomme qui correspond a ce qui s est
    ///   passe.
    func ouvrir() async throws

    /// Envoie des octets, dans l ordre.
    func envoyer(_ octets: Data) async throws

    /// Rend exactement `longueur` octets.
    ///
    /// - Throws: `ErreurReseau.reponseTronquee` quand la connexion se ferme
    ///   avant que le compte y soit, ce qui est la forme que prend une coupure
    ///   au milieu d une trame.
    func recevoir(exactement longueur: Int) async throws -> Data

    /// Ferme la connexion.
    func fermer() async
}

/// Le canal reel, pose sur le cadre Network.
///
/// C est un acteur parce qu une connexion TCP est une ressource partagee
/// mutable : deux trames envoyees de front sur le meme fil se melangeraient, et
/// deux lectures de front se voleraient leurs octets.
public actor CanalTcp: CanalReseau {
    /// Delai au dela duquel une operation est abandonnee.
    ///
    /// Quinze secondes, la meme valeur que le transport HTTP et que la limite
    /// des extensions. Deux delais differents feraient qu un partage lent serait
    /// tantot declare muet, tantot en echec, selon laquelle des deux horloges
    /// gagne.
    public static let delaiParDefaut: TimeInterval = 15

    private let hote: String
    private let port: UInt16
    private let delai: TimeInterval

    private var connexion: NWConnection?

    /// Octets recus et pas encore reclames.
    ///
    /// TCP ne rend pas des messages : une seule reception peut rapporter la fin
    /// d une trame et le debut de la suivante. Ce qui depasse est garde ici,
    /// sans quoi chaque trame perdrait sa tete.
    private var enAttente = Data()

    public init(hote: String, port: UInt16, delai: TimeInterval = CanalTcp.delaiParDefaut) {
        self.hote = hote
        self.port = port
        self.delai = delai
    }

    // MARK: Protocole

    public func ouvrir() async throws {
        guard connexion == nil else {
            return
        }
        guard let port = NWEndpoint.Port(rawValue: port) else {
            throw ErreurReseau.serveurIntrouvable
        }

        let parametres = NWParameters.tcp
        let ouverte = NWConnection(host: NWEndpoint.Host(hote), port: port, using: parametres)

        try await Self.attendreLEtatPret(de: ouverte, delai: delai)

        connexion = ouverte
    }

    public func envoyer(_ octets: Data) async throws {
        let connexion = try connexionOuverte()

        try await withCheckedThrowingContinuation { (reprise: CheckedContinuation<Void, any Error>) in
            connexion.send(
                content: octets,
                completion: .contentProcessed { erreur in
                    guard let erreur else {
                        return reprise.resume()
                    }

                    reprise.resume(throwing: Self.traduire(erreur))
                }
            )
        }
    }

    public func recevoir(exactement longueur: Int) async throws -> Data {
        guard longueur > 0 else {
            return Data()
        }

        let connexion = try connexionOuverte()

        while enAttente.count < longueur {
            try Task.checkCancellation()

            let recus = try await Self.recevoir(sur: connexion, maximum: longueur - enAttente.count)

            guard recus.isEmpty == false else {
                throw ErreurReseau.reponseTronquee
            }

            enAttente.append(recus)
        }

        let debut = enAttente.startIndex
        let trame = enAttente.subdata(in: debut..<(debut + longueur))
        enAttente.removeFirst(longueur)

        return trame
    }

    public func fermer() async {
        connexion?.cancel()
        connexion = nil
        enAttente.removeAll()
    }

    // MARK: Cadre Network

    private func connexionOuverte() throws -> NWConnection {
        guard let connexion else {
            throw ErreurReseau.connexionRefusee
        }

        return connexion
    }

    /// Attend que la connexion soit prete, ou echoue.
    private static func attendreLEtatPret(de connexion: NWConnection, delai: TimeInterval) async throws {
        let sentinelle = SentinelleDOuverture()

        try await withThrowingTaskGroup(of: Void.self) { groupe in
            groupe.addTask {
                try await withCheckedThrowingContinuation { (reprise: CheckedContinuation<Void, any Error>) in
                    connexion.stateUpdateHandler = { etat in
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
                    connexion.start(queue: .global(qos: .userInitiated))
                }
            }
            groupe.addTask {
                try await Task.sleep(for: .seconds(delai))

                throw ErreurReseau.delaiDepasse
            }

            // La premiere des deux taches qui aboutit decide, l autre est
            // annulee. Sans cette course, une connexion vers un hote qui ne
            // repond jamais attendrait le delai du systeme, qui se compte en
            // minutes.
            try await groupe.next()
            groupe.cancelAll()
        }
    }

    /// Recoit ce qui arrive, sans exiger un compte precis.
    private static func recevoir(sur connexion: NWConnection, maximum: Int) async throws -> Data {
        try await withCheckedThrowingContinuation { (reprise: CheckedContinuation<Data, any Error>) in
            connexion.receive(minimumIncompleteLength: 1, maximumLength: maximum) { octets, _, termine, erreur in
                if let erreur {
                    return reprise.resume(throwing: traduire(erreur))
                }
                if let octets, octets.isEmpty == false {
                    return reprise.resume(returning: octets)
                }

                reprise.resume(throwing: termine ? ErreurReseau.reponseTronquee : ErreurReseau.horsLigne)
            }
        }
    }

    /// Traduit une erreur du cadre Network en cas nomme du domaine.
    private static func traduire(_ erreur: NWError) -> ErreurReseau {
        switch erreur {
        case let .posix(code):
            switch code {
            case .ECONNREFUSED: .connexionRefusee
            case .ETIMEDOUT: .delaiDepasse
            case .ENETDOWN, .ENETUNREACH, .EHOSTUNREACH: .horsLigne
            case .ECONNRESET, .EPIPE: .reponseTronquee
            default: .echecDeTransport(code: Int(code.rawValue))
            }
        case .dns:
            .serveurIntrouvable
        case .tls:
            .certificatRefuse
        default:
            .echecDeTransport(code: 0)
        }
    }
}

/// Garde qu une reprise d attente ne soit pas conclue deux fois.
///
/// Le gestionnaire d etat d une connexion est rappele plusieurs fois, et une
/// connexion qui devient prete puis annulee conclurait deux fois la meme
/// continuation, ce qui est une faute fatale en Swift.
private actor SentinelleDOuverture {
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
