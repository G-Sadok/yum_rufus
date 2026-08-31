import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

//
// EcrivainDeCbz
//
// Fabrique un CBZ reel, avec de vraies pages JPEG.
//
// Les budgets d ouverture de chapitre, de tourne de page et de memoire en
// lecture ne veulent rien dire sur des octets inventes : ils mesurent la lecture
// de l index central d un ZIP, l extraction d une entree et le decodage sous
// echantillonne d une image. Une archive de motifs ne serait pas decodable, et
// une archive minuscule ne dirait rien du cout d une page de manga.
//
// Les entrees sont stockees et non compressees. Un CBZ de scans est deja compose
// d images compressees, les redeflater ne gagne rien et ferait payer a la
// generation un temps que la mesure n emploie pas.
//

/// Ce qui empeche la fabrication d un chapitre.
public enum ErreurDeFabrication: Error, Sendable, Equatable {
    /// L image n a pas pu etre construite a cette taille.
    case imageImpossible(largeur: Int, hauteur: Int)

    /// L encodage JPEG a echoue.
    case encodageImpossible(nom: String)

    /// Le fichier n a pas pu etre ecrit a cet emplacement.
    case ecritureImpossible(chemin: String)
}

/// Fabrique de chapitres CBZ deterministes.
public enum EcrivainDeCbz {
    /// Ecrit un CBZ de `pages` pages a l emplacement demande.
    ///
    /// - Parameters:
    ///   - destination: chemin du fichier, dont le dossier parent doit exister.
    ///   - pages: nombre de pages du chapitre.
    ///   - largeur: largeur de chaque page en pixels.
    ///   - hauteur: hauteur de chaque page en pixels.
    ///   - graine: graine du contenu, pour que deux appels rendent le meme
    ///     fichier octet pour octet.
    public static func ecrire(
        vers destination: URL,
        pages: Int,
        largeur: Int,
        hauteur: Int,
        graine: UInt64
    ) throws {
        var archive = Data()
        var index = Data()

        for page in 0..<pages {
            let nom = String(format: "page%03d.jpg", page)
            let octets = try jpeg(largeur: largeur, hauteur: hauteur, graine: graine &+ UInt64(page), nom: nom)
            let somme = SommeCrc32Independante.calculer(octets)

            let offsetLocal = UInt32(archive.count)

            archive.append(enTeteLocal(nom: nom, crc: somme, taille: octets.count))
            archive.append(octets)
            index.append(enTeteCentral(nom: nom, crc: somme, taille: octets.count, offsetLocal: offsetLocal))
        }

        let debutDeLIndex = UInt32(archive.count)
        archive.append(index)
        archive.append(
            enregistrementDeFin(
                nombreDEntrees: pages,
                tailleDeLIndex: UInt32(index.count),
                offsetDeLIndex: debutDeLIndex
            )
        )

        do {
            try archive.write(to: destination)
        } catch {
            throw ErreurDeFabrication.ecritureImpossible(chemin: destination.path)
        }
    }

    // MARK: Pages

