import Foundation

//
// EmpreinteMd4
//
// MD4, ecrit ici parce qu aucune bibliotheque du systeme ne le propose plus.
//
// Il ne sert qu a une chose, et il ne servira jamais a rien d autre : NTLM
// definit l empreinte d un mot de passe comme le MD4 de son ecriture en UTF 16
// petit boutien. Ce n est pas un choix, c est la norme du protocole SMB, et
// aucun serveur n acceptera autre chose. La fonction est cassee depuis les
// annees quatre vingt dix, ce qui n a pas d importance ici : elle n est jamais
// employee pour proteger quoi que ce soit, seulement pour reproduire une valeur
// que le serveur calcule de son cote. Le nom du type le dit, et rien dans le
// projet ne doit l employer ailleurs.
//
// L implementation est la description directe de la RFC 1320, sans table ni
// deroulage : trois tours de seize operations, sur un etat de quatre mots.
//

/// L empreinte MD4, reservee au calcul de l empreinte de mot de passe NTLM.
enum EmpreinteMd4 {
    /// Rend les seize octets de l empreinte.
    static func calculer(_ message: Data) -> Data {
        var etat: [UInt32] = [0x6745_2301, 0xEFCD_AB89, 0x98BA_DCFE, 0x1032_5476]

        for bloc in blocs(de: message) {
            transformer(&etat, bloc: bloc)
        }

        var empreinte = Data()

        for mot in etat {
            empreinte.append(UInt8(mot & 0xFF))
            empreinte.append(UInt8(mot >> 8 & 0xFF))
            empreinte.append(UInt8(mot >> 16 & 0xFF))
            empreinte.append(UInt8(mot >> 24 & 0xFF))
        }

        return empreinte
    }

    /// Decoupe le message en blocs de seize mots, bourrage compris.
    ///
    /// Le bourrage est celui de la norme : un octet a un, des zeros jusqu a huit
    /// octets de la fin du bloc, puis la longueur en bits sur soixante quatre
    /// bits petit boutien.
    private static func blocs(de message: Data) -> [[UInt32]] {
        var complet = message
        complet.append(0x80)

        while complet.count % 64 != 56 {
            complet.append(0)
        }

        let bits = UInt64(message.count) &* 8

        for decalage in stride(from: 0, to: 64, by: 8) {
            complet.append(UInt8(bits >> UInt64(decalage) & 0xFF))
        }

        return stride(from: 0, to: complet.count, by: 64).map { debut in
            (0..<16).map { rang in
                let position = complet.startIndex + debut + rang * 4

                return UInt32(complet[position])
                    | UInt32(complet[position + 1]) << 8
                    | UInt32(complet[position + 2]) << 16
                    | UInt32(complet[position + 3]) << 24
            }
        }
    }

    /// Applique les trois tours de la norme a un bloc.
    private static func transformer(_ etat: inout [UInt32], bloc: [UInt32]) {
        var premier = etat[0]
        var deuxieme = etat[1]
        var troisieme = etat[2]
        var quatrieme = etat[3]

        for rang in 0..<16 {
            let melange = premier
                &+ (deuxieme & troisieme | ~deuxieme & quatrieme)
                &+ bloc[rang]
            (premier, deuxieme, troisieme, quatrieme) = (
                quatrieme, tourner(melange, de: decalagesDuPremierTour[rang % 4]), deuxieme, troisieme
            )
        }
        for rang in 0..<16 {
            let melange = premier
                &+ (deuxieme & troisieme | deuxieme & quatrieme | troisieme & quatrieme)
                &+ bloc[ordreDuDeuxiemeTour[rang]]
                &+ 0x5A82_7999
            (premier, deuxieme, troisieme, quatrieme) = (
                quatrieme, tourner(melange, de: decalagesDuDeuxiemeTour[rang % 4]), deuxieme, troisieme
            )
        }
        for rang in 0..<16 {
            let melange = premier
                &+ (deuxieme ^ troisieme ^ quatrieme)
                &+ bloc[ordreDuTroisiemeTour[rang]]
                &+ 0x6ED9_EBA1
            (premier, deuxieme, troisieme, quatrieme) = (
                quatrieme, tourner(melange, de: decalagesDuTroisiemeTour[rang % 4]), deuxieme, troisieme
            )
        }

        etat[0] = etat[0] &+ premier
        etat[1] = etat[1] &+ deuxieme
        etat[2] = etat[2] &+ troisieme
        etat[3] = etat[3] &+ quatrieme
    }

    private static func tourner(_ valeur: UInt32, de decalage: UInt32) -> UInt32 {
        valeur << decalage | valeur >> (32 - decalage)
    }

    private static let decalagesDuPremierTour: [UInt32] = [3, 7, 11, 19]
    private static let decalagesDuDeuxiemeTour: [UInt32] = [3, 5, 9, 13]
    private static let decalagesDuTroisiemeTour: [UInt32] = [3, 9, 11, 15]

    private static let ordreDuDeuxiemeTour = [0, 4, 8, 12, 1, 5, 9, 13, 2, 6, 10, 14, 3, 7, 11, 15]
    private static let ordreDuTroisiemeTour = [0, 8, 4, 12, 2, 10, 6, 14, 1, 9, 5, 13, 3, 11, 7, 15]
}
