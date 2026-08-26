import Core
import Foundation

//
// AppelRpc
//
// Le protocole ONC RPC, sur lequel NFS est bati. L encodage des valeurs vit a
// cote, dans `CodageXdr`.
//
// NFS n est pas un protocole, c est un jeu de procedures appelees a distance.
// Tout ce qui traverse le fil est donc un appel RPC : un en tete qui dit quel
// programme, quelle version et quelle procedure, une preuve d identite, puis les
// arguments encodes en XDR. La reponse suit la meme forme.
//
// Sur TCP, un appel est precede d un marqueur de fragment : quatre octets dont
// le bit de poids fort dit que le fragment est le dernier, et les trente et un
// autres donnent sa longueur. Un lecteur qui l ignore lit l en tete RPC quatre
// octets trop loin et ne comprend plus rien.
//

/// Ce qu il faut savoir pour se presenter a un serveur ONC RPC.
///
/// La preuve `AUTH_UNIX` est la seule que NFS version trois emploie en pratique.
/// Elle n est pas une authentification : elle annonce un identifiant
/// d utilisateur et de groupe, et le serveur decide d y croire ou non selon
/// l adresse d ou vient l appel. C est pourquoi un export NFS se protege par
/// adresse et par reseau, jamais par mot de passe, et pourquoi la section 11 ne
/// range aucun secret pour ce protocole.
public struct IdentiteUnix: Sendable, Hashable {
    public let machine: String
    public let utilisateur: UInt32
    public let groupe: UInt32
    public let groupesSecondaires: [UInt32]

    public init(
        machine: String = "tsuzuki",
        utilisateur: UInt32 = 0,
        groupe: UInt32 = 0,
        groupesSecondaires: [UInt32] = []
    ) {
        self.machine = machine
        self.utilisateur = utilisateur
        self.groupe = groupe
        self.groupesSecondaires = groupesSecondaires
    }

    /// Le corps de la preuve, tel que la norme le decrit.
    func corps(horodatage: UInt32) -> Data {
        var ecriture = EcritureXdr()
        ecriture.entier32(horodatage)
        ecriture.texte(machine)
        ecriture.entier32(utilisateur)
        ecriture.entier32(groupe)
        ecriture.entier32(UInt32(groupesSecondaires.count))

        for groupe in groupesSecondaires {
            ecriture.entier32(groupe)
        }

        return ecriture.octets
    }
}

/// Ce qui designe une procedure distante et ce qu on lui passe.
///
/// Les six valeurs voyagent ensemble parce qu elles n ont aucun sens separees :
/// un numero de procedure ne veut rien dire sans son programme et sa version, et
/// les arguments sont encodes selon la procedure visee.
struct DemandeRpc: Sendable {
    let identifiant: UInt32
    let programme: UInt32
    let version: UInt32
    let procedure: UInt32
    let horodatage: UInt32
    let arguments: Data
}

/// Ce qui peut mal tourner dans un echange ONC RPC.
enum ErreurRpc: Error, Sendable, Equatable {
    /// Le serveur a refuse l appel, avec le code qu il a rendu.
    case appelRefuse(code: UInt32)

    /// Le serveur a accepte l appel mais l a rate, avec son code.
    case appelRate(code: UInt32)

    /// La reponse ne suit pas la forme d une reponse RPC.
    case reponseIllisible

    /// La reponse ne repond pas a l appel qui vient de partir.
    case reponseMalAppariee

    /// La procedure a rendu un statut d erreur propre a son programme.
    case statut(programme: UInt32, code: UInt32)

    /// Traduction vers le domaine, pour que rien de brut ne remonte a la vue.
    var reseau: ErreurReseau {
        switch self {
        case .appelRefuse:
            .authentificationRefusee
        case .reponseIllisible, .reponseMalAppariee:
            .reponseIllisible
        case .appelRate:
            .reponseInattendue(code: 0)
        case let .statut(_, code):
            Self.traduireLeStatutNfs(code)
        }
    }

    /// Traduit les statuts d erreur de NFS version trois qui ont un sens ici.
    private static func traduireLeStatutNfs(_ code: UInt32) -> ErreurReseau {
        switch code {
        case 1, 13: .accesRefuse
        case 2: .ressourceIntrouvable
        case 70: .reponseTronquee
        default: .reponseInattendue(code: Int(code))
        }
    }
}

