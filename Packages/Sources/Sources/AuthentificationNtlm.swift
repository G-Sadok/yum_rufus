import CryptoKit
import Foundation

//
// AuthentificationNtlm
//
// NTLM version deux, la seule authentification qu un partage SMB grand public
// accepte sans annuaire.
//
// L echange tient en trois messages. Le client annonce ce qu il sait faire, le
// serveur repond par un defi de huit octets accompagne de la description de son
// domaine, et le client rend une preuve calculee sur ce defi. Le mot de passe ne
// traverse jamais le fil, et il ne peut pas s en deduire : c est tout l interet
// du procede, et c est ce qui distingue la version deux de la premiere, qui
// laissait retrouver le mot de passe hors ligne en quelques heures.
//
// Deux details de la norme decident du reste.
//
// Le premier est que la preuve couvre les informations de domaine renvoyees par
// le serveur, telles quelles et dans l ordre. Les recopier au lieu de les
// reconstruire n est pas de la paresse : un serveur qui y ajoute un horodatage
// ou un nom de machine verifie que le client les a bien rendues, et une preuve
// calculee sur une reconstruction est refusee.
//
// Le second est que la version une n est plus proposee du tout. Aucune reponse
// LM n est calculee, le champ part rempli de zeros. Les serveurs qui exigeraient
// la version une sont ceux qu il ne faut de toute facon pas joindre.
//

/// Qui le client dit etre, dans l echange NTLM.
///
/// Les quatre valeurs voyagent ensemble parce que la norme les traite ensemble :
/// le compte et le domaine entrent tous deux dans le calcul de l empreinte, et
/// le poste de travail est recopie dans le meme message. Les passer separement a
/// chaque etape ferait quatre occasions d en oublier une.
struct CompteNtlm: Sendable, Hashable {
    let compte: String
    let motDePasse: String
    let domaine: String
    let posteDeTravail: String
}

/// Ce que le serveur a repondu au premier message NTLM.
struct DefiNtlm: Sendable, Hashable {
    /// Les huit octets de defi.
    let defi: Data

    /// Les informations de domaine, a recopier telles quelles dans la preuve.
    let informations: Data

    /// Les drapeaux que le serveur a retenus.
    let drapeaux: UInt32
}

/// Les trois messages de l echange NTLM version deux.
enum AuthentificationNtlm {
    /// Signature qui ouvre les trois messages.
    static let signature = Data("NTLMSSP\u{0}".utf8)

    /// Drapeaux annonces par le client.
    ///
    /// Unicode, demande du nom de domaine, NTLM, signature systematique et
    /// securite de session etendue. Rien de plus : chaque drapeau superflu
    /// engage le client a fournir quelque chose, et un drapeau d echange de cle
    /// annonce non tenu fait echouer la session sans message clair.
    static let drapeauxDuClient: UInt32 = 0x0000_0001
        | 0x0000_0004
        | 0x0000_0200
        | 0x0000_8000
        | 0x0008_0000

    // MARK: Premier message

    /// Le message qui annonce ce que le client sait faire.
    static func negociation() -> Data {
        var message = Data()
        message.append(signature)
        message.append(entier32(1))
        message.append(entier32(drapeauxDuClient))

        // Domaine et poste de travail vides. Les annoncer n apporte rien : le
        // serveur renvoie de toute facon son propre domaine dans son defi.
        message.append(champ(longueur: 0, position: 32))
        message.append(champ(longueur: 0, position: 32))

        return message
    }

    // MARK: Deuxieme message

    /// Lit le defi du serveur.
    ///
    /// Le message est cherche par sa signature plutot que lu depuis le debut du
    /// tampon : un serveur qui negocie par SPNEGO l enveloppe dans une structure
    /// ASN.1 dont la longueur varie, et lire a une position fixe rendrait huit
    /// octets de defi qui n en sont pas.
    static func defi(dans tampon: Data) -> DefiNtlm? {
        guard let debut = position(deLaSignature: tampon) else {
            return nil
        }

        let message = tampon.subdata(in: debut..<tampon.endIndex)

        guard message.count >= 48, entier32(message, a: 8) == 2 else {
            return nil
        }
        guard let defi = tranche(message, a: 24, longueur: 8) else {
            return nil
        }

        let drapeaux = entier32(message, a: 20) ?? 0
        let informations = champLu(message, a: 40) ?? Data()

        return DefiNtlm(defi: defi, informations: informations, drapeaux: drapeaux)
    }

