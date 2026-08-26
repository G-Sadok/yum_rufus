import Foundation

//
// ArchiveSynthetique
//
// Un CBZ de deux cents mega octets qui n existe nulle part.
//
// Le premier critere de la fonctionnalite se mesure sur un conteneur de deux
// cents mega octets. Le poser dans le depot est exclu, le fabriquer sur disque
// au debut du test le serait presque autant : deux cents mega octets ecrits puis
// relus a chaque execution de la suite couteraient plus cher que tout le reste
// des tests reunis, et ne prouveraient rien de plus.
//
// Cette archive rend donc les octets d un ZIP valide sans jamais en tenir plus
// d une page en memoire. Elle connait sa disposition, en tetes locaux, donnees,
// index central, enregistrement de fin, et fabrique n importe quelle plage a la
// demande. C est exactement ce qu un serveur de fichiers fait, ce qui en fait le
// double juste pour mesurer ce qui traverse le reseau.
//
// Toutes les pages portent le meme contenu, et ce n est pas une facilite : cela
// rend une seule somme de controle a calculer au lieu de quarante, donc une
// suite de tests qui reste rapide, alors que le lecteur ZIP verifie la somme de
// chaque page qu il extrait et refuserait un contenu invente.
//

/// Un CBZ valide dont les octets se calculent au lieu d etre stockes.
struct ArchiveSynthetique: Sendable {
    /// Ce que porte une portion de l archive.
    private enum Contenu: Sendable {
        /// Des octets fixes, en tete ou index.
        case fixe(Data)

        /// Le contenu d une page, identique pour toutes.
        case page
    }

    private struct Portion: Sendable {
        let debut: UInt64
        let fin: UInt64
        let contenu: Contenu
    }

    let nombreDePages: Int
    let octetsParPage: Int
    let taille: UInt64

    /// Le contenu d une page, tel que le lecteur doit le rendre.
    let contenuDUnePage: Data

    private let portions: [Portion]

    init(nombreDePages: Int, octetsParPage: Int) {
        self.nombreDePages = nombreDePages
        self.octetsParPage = octetsParPage

        let page = Self.motif(octetsParPage)
        let crc = SommeCrc32.calculer(page)
        let noms = (0..<nombreDePages).map { String(format: "page%03d.jpg", $0) }

        var portions: [Portion] = []
        var offsets: [UInt64] = []
        var position: UInt64 = 0

        for nom in noms {
            offsets.append(position)

            let enTete = Self.enTeteLocal(nom: nom, crc: crc, taille: octetsParPage)
            portions.append(Portion(debut: position, fin: position + UInt64(enTete.count), contenu: .fixe(enTete)))
            position += UInt64(enTete.count)
            portions.append(Portion(debut: position, fin: position + UInt64(octetsParPage), contenu: .page))
            position += UInt64(octetsParPage)
        }

        var index = Data()
        for (rang, nom) in noms.enumerated() {
            index.append(
                Self.enTeteCentral(nom: nom, crc: crc, taille: octetsParPage, offsetLocal: UInt32(offsets[rang]))
            )
        }

        let debutDeLIndex = position
        portions.append(Portion(debut: position, fin: position + UInt64(index.count), contenu: .fixe(index)))
        position += UInt64(index.count)

        let fin = Self.enregistrementDeFin(
            nombreDEntrees: nombreDePages,
            tailleDeLIndex: UInt32(index.count),
            offsetDeLIndex: UInt32(debutDeLIndex)
        )
        portions.append(Portion(debut: position, fin: position + UInt64(fin.count), contenu: .fixe(fin)))
        position += UInt64(fin.count)

        contenuDUnePage = page
        self.portions = portions
        taille = position
    }

    /// Les noms d entrees, dans l ordre ou l archive les range.
    var nomsDesPages: [String] {
        (0..<nombreDePages).map { String(format: "page%03d.jpg", $0) }
    }

    /// Rend la plage demandee, calculee et non stockee.
    func octets(a offset: UInt64, longueur: Int) -> Data {
        guard longueur > 0, offset < taille else {
            return Data()
        }

        let borne = min(offset + UInt64(longueur), taille)
        var assemble = Data(capacity: Int(borne - offset))
        var position = offset

        for portion in portions where portion.fin > position && portion.debut < borne {
            let debut = max(position, portion.debut)
            let bout = min(borne, portion.fin)
            let dedans = Int(debut - portion.debut)
            let combien = Int(bout - debut)

            let source = switch portion.contenu {
            case let .fixe(octets): octets
            case .page: contenuDUnePage
            }

            assemble.append(
                source.subdata(in: (source.startIndex + dedans)..<(source.startIndex + dedans + combien))
            )

            position = bout
        }

        return assemble
    }