/// Client ONC RPC sur TCP, avec marquage de fragments.
///
/// C est un acteur parce que l identifiant d appel s incremente et que deux
/// appels de front sur le meme canal doivent recevoir chacun leur reponse.
actor ClientRpc {
    /// Longueur maximale acceptee pour une reponse.
    ///
    /// Un mega octet au dela de la plus grosse lecture NFS que le client
    /// demande. La borne existe pour qu un serveur hostile, ou un flot
    /// desynchronise, ne fasse pas allouer une trame de plusieurs giga octets.
    static let trameMaximale = 8 * 1024 * 1024

    private let canal: any CanalReseau
    private let identite: IdentiteUnix
    private let horodatage: @Sendable () -> UInt32

    private var prochainIdentifiant: UInt32 = 1

    init(
        canal: any CanalReseau,
        identite: IdentiteUnix = IdentiteUnix(),
        horodatage: @escaping @Sendable () -> UInt32 = ClientRpc.horodatageCourant
    ) {
        self.canal = canal
        self.identite = identite
        self.horodatage = horodatage
    }

    /// L instant courant, en secondes depuis l epoque.
    static let horodatageCourant: @Sendable () -> UInt32 = {
        UInt32(truncatingIfNeeded: Int(Date().timeIntervalSince1970))
    }

    /// Appelle une procedure et rend le curseur pose sur son resultat.
    ///
    /// - Throws: `ErreurRpc` quand l echange lui meme echoue, `ErreurReseau`
    ///   quand c est le canal.
    func appeler(
        programme: UInt32,
        version: UInt32,
        procedure: UInt32,
        arguments: Data
    ) async throws -> LectureXdr {
        try Task.checkCancellation()
        try await canal.ouvrir()

        let identifiant = prochainIdentifiant
        prochainIdentifiant &+= 1

        let demande = DemandeRpc(
            identifiant: identifiant,
            programme: programme,
            version: version,
            procedure: procedure,
            horodatage: horodatage(),
            arguments: arguments
        )

        try await canal.envoyer(Self.marquer(Self.appel(demande, identite: identite)))

        let reponse = try await recevoirUneReponse()

        return try Self.lireLaReponse(reponse, identifiant: identifiant)
    }

    // MARK: Trames

    /// Assemble le message d appel, en tete et arguments.
    static func appel(_ demande: DemandeRpc, identite: IdentiteUnix) -> Data {
        var ecriture = EcritureXdr()
        ecriture.entier32(demande.identifiant)
        ecriture.entier32(0)
        ecriture.entier32(2)
        ecriture.entier32(demande.programme)
        ecriture.entier32(demande.version)
        ecriture.entier32(demande.procedure)

        // Preuve d identite AUTH_UNIX, puis verificateur AUTH_NULL, que la
        // norme impose vide sur un appel.
        ecriture.entier32(1)
        ecriture.variable(identite.corps(horodatage: demande.horodatage))
        ecriture.entier32(0)
        ecriture.entier32(0)
        ecriture.ajouter(demande.arguments)

        return ecriture.octets
    }

    /// Pose le marqueur de fragment, avec le bit de dernier fragment.
    static func marquer(_ trame: Data) -> Data {
        var ecriture = EcritureXdr()
        ecriture.entier32(UInt32(trame.count) | 0x8000_0000)
        ecriture.ajouter(trame)

        return ecriture.octets
    }

    /// Lit une reponse complete, fragment par fragment.
    private func recevoirUneReponse() async throws -> Data {
        var assemblee = Data()

        while true {
            try Task.checkCancellation()

            let marqueur = try await canal.recevoir(exactement: 4)
            var lecture = LectureXdr(marqueur)

            guard let entete = lecture.entier32() else {
                throw ErreurReseau.reponseTronquee
            }

            let dernier = entete & 0x8000_0000 != 0
            let longueur = Int(entete & 0x7FFF_FFFF)

            guard longueur <= Self.trameMaximale else {
                throw ErreurReseau.reponseIllisible
            }

            try await assemblee.append(canal.recevoir(exactement: longueur))

            if dernier {
                return assemblee
            }
        }
    }

    /// Verifie l en tete de reponse et rend le curseur pose sur le resultat.
    static func lireLaReponse(_ octets: Data, identifiant: UInt32) throws -> LectureXdr {
        var lecture = LectureXdr(octets)

        guard let renvoye = lecture.entier32(), let type = lecture.entier32() else {
            throw ErreurRpc.reponseIllisible
        }
        guard renvoye == identifiant else {
            throw ErreurRpc.reponseMalAppariee
        }
        guard type == 1, let etat = lecture.entier32() else {
            throw ErreurRpc.reponseIllisible
        }
        guard etat == 0 else {
            guard let code = lecture.entier32() else {
                throw ErreurRpc.reponseIllisible
            }

            throw ErreurRpc.appelRefuse(code: code)
        }

        // Verificateur de la reponse, ignore : la seule saveur qu un serveur NFS
        // renvoie est AUTH_NULL, et sa verification n apporterait rien sans
        // authentification forte.
        guard lecture.entier32() != nil, lecture.variable() != nil, let accepte = lecture.entier32() else {
            throw ErreurRpc.reponseIllisible
        }
        guard accepte == 0 else {
            throw ErreurRpc.appelRate(code: accepte)
        }

        return lecture
    }
}
