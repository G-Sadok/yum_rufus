import Core
import Foundation

//
// Smb2
//
// Les trames du protocole SMB version deux, celles que le partage emploie et pas
// une de plus.
//
// SMB est un protocole a en tete fixe : soixante quatre octets qui disent la
// commande, le numero de message, la session et l arborescence, puis un corps
// dont la disposition depend de la commande. Chaque corps commence par sa propre
// taille, et cette taille est une constante du protocole, pas une mesure. Un
// serveur refuse une commande dont la taille annoncee ne correspond pas a ce que
// la norme prevoit, ce qui rend ces constantes obligatoires et non decoratives.
//
// Une bizarrerie du format merite d etre dite parce qu elle a coule bien des
// implementations. La taille annoncee vaut la taille de la structure fixe plus
// un, quand la commande porte un tampon variable. La commande de lecture annonce
// quarante neuf pour quarante huit octets fixes, et la reponse dix sept pour
// seize. Ce n est pas une erreur de la norme, c est sa facon de dire qu un
// tampon suit, et un client qui annonce la vraie taille se fait refuser.
//
// Le dialecte negocie est volontairement borne aux versions deux zero deux et
// deux un. La version trois un un impose un controle d integrite de la
// negociation et un chiffrement dont la mise en oeuvre correcte demande bien
// plus que ce que la lecture d un CBZ justifie, et un dialecte annonce mais mal
// tenu est pire que non annonce.
//

/// Les commandes SMB version deux employees par le partage.
enum CommandeSmb2: UInt16, Sendable {
    case negocier = 0x0000
    case ouvrirSession = 0x0001
    case fermerSession = 0x0002
    case connecterArborescence = 0x0003
    case deconnecterArborescence = 0x0004
    case creer = 0x0005
    case fermer = 0x0006
    case lire = 0x0008
    case interrogerDossier = 0x000E
}

/// Les codes de statut que le partage sait nommer.
enum StatutSmb2 {
    static let succes: UInt32 = 0x0000_0000
    static let traitementEnCours: UInt32 = 0xC000_0016
    static let echecDOuverture: UInt32 = 0xC000_006D
    static let accesRefuse: UInt32 = 0xC000_0022
    static let objetIntrouvable: UInt32 = 0xC000_0034
    static let cheminIntrouvable: UInt32 = 0xC000_003A
    static let plusAucunFichier: UInt32 = 0x8000_0006
    static let finDeFichier: UInt32 = 0xC000_0011

    /// Traduit un statut en cas nomme du domaine.
    static func traduire(_ statut: UInt32) -> ErreurReseau {
        switch statut {
        case echecDOuverture: .authentificationRefusee
        case accesRefuse: .accesRefuse
        case objetIntrouvable, cheminIntrouvable: .ressourceIntrouvable
        default: .reponseInattendue(code: Int(bitPattern: UInt(statut)))
        }
    }
}

/// L en tete de soixante quatre octets qui ouvre toute trame SMB version deux.
struct EnTeteSmb2: Sendable, Hashable {
    static let taille = 64
    static let signature = Data([0xFE, 0x53, 0x4D, 0x42])

    /// Drapeau pose sur une trame signee.
    static let drapeauSignee: UInt32 = 0x0000_0008

    var commande: CommandeSmb2
    var statut: UInt32 = 0
    var credits: UInt16 = 1
    var drapeaux: UInt32 = 0
    var identifiantDeMessage: UInt64 = 0
    var identifiantDArborescence: UInt32 = 0
    var identifiantDeSession: UInt64 = 0
    var signature: Data = .init(repeating: 0, count: 16)

    /// Les soixante quatre octets de l en tete.
    func octets() -> Data {
        var ecriture = EcritureSmb2()
        ecriture.fixe(EnTeteSmb2.signature)
        ecriture.entier16(64)
        ecriture.entier16(1)
        ecriture.entier32(statut)
        ecriture.entier16(commande.rawValue)
        ecriture.entier16(credits)
        ecriture.entier32(drapeaux)
        ecriture.entier32(0)
        ecriture.entier64(identifiantDeMessage)
        ecriture.entier32(0)
        ecriture.entier32(identifiantDArborescence)
        ecriture.entier64(identifiantDeSession)
        ecriture.fixe(signature)

        return ecriture.octets
    }

    /// Lit l en tete d une trame recue.
    static func lire(_ trame: Data) -> EnTeteSmb2? {
        guard trame.count >= taille else {
            return nil
        }

        var lecture = LectureSmb2(trame)

        guard lecture.fixe(4) == signature,
              lecture.sauter(4),
              let statut = lecture.entier32(),
              let brute = lecture.entier16(),
              let commande = CommandeSmb2(rawValue: brute),
              let credits = lecture.entier16(),
              let drapeaux = lecture.entier32(),
              lecture.sauter(4),
              let message = lecture.entier64(),
              lecture.sauter(4),
              let arborescence = lecture.entier32(),
              let session = lecture.entier64(),
              let signature = lecture.fixe(16)
        else {
            return nil
        }

        return EnTeteSmb2(
            commande: commande,
            statut: statut,
            credits: credits,
            drapeaux: drapeaux,
            identifiantDeMessage: message,
            identifiantDArborescence: arborescence,
            identifiantDeSession: session,
            signature: signature
        )
    }
}

