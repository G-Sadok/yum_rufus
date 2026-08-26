import CryptoKit
import Foundation

//
// AuthentificationDigest
//
// L authentification Digest de HTTP, telle que la RFC 7616 la definit, et telle
// que le tableau 4.2 l exige pour WebDAV. C est le troisieme critere de la
// fonctionnalite.
//
// Elle ne passe pas par `IdentiteHttp`, et ce n est pas un oubli. Une identite
// au sens de ce protocole rend un entete qui vaut pour n importe quelle requete,
// ce qui est vrai d une authentification basique et d une cle d API. La reponse
// Digest, elle, est calculee sur la methode et sur le chemin de la requete : le
// meme mot de passe donne un entete different pour un `PROPFIND` sur un dossier
// et pour un `GET` sur un fichier. L entete ne peut donc pas etre fabrique avant
// de savoir ou la requete va, et c est le client WebDAV qui l assemble.
//
// Deux details de la norme sont souvent negliges et cassent l authentification
// sur les serveurs qui les respectent.
//
// Le premier est le compteur `nc`. Il s incremente a chaque requete portant le
// meme `nonce`, sur huit chiffres hexadecimaux, et un serveur qui detecte un
// rejeu refuse. Le compteur vit donc avec le defi, pas avec la requete.
//
// Le second est l algorithme. La RFC 7616 ajoute SHA-256 a MD5, et les serveurs
// recents annoncent les deux defis dans deux entetes separes. Choisir le plus
// solide est ici la regle, MD5 restant accepte parce que la moitie des NAS en
// service ne proposent que lui.
//

/// Le defi qu un serveur envoie dans son entete `WWW-Authenticate`.
struct DefiDigest: Sendable, Hashable {
    /// Domaine de protection annonce par le serveur.
    let domaine: String

    let nonce: String
    let opaque: String?

    /// Qualite de protection retenue, `auth` ou aucune.
    ///
    /// `auth-int` n est jamais retenue : elle impose de hacher le corps de la
    /// requete, et aucune requete de lecture n en porte. Un serveur qui ne
    /// propose qu elle est traite comme un serveur sans `qop`.
    let qualite: String?

    let algorithme: AlgorithmeDigest

    /// Vrai quand le serveur dit que seul le `nonce` etait perime.
    ///
    /// C est la seule situation ou rejouer la requete a un sens sans que
    /// l utilisateur change quoi que ce soit.
    let perime: Bool
}

/// Fonction de hachage retenue pour un defi.
enum AlgorithmeDigest: Sendable, Hashable {
    case md5
    case md5Session
    case sha256
    case sha256Session

    /// Vrai quand la variante `-sess` est demandee, qui melange le `nonce` et le
    /// `cnonce` dans le premier terme.
    var estDeSession: Bool {
        self == .md5Session || self == .sha256Session
    }

    /// Rang de solidite, pour choisir entre plusieurs defis proposes ensemble.
    var solidite: Int {
        switch self {
        case .md5: 0
        case .md5Session: 1
        case .sha256: 2
        case .sha256Session: 3
        }
    }

    /// Nom a reecrire dans l entete de reponse, tel que le serveur l attend.
    var nom: String {
        switch self {
        case .md5: "MD5"
        case .md5Session: "MD5-sess"
        case .sha256: "SHA-256"
        case .sha256Session: "SHA-256-sess"
        }
    }

    /// Hachage hexadecimal en minuscules, comme la norme l impose.
    func hacher(_ texte: String) -> String {
        let octets = Data(texte.utf8)

        switch self {
        case .md5, .md5Session:
            return Insecure.MD5.hash(data: octets).map { String(format: "%02x", $0) }.joined()
        case .sha256, .sha256Session:
            return SHA256.hash(data: octets).map { String(format: "%02x", $0) }.joined()
        }
    }

    /// Lit le nom d algorithme annonce par un serveur.
    ///
    /// Un nom inconnu rend nul plutot que MD5 par defaut : calculer une reponse
    /// avec la mauvaise fonction produirait un refus que personne ne saurait
    /// expliquer.
    static func depuis(_ nom: String?) -> AlgorithmeDigest? {
        switch nom?.uppercased() {
        case nil, "MD5": .md5
        case "MD5-SESS": .md5Session
        case "SHA-256": .sha256
        case "SHA-256-SESS": .sha256Session
        default: nil
        }
    }
}

// MARK: - Lecture du defi

extension DefiDigest {
    /// Lit tous les defis Digest portes par un entete `WWW-Authenticate`.
    ///
    /// Un serveur recent en annonce plusieurs, separes par des virgules, et
    /// distinguer la virgule qui separe deux defis de celle qui separe deux
    /// parametres du meme defi demande de decouper sur le mot `Digest` lui meme.
    static func tous(dans entete: String) -> [DefiDigest] {
        decouperParSchema(entete).compactMap(depuisLesParametres)
    }

    /// Le defi le plus solide propose par le serveur, ou nul s il n en propose
    /// aucun qui soit exploitable.
    static func meilleur(dans entete: String?) -> DefiDigest? {
        guard let entete else {
            return nil
        }

        return tous(dans: entete).max { gauche, droite in
            gauche.algorithme.solidite < droite.algorithme.solidite
        }
    }

