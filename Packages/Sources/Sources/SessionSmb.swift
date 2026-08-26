import Core
import CryptoKit
import Foundation

//
// SessionSmb
//
// L ouverture de session SMB, et l echange de trames qui la suit.
//
// Trois choses se jouent ici, et elles sont dans l ordre ou elles arrivent sur
// le fil.
//
// La negociation d abord. Elle fixe le dialecte et, surtout, elle dit si le
// serveur exige la signature des trames. Ce dernier point n est pas un detail de
// configuration : un serveur qui l exige refuse toute trame non signee apres
// l ouverture de session, avec un code que rien ne distingue d un refus de
// droits, et le diagnostic devient impossible.
//
// L ouverture de session ensuite, en deux echanges NTLM. Le premier annonce ce
// que le client sait faire et recoit un defi ; le second rend la preuve calculee
// sur ce defi. La cle de signature n est retenue qu apres l acceptation :
// signer avec une cle issue d une preuve refusee ferait echouer la trame
// suivante sur un code de signature invalide, qui ne dit rien du vrai probleme.
//
// L encadrement enfin. Sur le port 445, chaque trame est precedee de quatre
// octets dont le premier est toujours nul et les trois autres portent la
// longueur en gros boutien. C est un reste de l encapsulation NetBIOS, que le
// port direct a conserve, et l oublier decale toute la lecture.
//

extension PartageSmb {
    // MARK: Ouverture

    /// Negocie, ouvre la session et se connecte a l arborescence, une fois.
    func preparer() async throws {
        guard ouverte == false else {
            return
        }

        try await canal.ouvrir()
        try await negocier()
        try await ouvrirLaSession()
        try await connecterLArborescence()

        ouverte = true
    }

    private func negocier() async throws {
        var corps = EcritureSmb2()
        corps.entier16(36)
        corps.entier16(UInt16(Self.dialectes.count))
        corps.entier16(1)
        corps.entier16(0)
        corps.entier32(0)
        corps.fixe(Data(repeating: 0, count: 16))
        corps.entier64(0)

        for dialecte in Self.dialectes {
            corps.entier16(dialecte)
        }

        let reponse = try await echanger(.negocier, corps: corps.octets)

        var lecture = LectureSmb2(reponse.corps)

        guard lecture.entier16() == 65,
              let mode = lecture.entier16(),
              lecture.sauter(4),
              lecture.sauter(16),
              lecture.sauter(4),
              lecture.sauter(4),
              let lectureMaximale = lecture.entier32()
        else {
            throw ErreurReseau.reponseIllisible
        }

        lectureMaximaleNegociee = max(1, min(lectureMaximale, Self.lectureMaximale))
        signatureReclamee = mode & Self.signatureExigee != 0
    }

    private func ouvrirLaSession() async throws {
        let premiere = try await envoyerLOuvertureDeSession(AuthentificationNtlm.negociation())
        session = premiere.entete.identifiantDeSession

        guard premiere.entete.statut == StatutSmb2.traitementEnCours else {
            // Un serveur qui accepte du premier coup n a demande aucune preuve.
            // Cela n arrive que sur un partage ouvert a tous.
            return
        }
        guard let defi = AuthentificationNtlm.defi(dans: premiere.tampon) else {
            throw ErreurReseau.reponseIllisible
        }

        let preuve = preuveNtlm(pour: defi)
        let seconde = try await envoyerLOuvertureDeSession(preuve.message)

        guard seconde.entete.statut == StatutSmb2.succes else {
            throw StatutSmb2.traduire(seconde.entete.statut)
        }

        if signatureReclamee {
            cleDeSignature = preuve.cleDeSession
        }
    }

    /// Calcule la preuve NTLM a partir des identifiants saisis.
    private func preuveNtlm(pour defi: DefiNtlm) -> AuthentificationNtlm.Preuve {
        let compte: String
        let motDePasse: String
        let domaine: String

        switch identifiants {
        case .invite:
            compte = ""
            motDePasse = ""
            domaine = ""
        case let .compte(saisi, secret, sonDomaine):
            compte = saisi
            motDePasse = secret
            domaine = sonDomaine
        }

        return AuthentificationNtlm.preuve(
            CompteNtlm(
                compte: compte,
                motDePasse: motDePasse,
                domaine: domaine,
                posteDeTravail: posteDeTravail
            ),
            defi: defi,
            defiDuClient: defiDuClient(),
            horodatage: horodatage()
        )
    }

