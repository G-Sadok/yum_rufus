import Core
import Foundation

//
// ServeurDeTransfertWifi
//
// Le serveur de la section 4.4 : une page de depot, un code a six chiffres, et
// des fichiers qui atterrissent dans la source Fichiers locaux.
//
// C est un acteur parce que tout son etat est partage et mutable : le jeton de
// session, le compteur d essais rates et l ouverture elle meme sont lus et
// ecrits par autant de taches qu il y a de connexions, et un navigateur ouvre
// plusieurs connexions de front sans prevenir.
//
// Le serveur ne connait pas le reseau. Il recoit une requete deja lue et rend
// une reponse, ce qui permet de prouver le code obligatoire, le refus d un
// format et la fermeture sans ouvrir de port. Le port est l affaire de
// `PointDEcoute`, et la duree de vie celle de `SessionDeTransfertWifi`.
//
// Le transport est en clair, et c est l exception locale que la regle de
// securite du projet demande de confirmer explicitement. Elle est confirmee
// ici : la section 4.4 impose un serveur HTTP sur le port 8080, et un
// certificat de confiance pour une adresse privee tiree par le routeur ne
// s obtient pas. Trois choses compensent, et elles se lisent dans le code
// ci dessous. La reception ne vit que le temps d une feuille ouverte. Le code
// change a chaque ouverture et se compare a temps constant. Dix codes faux la
// verrouillent, ce qui ramene une recherche exhaustive d un million de codes a
// une chance sur cent mille par ouverture.
//
// Le code est obligatoire au sens fort : tant qu il n a pas ete presente juste,
// aucune reponse ne contient le formulaire de fichiers, et un depot envoye
// directement, sans passer par la page, est refuse sans etre lu.
//