/// Une trame recue, en tete et corps separes.
///
/// Le tampon est le contenu variable que certaines commandes joignent a leur
/// corps fixe, deja extrait a la position que la reponse annonce.
struct ReponseSmb2: Sendable {
    let entete: EnTeteSmb2
    let corps: Data
    var tampon: Data = .init()
}

/// Ce que l ouverture d un fichier ou d un dossier rend.
struct OuvertureSmb2: Sendable {
    let descripteur: Data
    let taille: UInt64

    /// Date de derniere ecriture, comptee comme Windows la compte.
    let derniereEcriture: UInt64

    let estDossier: Bool
}

// MARK: - Ecriture et lecture

/// Ecriture d octets en petit boutien, la convention de SMB.
struct EcritureSmb2 {
    private var contenu = Data()

    /// Les octets ecrits jusqu ici.
    var octets: Data {
        contenu
    }

    mutating func entier8(_ valeur: UInt8) {
        contenu.append(valeur)
    }

    mutating func entier16(_ valeur: UInt16) {
        contenu.append(UInt8(valeur & 0xFF))
        contenu.append(UInt8(valeur >> 8 & 0xFF))
    }

    mutating func entier32(_ valeur: UInt32) {
        entier16(UInt16(valeur & 0xFFFF))
        entier16(UInt16(valeur >> 16 & 0xFFFF))
    }

    mutating func entier64(_ valeur: UInt64) {
        entier32(UInt32(valeur & 0xFFFF_FFFF))
        entier32(UInt32(valeur >> 32 & 0xFFFF_FFFF))
    }

    mutating func fixe(_ octets: Data) {
        contenu.append(octets)
    }
}

/// Lecture d octets en petit boutien.
struct LectureSmb2 {
    private let octets: Data
    private(set) var position: Int

    init(_ octets: Data, a position: Int = 0) {
        self.octets = octets
        self.position = position
    }

    var reste: Int {
        max(0, octets.count - position)
    }

    mutating func entier8() -> UInt8? {
        fixe(1).map { $0[$0.startIndex] }
    }

    mutating func entier16() -> UInt16? {
        guard let contenu = fixe(2) else {
            return nil
        }

        let debut = contenu.startIndex

        return UInt16(contenu[debut]) | UInt16(contenu[debut + 1]) << 8
    }

    mutating func entier32() -> UInt32? {
        guard let bas = entier16(), let haut = entier16() else {
            return nil
        }

        return UInt32(bas) | UInt32(haut) << 16
    }

    mutating func entier64() -> UInt64? {
        guard let bas = entier32(), let haut = entier32() else {
            return nil
        }

        return UInt64(bas) | UInt64(haut) << 32
    }

    mutating func fixe(_ longueur: Int) -> Data? {
        guard longueur >= 0, reste >= longueur else {
            return nil
        }

        let debut = octets.startIndex + position
        position += longueur

        return octets.subdata(in: debut..<(debut + longueur))
    }

    mutating func sauter(_ longueur: Int) -> Bool {
        guard reste >= longueur else {
            return false
        }

        position += longueur

        return true
    }

    /// Rend une tranche a une position absolue, sans deplacer le curseur.
    func tranche(a position: Int, longueur: Int) -> Data? {
        guard position >= 0, longueur >= 0, position + longueur <= octets.count else {
            return nil
        }

        let debut = octets.startIndex + position

        return octets.subdata(in: debut..<(debut + longueur))
    }
}

// MARK: - Noms

/// Traduction entre les noms de SMB et ceux du reste du projet.
enum NomsSmb2 {
    /// Un chemin de partage, ecrit avec les barres obliques inverses de SMB.
    static func chemin(_ relatif: String) -> String {
        relatif
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .replacingOccurrences(of: "/", with: "\\")
    }

    /// Un nom rendu par le serveur, ramene a la convention du projet.
    static func nom(_ brut: String) -> String {
        brut.replacingOccurrences(of: "\\", with: "/")
    }

    /// Decode une chaine SMB, toujours ecrite en UTF 16 petit boutien.
    ///
    /// Un nom qui ne se decode pas rend la chaine vide plutot que nul : arreter
    /// le listage d un dossier entier pour un nom mal encode ferait disparaitre
    /// les series voisines, qui n y sont pour rien.
    static func texte(_ octets: Data) -> String {
        String(bytes: octets, encoding: .utf16LittleEndian) ?? ""
    }

    /// Traduit un instant Windows, compte en unites de cent nanosecondes depuis
    /// 1601, en date du systeme.
    ///
    /// Zero veut dire inconnu et non le premier janvier 1601 : un serveur qui ne
    /// tient pas une date la laisse a zero, et la rendre telle quelle ferait
    /// classer tous ses chapitres comme les plus anciens de la bibliotheque.
    static func date(_ windows: UInt64) -> Date? {
        guard windows > 0 else {
            return nil
        }

        return Date(timeIntervalSince1970: Double(windows) / 10_000_000 - secondesEntre1601Et1970)
    }

    /// Ecart entre l epoque de Windows et celle du systeme, en secondes.
    static let secondesEntre1601Et1970: Double = 11_644_473_600
}