    /// Une page JPEG deterministe qui pese ce que pese une planche scannee.
    ///
    /// Il a fallu deux essais pour poser cette page, et l ecart entre les deux
    /// dit tout ce que ce fichier doit garantir.
    ///
    /// La premiere version tirait du bruit pseudo aleatoire sur toute la page.
    /// Le bruit est le pire cas absolu d un encodeur JPEG : chaque page pesait
    /// 7,7 Mo la ou une planche scannee en pese entre 0,4 et 1,5, et la tourne
    /// de page mesurait 154 ms contre un budget de 80. Le budget n etait pas
    /// depasse par le lecteur, il etait depasse par un contenu qui n existe pas.
    ///
    /// L erreur inverse est aussi grave et plus discrete : un aplat se
    /// comprimerait a quelques kilo octets, le decodeur n aurait presque rien a
    /// faire, et les budgets d ouverture et de tourne de page passeraient au
    /// vert quoi qu il arrive au code.
    ///
    /// Ce qui est dessine ici est donc une planche : fond clair, cases bordees
    /// de noir, hachures, trames et bandeaux de texte. La suite
    /// `CorpusSurDisqueTests` borne la densite obtenue des deux cotes, pour que
    /// ni l une ni l autre des deux derives ne revienne en silence.
    static func jpeg(largeur: Int, hauteur: Int, graine: UInt64, nom: String) throws -> Data {
        let image = try planche(largeur: largeur, hauteur: hauteur, graine: graine)
        let sortie = NSMutableData()

        guard let destination = CGImageDestinationCreateWithData(
            sortie as CFMutableData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw ErreurDeFabrication.encodageImpossible(nom: nom)
        }

        let reglages = [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary
        CGImageDestinationAddImage(destination, image, reglages)

        guard CGImageDestinationFinalize(destination) else {
            throw ErreurDeFabrication.encodageImpossible(nom: nom)
        }

        return sortie as Data
    }

    /// Dessine une planche en niveaux de gris.
    ///
    /// Le gris et non la couleur : un scan de manga en est un, et l encoder en
    /// trois composantes ferait payer au decodeur une conversion que le vrai
    /// chapitre ne lui demande pas.
    private static func planche(largeur: Int, hauteur: Int, graine: UInt64) throws -> CGImage {
        var octets = Data(count: largeur * hauteur)
        var tirage = GrainePseudoAleatoire(graine: graine)
        let cases = decoupageEnCases(largeur: largeur, hauteur: hauteur, tirage: &tirage)

        octets.withUnsafeMutableBytes { (tampon: UnsafeMutableRawBufferPointer) in
            for ligne in 0..<hauteur {
                let debut = ligne * largeur

                for colonne in 0..<largeur {
                    tampon[debut + colonne] = valeur(colonne: colonne, ligne: ligne, cases: cases)
                }
            }
        }

        // L image est construite sur un fournisseur de donnees et non sur un
        // contexte graphique : le contexte prendrait un pointeur sur un tampon
        // dont il ne garantit pas la survie, le fournisseur retient les octets.
        guard let fournisseur = CGDataProvider(data: octets as CFData) else {
            throw ErreurDeFabrication.imageImpossible(largeur: largeur, hauteur: hauteur)
        }

        guard let image = CGImage(
            width: largeur,
            height: hauteur,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: largeur,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: fournisseur,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else {
            throw ErreurDeFabrication.imageImpossible(largeur: largeur, hauteur: hauteur)
        }

        return image
    }

    /// Une case de la planche, avec le remplissage qui l occupe.
    private struct CaseDePlanche {
        let colonnes: Range<Int>
        let lignes: Range<Int>

        /// Periode de la trame, en pixels. Plus elle est courte, plus la case
        /// coute cher a encoder.
        let periode: Int

        /// Sens des hachures, qui evite que toutes les cases se ressemblent.
        let diagonale: Bool

        /// Gris de fond de la case.
        let fond: UInt8

        /// Bande tramee, qui n occupe qu une part de la case.
        let trame: Range<Int>

        /// Bulle de dialogue, seul endroit ou du texte est simule.
        let bulleColonnes: Range<Int>
        let bulleLignes: Range<Int>
    }

    /// Decoupe la planche en trois a six cases empilees.
    ///
    /// La trame et la bulle sont volontairement etroites. Une planche est
    /// surtout du blanc : c est ce qui fait qu un scan pese quelques centaines
    /// de kilo octets et non plusieurs mega octets, et c est ce qui rend le
    /// budget de tourne de page mesurable sur autre chose qu un cas impossible.
    private static func decoupageEnCases(
        largeur: Int,
        hauteur: Int,
        tirage: inout GrainePseudoAleatoire
    ) -> [CaseDePlanche] {
        let marge = max(4, largeur / 40)
        let nombre = tirage.entier(de: 3, a: 6)
        let hauteurUtile = hauteur - 2 * marge
        let pas = hauteurUtile / nombre

        return (0..<nombre).map { rang in
            let haut = marge + rang * pas
            let bas = haut + pas - marge / 2
            let gauche = marge + tirage.entier(de: 0, a: largeur / 8)
            let droite = largeur - marge
            let hauteurDeCase = bas - haut

            let debutDeTrame = haut + hauteurDeCase / 2
            let largeurDeBulle = (droite - gauche) * 2 / 5
            let hauteurDeBulle = max(12, hauteurDeCase / 6)
            let coinDeBulle = gauche + tirage.entier(de: marge, a: max(marge + 1, (droite - gauche) / 3))

            return CaseDePlanche(
                colonnes: gauche..<droite,
                lignes: haut..<bas,
                periode: tirage.entier(de: 10, a: 26),
                diagonale: tirage.entier(de: 0, a: 1) == 0,
                fond: UInt8(tirage.entier(de: 236, a: 252)),
                trame: debutDeTrame..<(debutDeTrame + hauteurDeCase / 4),
                bulleColonnes: coinDeBulle..<(coinDeBulle + largeurDeBulle),
                bulleLignes: (haut + hauteurDeCase / 8)..<(haut + hauteurDeCase / 8 + hauteurDeBulle)
            )
        }
    }

    /// Le gris d un pixel de la planche.
    private static func valeur(colonne: Int, ligne: Int, cases: [CaseDePlanche]) -> UInt8 {
        guard let dedans = cases.first(where: { $0.colonnes.contains(colonne) && $0.lignes.contains(ligne) })
        else {
            return 252
        }

        let bord = 3
        let surLeBord = colonne - dedans.colonnes.lowerBound < bord
            || dedans.colonnes.upperBound - colonne <= bord
            || ligne - dedans.lignes.lowerBound < bord
            || dedans.lignes.upperBound - ligne <= bord

        if surLeBord {
            return 8
        }

        if dedans.bulleColonnes.contains(colonne), dedans.bulleLignes.contains(ligne) {
            return texteDeBulle(colonne: colonne, ligne: ligne, bulle: dedans)
        }

        guard dedans.trame.contains(ligne) else {
            return dedans.fond
        }

        let axe = dedans.diagonale ? colonne + ligne : colonne - ligne + dedans.colonnes.upperBound

        return axe % dedans.periode < dedans.periode / 3 ? 48 : dedans.fond
    }

    /// Le contenu d une bulle : trois lignes de mots simules sur fond blanc.
    ///
    /// C est la zone la plus couteuse a encoder de toute la planche, et elle
    /// occupe moins d un dixieme de la page, exactement comme sur une vraie.
    private static func texteDeBulle(colonne: Int, ligne: Int, bulle: CaseDePlanche) -> UInt8 {
        let rangDansLaBulle = ligne - bulle.bulleLignes.lowerBound
        let hauteurDeLigne = max(3, bulle.bulleLignes.count / 4)

        guard rangDansLaBulle % hauteurDeLigne < hauteurDeLigne / 2 else {
            return 254
        }

        let position = colonne - bulle.bulleColonnes.lowerBound

        return (position / 5) % 6 < 4 ? 20 : 254
    }

    // MARK: Disposition du format ZIP

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

/// Somme de controle CRC 32 du format ZIP, ecrite ici plutot qu empruntee au
/// paquet Archive.
///
/// Fabriquer une archive avec la somme calculee par le code qui la relira
/// ensuite ne prouverait que la coherence de ce code avec lui meme. Celle ci est
/// la table standard du polynome inverse 0xEDB88320, que le format impose.
enum SommeCrc32Independante {
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