    // MARK: Disposition du format

    /// Le contenu d une page, deterministe et sans motif trop court.
    ///
    /// Le pas de trente et un evite une periode de deux cent cinquante six
    /// octets, qui ferait passer une lecture decalee d un bloc entier pour une
    /// lecture juste.
    private static func motif(_ longueur: Int) -> Data {
        var octets = Data(count: longueur)
        octets.withUnsafeMutableBytes { tampon in
            for indice in 0..<tampon.count {
                tampon[indice] = UInt8(truncatingIfNeeded: indice &* 31 &+ 7)
            }
        }

        return octets
    }

    private static func enTeteLocal(nom: String, crc: UInt32, taille: Int) -> Data {
        let octetsDuNom = Data(nom.utf8)
        var enTete = Data()

        enTete.append(entier32(0x0403_4B50))
        enTete.append(entier16(20))
        enTete.append(entier16(0))
        enTete.append(entier16(0))
        enTete.append(entier16(0))
        enTete.append(entier16(0))
        enTete.append(entier32(crc))
        enTete.append(entier32(UInt32(taille)))
        enTete.append(entier32(UInt32(taille)))
        enTete.append(entier16(UInt16(octetsDuNom.count)))
        enTete.append(entier16(0))
        enTete.append(octetsDuNom)

        return enTete
    }

    private static func enTeteCentral(nom: String, crc: UInt32, taille: Int, offsetLocal: UInt32) -> Data {
        let octetsDuNom = Data(nom.utf8)
        var enTete = Data()

        enTete.append(entier32(0x0201_4B50))
        enTete.append(entier16(20))
        enTete.append(entier16(20))
        enTete.append(entier16(0))
        enTete.append(entier16(0))
        enTete.append(entier16(0))
        enTete.append(entier16(0))
        enTete.append(entier32(crc))
        enTete.append(entier32(UInt32(taille)))
        enTete.append(entier32(UInt32(taille)))
        enTete.append(entier16(UInt16(octetsDuNom.count)))
        enTete.append(entier16(0))
        enTete.append(entier16(0))
        enTete.append(entier16(0))
        enTete.append(entier16(0))
        enTete.append(entier32(0))
        enTete.append(entier32(offsetLocal))
        enTete.append(octetsDuNom)

        return enTete
    }

    private static func enregistrementDeFin(
        nombreDEntrees: Int,
        tailleDeLIndex: UInt32,
        offsetDeLIndex: UInt32
    ) -> Data {
        var fin = Data()

        fin.append(entier32(0x0605_4B50))
        fin.append(entier16(0))
        fin.append(entier16(0))
        fin.append(entier16(UInt16(nombreDEntrees)))
        fin.append(entier16(UInt16(nombreDEntrees)))
        fin.append(entier32(tailleDeLIndex))
        fin.append(entier32(offsetDeLIndex))
        fin.append(entier16(0))

        return fin
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
}

/// Somme de controle CRC 32, reecrite ici plutot qu empruntee au paquet Archive.
///
/// Un test qui verifierait une archive avec la somme calculee par le code qu il
/// teste ne prouverait que la coherence de ce code avec lui meme. Celle ci est
/// la table standard du polynome inverse 0xEDB88320, celle que le format ZIP
/// impose, ecrite independamment.
enum SommeCrc32 {
    private static let table: [UInt32] = (0..<256).map { rang in
        var valeur = UInt32(rang)

        for _ in 0..<8 {
            valeur = valeur & 1 == 1 ? 0xEDB8_8320 ^ (valeur >> 1) : valeur >> 1
        }

        return valeur
    }

    static func calculer(_ octets: Data) -> UInt32 {
        var somme: UInt32 = 0xFFFF_FFFF

        octets.withUnsafeBytes { tampon in
            for octet in tampon {
                somme = table[Int((somme ^ UInt32(octet)) & 0xFF)] ^ (somme >> 8)
            }
        }

        return somme ^ 0xFFFF_FFFF
    }
}