    /// Decoupe un entete en corps de defis Digest, schema retire.
    private static func decouperParSchema(_ entete: String) -> [String] {
        var corps: [String] = []
        var reste = Substring(entete)

        while let debut = reste.range(of: "Digest ", options: [.caseInsensitive]) {
            let apres = reste[debut.upperBound...]

            if let suivant = apres.range(of: ", Digest ", options: [.caseInsensitive]) {
                corps.append(String(apres[..<suivant.lowerBound]))
                reste = apres[suivant.lowerBound...].dropFirst(2)
            } else {
                corps.append(String(apres))
                reste = Substring("")
            }
        }

        return corps
    }

    /// Construit un defi a partir du corps d un entete, sans son schema.
    private static func depuisLesParametres(_ corps: String) -> DefiDigest? {
        let parametres = ParametresDEntete.lire(corps)

        guard let nonce = parametres["nonce"], let algorithme = AlgorithmeDigest.depuis(parametres["algorithm"])
        else {
            return nil
        }

        let qualites = (parametres["qop"] ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }

        return DefiDigest(
            domaine: parametres["realm"] ?? "",
            nonce: nonce,
            opaque: parametres["opaque"],
            qualite: qualites.contains("auth") ? "auth" : nil,
            algorithme: algorithme,
            perime: parametres["stale"]?.lowercased() == "true"
        )
    }
}

/// Lecture des parametres nommes d un entete HTTP.
enum ParametresDEntete {
    /// Lit les couples `nom=valeur` d un entete, guillemets retires.
    ///
    /// Le decoupage ne peut pas se faire par un `split` sur la virgule : une
    /// valeur entre guillemets a le droit d en contenir, et le `qop` en contient
    /// systematiquement des qu un serveur propose `auth,auth-int`.
    static func lire(_ corps: String) -> [String: String] {
        var parametres: [String: String] = [:]
        var nom = ""
        var valeur = ""
        var dansLaValeur = false
        var entreGuillemets = false
        var echappe = false

        func poser() {
            let cle = nom.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            if cle.isEmpty == false {
                parametres[cle] = valeur.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            nom = ""
            valeur = ""
            dansLaValeur = false
        }

        for caractere in corps {
            if echappe {
                valeur.append(caractere)
                echappe = false
            } else if entreGuillemets, caractere == "\\" {
                echappe = true
            } else if caractere == "\"", dansLaValeur {
                entreGuillemets.toggle()
            } else if caractere == "=", dansLaValeur == false {
                dansLaValeur = true
            } else if caractere == ",", entreGuillemets == false {
                poser()
            } else if dansLaValeur {
                valeur.append(caractere)
            } else {
                nom.append(caractere)
            }
        }

        poser()

        return parametres
    }
}

// MARK: - Calcul de la reponse

/// Ce qu il faut pour repondre a un defi Digest sur une requete precise.
struct ReponseDigest: Sendable {
    let compte: String
    let motDePasse: String
    let defi: DefiDigest

    /// Verbe de la requete, en majuscules.
    let methode: String

    /// Chemin et parametres de la requete, tels qu ils partent sur le fil.
    ///
    /// La norme appelle cette valeur `digest-uri`, et elle doit etre identique a
    /// celle de la ligne de requete. Un serveur qui compare les deux refuse une
    /// reponse calculee sur une adresse complete.
    let uri: String

    /// Valeur aleatoire cote client, sur huit chiffres hexadecimaux au moins.
    let cnonce: String

    /// Rang de la requete pour ce `nonce`, a partir de un.
    let compteur: UInt32

    /// La valeur de l entete `Authorization` a poser sur la requete.
    func entete() -> String {
        var champs: [String] = [
            "username=\(Self.cite(compte))",
            "realm=\(Self.cite(defi.domaine))",
            "nonce=\(Self.cite(defi.nonce))",
            "uri=\(Self.cite(uri))",
            "response=\(Self.cite(reponse()))",
            "algorithm=\(defi.algorithme.nom)",
        ]

        if let qualite = defi.qualite {
            champs.append("qop=\(qualite)")
            champs.append("nc=\(Self.compteurHexadecimal(compteur))")
            champs.append("cnonce=\(Self.cite(cnonce))")
        }
        if let opaque = defi.opaque {
            champs.append("opaque=\(Self.cite(opaque))")
        }

        return "Digest " + champs.joined(separator: ", ")
    }

    /// La reponse hachee, seule valeur que le serveur verifie reellement.
    func reponse() -> String {
        let hacher = defi.algorithme.hacher
        let secondTerme = hacher("\(methode):\(uri)")

        guard let qualite = defi.qualite else {
            return hacher("\(premierTerme()):\(defi.nonce):\(secondTerme)")
        }

        let milieu = "\(defi.nonce):\(Self.compteurHexadecimal(compteur)):\(cnonce):\(qualite)"

        return hacher("\(premierTerme()):\(milieu):\(secondTerme)")
    }

    /// Le premier terme, que la norme note HA1.
    private func premierTerme() -> String {
        let hacher = defi.algorithme.hacher
        let base = hacher("\(compte):\(defi.domaine):\(motDePasse)")

        guard defi.algorithme.estDeSession else {
            return base
        }

        return hacher("\(base):\(defi.nonce):\(cnonce)")
    }

    /// Le compteur sur huit chiffres hexadecimaux, comme la norme l impose.
    static func compteurHexadecimal(_ valeur: UInt32) -> String {
        String(format: "%08x", valeur)
    }

    /// Entoure une valeur de guillemets, en echappant ceux qu elle contient.
    private static func cite(_ valeur: String) -> String {
        let echappee = valeur
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        return "\"\(echappee)\""
    }
}