    // MARK: Troisieme message

    /// Ce que le troisieme message porte, et la cle de session qui en decoule.
    struct Preuve: Sendable, Hashable {
        /// Le message a envoyer au serveur.
        let message: Data

        /// La cle dont derive la signature des trames suivantes.
        let cleDeSession: Data
    }

    /// Calcule la preuve a rendre au serveur.
    ///
    /// - Parameters:
    ///   - defiDuClient: huit octets tires au hasard. Injectes pour que les
    ///     tests puissent comparer la preuve a une valeur calculee a part.
    ///   - horodatage: instant en unites de cent nanosecondes depuis 1601, tel
    ///     que Windows les compte. Injecte pour la meme raison.
    static func preuve(
        _ identite: CompteNtlm,
        defi: DefiNtlm,
        defiDuClient: Data,
        horodatage: UInt64
    ) -> Preuve {
        let empreinte = empreinteDeVersionDeux(
            compte: identite.compte,
            motDePasse: identite.motDePasse,
            domaine: identite.domaine
        )
        let temporaire = blocTemporaire(
            horodatage: horodatage,
            defiDuClient: defiDuClient,
            informations: defi.informations
        )
        let attestation = hmacMd5(cle: empreinte, message: defi.defi + temporaire)
        let reponse = attestation + temporaire

        return Preuve(
            message: troisiemeMessage(identite, reponse: reponse),
            cleDeSession: hmacMd5(cle: empreinte, message: attestation)
        )
    }

    /// L empreinte de la version deux, qui lie le mot de passe au compte.
    static func empreinteDeVersionDeux(compte: String, motDePasse: String, domaine: String) -> Data {
        let empreinteDuMotDePasse = EmpreinteMd4.calculer(utf16(motDePasse))

        return hmacMd5(
            cle: empreinteDuMotDePasse,
            message: utf16(compte.uppercased() + domaine)
        )
    }

    /// Le bloc que la norme appelle temporaire, et que la preuve recopie.
    static func blocTemporaire(horodatage: UInt64, defiDuClient: Data, informations: Data) -> Data {
        var bloc = Data([0x01, 0x01, 0x00, 0x00])
        bloc.append(entier32(0))
        bloc.append(entier64(horodatage))
        bloc.append(defiDuClient)
        bloc.append(entier32(0))
        bloc.append(informations)
        bloc.append(entier32(0))

        return bloc
    }

    /// Assemble le troisieme message autour de sa charge utile.
    private static func troisiemeMessage(_ identite: CompteNtlm, reponse: Data) -> Data {
        let octetsDuDomaine = utf16(identite.domaine)
        let octetsDuCompte = utf16(identite.compte)
        let octetsDuPoste = utf16(identite.posteDeTravail)

        // La charge utile commence apres l en tete, qui pese soixante quatre
        // octets tant qu aucune version ni empreinte de message n est annoncee.
        let debut = 64
        let positionLm = debut
        let positionNt = positionLm + 24
        let positionDomaine = positionNt + reponse.count
        let positionCompte = positionDomaine + octetsDuDomaine.count
        let positionPoste = positionCompte + octetsDuCompte.count
        let positionCle = positionPoste + octetsDuPoste.count

        var message = Data()
        message.append(signature)
        message.append(entier32(3))
        message.append(champ(longueur: 24, position: positionLm))
        message.append(champ(longueur: reponse.count, position: positionNt))
        message.append(champ(longueur: octetsDuDomaine.count, position: positionDomaine))
        message.append(champ(longueur: octetsDuCompte.count, position: positionCompte))
        message.append(champ(longueur: octetsDuPoste.count, position: positionPoste))
        message.append(champ(longueur: 0, position: positionCle))
        message.append(entier32(drapeauxDuClient))

        // La reponse de version une n est pas calculee. Vingt quatre zeros
        // disent au serveur qu il n y en a pas, ce que la version deux autorise.
        message.append(Data(repeating: 0, count: 24))
        message.append(reponse)
        message.append(octetsDuDomaine)
        message.append(octetsDuCompte)
        message.append(octetsDuPoste)

        return message
    }