    /// Envoie un message NTLM dans une ouverture de session.
    private func envoyerLOuvertureDeSession(_ jeton: Data) async throws -> ReponseSmb2 {
        var corps = EcritureSmb2()
        corps.entier16(25)
        corps.entier8(0)
        corps.entier8(1)
        corps.entier32(0)
        corps.entier32(0)
        corps.entier16(UInt16(EnTeteSmb2.taille + 24))
        corps.entier16(UInt16(jeton.count))
        corps.entier64(0)
        corps.fixe(jeton)

        let reponse = try await echanger(
            .ouvrirSession,
            corps: corps.octets,
            statutsAcceptes: [StatutSmb2.traitementEnCours]
        )

        var lecture = LectureSmb2(reponse.corps)

        guard lecture.entier16() == 9,
              lecture.sauter(2),
              let position = lecture.entier16(),
              let longueur = lecture.entier16()
        else {
            throw ErreurReseau.reponseIllisible
        }

        let tampon = lecture.tranche(a: Int(position) - EnTeteSmb2.taille, longueur: Int(longueur)) ?? Data()

        return ReponseSmb2(entete: reponse.entete, corps: reponse.corps, tampon: tampon)
    }

    private func connecterLArborescence() async throws {
        let chemin = AuthentificationNtlm.utf16("\\\\\(hote)\\\(partage)")

        var corps = EcritureSmb2()
        corps.entier16(9)
        corps.entier16(0)
        corps.entier16(UInt16(EnTeteSmb2.taille + 8))
        corps.entier16(UInt16(chemin.count))
        corps.fixe(chemin)

        let reponse = try await echanger(.connecterArborescence, corps: corps.octets)
        arborescence = reponse.entete.identifiantDArborescence
    }

    // MARK: Echanges

    /// Envoie une commande et rend la reponse, statut verifie.
    ///
    /// - Parameter statutsAcceptes: statuts qui ne sont pas des erreurs pour
    ///   cette commande. L ouverture de session en a un, le listage aussi, et la
    ///   lecture en fin de fichier egalement.
    func echanger(
        _ commande: CommandeSmb2,
        corps: Data,
        statutsAcceptes: Set<UInt32> = []
    ) async throws -> ReponseSmb2 {
        try Task.checkCancellation()

        var entete = EnTeteSmb2(commande: commande)
        entete.identifiantDeMessage = prochainMessage
        entete.identifiantDeSession = session
        entete.identifiantDArborescence = commande == .connecterArborescence ? 0 : arborescence
        prochainMessage += 1

        var trame = entete.octets() + corps

        if let cleDeSignature {
            trame = Self.signer(trame, avec: cleDeSignature)
        }

        try await canal.envoyer(Self.encadrer(trame))

        let recue = try await recevoirUneTrame()

        guard let enteteRecue = EnTeteSmb2.lire(recue) else {
            throw ErreurReseau.reponseIllisible
        }
        guard enteteRecue.statut == StatutSmb2.succes || statutsAcceptes.contains(enteteRecue.statut) else {
            throw StatutSmb2.traduire(enteteRecue.statut)
        }

        return ReponseSmb2(
            entete: enteteRecue,
            corps: recue.subdata(in: (recue.startIndex + EnTeteSmb2.taille)..<recue.endIndex)
        )
    }

    /// Pose la longueur de la trame en tete, comme le veut SMB sur TCP direct.
    static func encadrer(_ trame: Data) -> Data {
        var cadre = Data()
        cadre.append(0)
        cadre.append(UInt8(trame.count >> 16 & 0xFF))
        cadre.append(UInt8(trame.count >> 8 & 0xFF))
        cadre.append(UInt8(trame.count & 0xFF))
        cadre.append(trame)

        return cadre
    }

    /// Lit une trame complete, cadre compris.
    private func recevoirUneTrame() async throws -> Data {
        let cadre = try await canal.recevoir(exactement: 4)

        guard cadre.count == 4 else {
            throw ErreurReseau.reponseTronquee
        }

        let debut = cadre.startIndex
        let longueur = Int(cadre[debut + 1]) << 16 | Int(cadre[debut + 2]) << 8 | Int(cadre[debut + 3])

        guard longueur >= EnTeteSmb2.taille else {
            throw ErreurReseau.reponseIllisible
        }

        return try await canal.recevoir(exactement: longueur)
    }

    /// Signe une trame, champ de signature mis a zero pendant le calcul.
    static func signer(_ trame: Data, avec cle: Data) -> Data {
        var signee = trame
        let debutDuDrapeau = signee.startIndex + 16
        let debutDeLaSignature = signee.startIndex + 48

        // Le drapeau de trame signee doit etre pose avant le calcul : il fait
        // partie des octets couverts par la signature.
        signee[debutDuDrapeau] |= UInt8(EnTeteSmb2.drapeauSignee)
        signee.replaceSubrange(debutDeLaSignature..<(debutDeLaSignature + 16), with: Data(repeating: 0, count: 16))

        var empreinte = HMAC<SHA256>(key: SymmetricKey(data: cle))
        empreinte.update(data: signee)

        let calculee = Data(empreinte.finalize()).prefix(16)
        signee.replaceSubrange(debutDeLaSignature..<(debutDeLaSignature + 16), with: calculee)

        return signee
    }
}