/// Le serveur de la reception Wi-Fi, sans son transport.
public actor ServeurDeTransfertWifi {
    /// Port impose par la section 4.4.
    public static let portParDefaut: UInt16 = 8080

    /// Taille maximale d un depot, en une requete.
    ///
    /// Le corps multipartie est tenu en memoire le temps d etre decoupe. Un
    /// plafond est donc une protection de l appareil autant qu un refus de
    /// service : sans lui, une machine du reseau ferait tomber l application en
    /// annoncant un corps de plusieurs gigaoctets. La valeur laisse passer un
    /// tome relie de plusieurs centaines de megaoctets, qui est le cas reel le
    /// plus lourd, et impose de deposer une longue serie par lots.
    public static let plafondParDepot = 512 * 1024 * 1024

    /// Nombre de codes faux au dela duquel la reception se verrouille.
    public static let plafondDEssais = 10

    /// Nom du biscuit qui porte la session ouverte par le code.
    static let nomDuBiscuit = "reception"

    private let code: CodeDeTransfert
    private let reception: any ReceptionDeDepot
    private let libelles: LibellesDeLaPageDeDepot

    private var ouverte = true
    private var jeton: String?
    private var essaisRates = 0

    public init(
        code: CodeDeTransfert,
        reception: any ReceptionDeDepot,
        libelles: LibellesDeLaPageDeDepot = LibellesDeLaPageDeDepot()
    ) {
        self.code = code
        self.reception = reception
        self.libelles = libelles
    }

    /// Vrai tant que la feuille est ouverte.
    public var estOuverte: Bool {
        ouverte
    }

    /// Nombre de codes faux presentes depuis l ouverture.
    var essaisRefuses: Int {
        essaisRates
    }

    /// Ferme la reception : plus aucune requete n est servie ensuite.
    ///
    /// Le jeton est oublie en meme temps, pour qu une reception rouverte ne
    /// reconnaisse pas le biscuit garde par un navigateur de la fois d avant.
    public func fermer() async {
        guard ouverte else {
            return
        }

        ouverte = false
        jeton = nil

        await reception.conclure()
    }

    /// Repond aux octets d une requete, tels qu ils arrivent du transport.
    func repondre(auxOctets octets: Data) async -> Data {
        do {
            return try await repondre(a: RequeteDeDepot.analyser(octets)).octets
        } catch let erreur as ErreurDeTransfert {
            return refus(erreur).octets
        } catch {
            return refus(.requeteMalformee).octets
        }
    }

    /// Repond a une requete deja lue.
    func repondre(a requete: RequeteDeDepot) async -> ReponseDeDepot {
        guard ouverte else {
            return refus(.receptionFermee)
        }
        guard essaisRates < Self.plafondDEssais else {
            return refus(.tropDEssais(essais: essaisRates))
        }

        switch (requete.methode, requete.chemin) {
        case ("GET", CheminsDeLaReception.racine):
            return .page(estReconnu(requete) ? PageDeDepot.depot(libelles) : PageDeDepot.demandeDeCode(libelles))
        case ("POST", CheminsDeLaReception.session):
            return presenterLeCode(requete)
        case ("POST", CheminsDeLaReception.depot):
            return await recevoirLesFichiers(requete)
        case ("GET", CheminsDeLaReception.session), ("GET", CheminsDeLaReception.depot):
            return .redirection(vers: CheminsDeLaReception.racine)
        case (_, CheminsDeLaReception.racine), (_, CheminsDeLaReception.session), (_, CheminsDeLaReception.depot):
            return ReponseDeDepot(code: 405, entetes: ["Allow": "GET, POST"])
        default:
            return .page(PageDeDepot.refus(libelles, cause: .requeteMalformee), code: 404)
        }
    }

    // MARK: Code

    /// Traite le formulaire de code.
    private func presenterLeCode(_ requete: RequeteDeDepot) -> ReponseDeDepot {
        guard requete.typeDeContenu == "application/x-www-form-urlencoded" else {
            return refus(.requeteMalformee)
        }

        let champs = FormulaireDeDepot.champsEncodes(requete.corps)

        guard code.correspond(a: champs[PageDeDepot.champDuCode] ?? "") else {
            essaisRates += 1

            guard essaisRates < Self.plafondDEssais else {
                return refus(.tropDEssais(essais: essaisRates))
            }

            return .page(PageDeDepot.demandeDeCode(libelles, refus: .codeRefuse), code: 401)
        }

        let neuf = Self.tirerUnJeton()
        jeton = neuf

        // Redirection plutot que page servie directement : sans elle, le
        // navigateur garde le POST du code dans son historique, et un
        // rechargement le rejoue, ce qui compte un essai de plus.
        return .redirection(
            vers: CheminsDeLaReception.racine,
            entetes: ["Set-Cookie": "\(Self.nomDuBiscuit)=\(neuf); Path=/; HttpOnly; SameSite=Strict"]
        )
    }

    /// Vrai quand la requete presente le jeton ouvert par un code juste.
    private func estReconnu(_ requete: RequeteDeDepot) -> Bool {
        guard let jeton, let presente = requete.biscuits[Self.nomDuBiscuit] else {
            return false
        }

        return Self.egalesATempsConstant(jeton, presente)
    }

    // MARK: Depot

    /// Traite le formulaire de fichiers.
    private func recevoirLesFichiers(_ requete: RequeteDeDepot) async -> ReponseDeDepot {
        guard estReconnu(requete) else {
            // Le depot n est meme pas lu : sans code, le corps de la requete ne
            // sort pas du tampon.
            return .page(PageDeDepot.demandeDeCode(libelles, refus: .codeRefuse), code: 401)
        }
        guard requete.typeDeContenu == "multipart/form-data",
              let frontiere = requete.parametreDeContenu("boundary")
        else {
            return refus(.requeteMalformee)
        }

        let champs: [ChampDeDepot]

        do {
            champs = try FormulaireDeDepot.champsMultipartie(requete.corps, frontiere: frontiere)
        } catch let erreur as ErreurDeTransfert {
            return refus(erreur)
        } catch {
            return refus(.requeteMalformee)
        }

        // Un champ de fichiers laisse vide arrive quand meme, avec un nom vide
        // et aucun octet. Le compter comme un refus afficherait une erreur pour
        // un formulaire simplement incomplet.
        let fichiers = champs.filter { champ in
            champ.estUnFichier && ((champ.nomDeFichier?.isEmpty == false) || champ.contenu.isEmpty == false)
        }

        guard fichiers.isEmpty == false else {
            return .page(PageDeDepot.depot(libelles), code: 400)
        }

        var recus: [String] = []
        var refuses: [(nom: String, cause: ErreurDeTransfert)] = []

        for fichier in fichiers {
            let propose = fichier.nomDeFichier ?? ""

            do {
                try await recus.append(reception.recevoir(nomPropose: propose, octets: fichier.contenu))
            } catch let erreur as ErreurDeTransfert {
                refuses.append((nom: propose, cause: erreur))
            } catch {
                refuses.append((nom: propose, cause: .ecritureImpossible))
            }
        }

        let page = PageDeDepot.depot(libelles, recus: recus, refuses: refuses)

        guard recus.isEmpty else {
            return .page(page, code: 201)
        }

        return .page(page, code: refuses.first?.cause.codeHttp ?? 400)
    }

    // MARK: Details

    private func refus(_ cause: ErreurDeTransfert) -> ReponseDeDepot {
        .page(PageDeDepot.refus(libelles, cause: cause), code: cause.codeHttp)
    }

    /// Tire le jeton de session, sur 128 bits.
    ///
    /// Le jeton est aussi sensible que le code : le presenter dispense de le
    /// saisir. Il est donc tire par le generateur du systeme, et non derive du
    /// code, dont il doit rester independant.
    private static func tirerUnJeton() -> String {
        var generateur = SystemRandomNumberGenerator()
        let hautes = UInt64.random(in: UInt64.min...UInt64.max, using: &generateur)
        let basses = UInt64.random(in: UInt64.min...UInt64.max, using: &generateur)

        return String(format: "%016lx%016lx", hautes, basses)
    }

    /// Compare deux jetons sans laisser mesurer ou ils different.
    private static func egalesATempsConstant(_ gauche: String, _ droite: String) -> Bool {
        let attendu = Array(gauche.utf8)
        let presente = Array(droite.utf8)

        guard attendu.count == presente.count else {
            return false
        }

        var ecart: UInt8 = 0

        for index in attendu.indices {
            ecart |= attendu[index] ^ presente[index]
        }

        return ecart == 0
    }
}