    // MARK: Outils

    /// Ecrit un couple longueur et position, tel que NTLM les enchaine.
    private static func champ(longueur: Int, position: Int) -> Data {
        var champ = Data()
        champ.append(entier16(UInt16(longueur)))
        champ.append(entier16(UInt16(longueur)))
        champ.append(entier32(UInt32(position)))

        return champ
    }

    /// Lit le contenu designe par un couple longueur et position.
    private static func champLu(_ message: Data, a position: Int) -> Data? {
        guard let longueur = entier16(message, a: position), let debut = entier32(message, a: position + 4) else {
            return nil
        }

        return tranche(message, a: Int(debut), longueur: Int(longueur))
    }

    private static func tranche(_ message: Data, a position: Int, longueur: Int) -> Data? {
        guard position >= 0, longueur >= 0, position + longueur <= message.count else {
            return nil
        }

        let debut = message.startIndex + position

        return message.subdata(in: debut..<(debut + longueur))
    }

    /// Cherche la signature NTLM dans un tampon, enveloppe ou non.
    private static func position(deLaSignature tampon: Data) -> Int? {
        guard tampon.count >= signature.count else {
            return nil
        }

        for debut in 0...(tampon.count - signature.count) {
            let position = tampon.startIndex + debut

            if tampon.subdata(in: position..<(position + signature.count)) == signature {
                return position
            }
        }

        return nil
    }

    /// Une chaine en UTF 16 petit boutien, seule forme que NTLM accepte.
    static func utf16(_ texte: String) -> Data {
        var octets = Data()

        for unite in texte.utf16 {
            octets.append(UInt8(unite & 0xFF))
            octets.append(UInt8(unite >> 8 & 0xFF))
        }

        return octets
    }

    static func hmacMd5(cle: Data, message: Data) -> Data {
        var empreinte = HMAC<Insecure.MD5>(key: SymmetricKey(data: cle))
        empreinte.update(data: message)

        return Data(empreinte.finalize())
    }

    private static func entier16(_ valeur: UInt16) -> Data {
        Data([UInt8(valeur & 0xFF), UInt8(valeur >> 8 & 0xFF)])
    }

    private static func entier32(_ valeur: UInt32) -> Data {
        Data([
            UInt8(valeur & 0xFF),
            UInt8(valeur >> 8 & 0xFF),
            UInt8(valeur >> 16 & 0xFF),
            UInt8(valeur >> 24 & 0xFF),
        ])
    }

    private static func entier64(_ valeur: UInt64) -> Data {
        var octets = Data()

        for decalage in stride(from: 0, to: 64, by: 8) {
            octets.append(UInt8(valeur >> UInt64(decalage) & 0xFF))
        }

        return octets
    }

    private static func entier16(_ message: Data, a position: Int) -> UInt16? {
        guard let octets = tranche(message, a: position, longueur: 2) else {
            return nil
        }

        return UInt16(octets[octets.startIndex]) | UInt16(octets[octets.startIndex + 1]) << 8
    }

    private static func entier32(_ message: Data, a position: Int) -> UInt32? {
        guard let octets = tranche(message, a: position, longueur: 4) else {
            return nil
        }

        let debut = octets.startIndex

        return UInt32(octets[debut])
            | UInt32(octets[debut + 1]) << 8
            | UInt32(octets[debut + 2]) << 16
            | UInt32(octets[debut + 3]) << 24
    }
}
