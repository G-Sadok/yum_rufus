import Compression
import Foundation

//
// ConstructeurDeZip
//
// Fabrique des archives ZIP en memoire pour les tests, y compris des archives
// volontairement cassees.
//
// Les archives sont construites plutot que deposees en binaire dans le depot,
// pour trois raisons. Un ZIP binaire ne se relit pas dans une revue. Une archive
// cassee d une facon precise, somme de controle fausse ou methode inconnue, se
// decrit ici en une ligne. Enfin le constructeur rend la position exacte des
// octets de chaque entree, ce qui permet de prouver qu ouvrir la page N ne
// touche pas les octets des pages precedentes.
//

/// Description d une entree a ecrire dans l archive de test.
struct EntreeDeTest {
    var nom: String
    var contenu: Data
    var compresser = false

    /// Somme de controle ecrite dans l archive, quand elle doit etre fausse.
    var crcForce: UInt32?

    /// Methode de compression ecrite dans l archive, quand elle doit etre
    /// inconnue du lecteur.
    var methodeForcee: UInt16?

    /// Drapeaux ecrits dans l archive, par exemple pour simuler une entree
    /// chiffree.
    var drapeauxForces: UInt16?

    /// Octets reellement ranges dans l archive, quand ils doivent contredire ce
    /// que l index annonce.
    var octetsForces: Data?

    /// Taille compressee annoncee, quand elle doit deborder du fichier.
    var tailleCompresseeForcee: UInt32?

    /// Taille decompressee annoncee, quand elle doit mentir.
    var tailleDecompresseeForcee: UInt32?

    init(_ nom: String, contenu: Data = Data(), compresser: Bool = false) {
        self.nom = nom
        self.contenu = contenu
        self.compresser = compresser
    }
}

/// Archive fabriquee, avec de quoi verifier ce qui a ete lu.
struct ArchiveDeTest {
    let octets: Data

    /// Plage occupee par les octets de chaque entree, dans le fichier.
    let plages: [String: Range<Int>]
}

enum ConstructeurDeZip {
    /// Ecrit une archive ZIP complete.
    static func archive(_ entrees: [EntreeDeTest], commentaire: String = "") -> ArchiveDeTest {
        var fichier = Data()
        var plages: [String: Range<Int>] = [:]
        var index = Data()

        for entree in entrees {
            let preparee = preparer(entree)
            let offsetLocal = fichier.count

            fichier.append(enTeteLocal(preparee))
            plages[entree.nom] = fichier.count..<(fichier.count + preparee.octets.count)
            fichier.append(preparee.octets)
            index.append(enTeteCentral(preparee, offsetLocal: UInt32(offsetLocal)))
        }

        let offsetIndex = fichier.count
        fichier.append(index)
        fichier.append(
            enregistrementDeFin(
                nombre: entrees.count,
                taille: index.count,
                offset: offsetIndex,
                commentaire: commentaire
            )
        )

        return ArchiveDeTest(octets: fichier, plages: plages)
    }

    /// Entree prete a ecrire, avec ses valeurs finales.
    struct EntreePreparee {
        let nom: Data
        let octets: Data
        let crc: UInt32
        let methode: UInt16
        let drapeaux: UInt16
        let tailleCompressee: UInt32
        let tailleDecompressee: UInt32
    }

    private static func preparer(_ entree: EntreeDeTest) -> EntreePreparee {
        let compresses = entree.compresser ? deflate(entree.contenu) : entree.contenu
        let methode: UInt16 = entree.compresser ? 8 : 0
        let octets = entree.octetsForces ?? compresses

        return EntreePreparee(
            nom: Data(entree.nom.utf8),
            octets: octets,
            crc: entree.crcForce ?? crc32(entree.contenu),
            methode: entree.methodeForcee ?? methode,
            drapeaux: entree.drapeauxForces ?? 0x0800,
            tailleCompressee: entree.tailleCompresseeForcee ?? UInt32(octets.count),
            tailleDecompressee: entree.tailleDecompresseeForcee ?? UInt32(entree.contenu.count)
        )
    }

    private static func enTeteLocal(_ entree: EntreePreparee) -> Data {
        var enTete = Data()
        enTete.ajouter32(0x0403_4B50)
        enTete.ajouter16(20)
        enTete.ajouter16(entree.drapeaux)
        enTete.ajouter16(entree.methode)
        enTete.ajouter16(0)
        enTete.ajouter16(0)
        enTete.ajouter32(entree.crc)
        enTete.ajouter32(entree.tailleCompressee)
        enTete.ajouter32(entree.tailleDecompressee)
        enTete.ajouter16(UInt16(entree.nom.count))
        enTete.ajouter16(0)
        enTete.append(entree.nom)

        return enTete
    }

    private static func enTeteCentral(_ entree: EntreePreparee, offsetLocal: UInt32) -> Data {
        var enTete = Data()
        enTete.ajouter32(0x0201_4B50)
        enTete.ajouter16(20)
        enTete.ajouter16(20)
        enTete.ajouter16(entree.drapeaux)
        enTete.ajouter16(entree.methode)
        enTete.ajouter16(0)
        enTete.ajouter16(0)
        enTete.ajouter32(entree.crc)
        enTete.ajouter32(entree.tailleCompressee)
        enTete.ajouter32(entree.tailleDecompressee)
        enTete.ajouter16(UInt16(entree.nom.count))
        enTete.ajouter16(0)
        enTete.ajouter16(0)
        enTete.ajouter16(0)
        enTete.ajouter16(0)
        enTete.ajouter32(0)
        enTete.ajouter32(offsetLocal)
        enTete.append(entree.nom)

        return enTete
    }

    private static func enregistrementDeFin(
        nombre: Int,
        taille: Int,
        offset: Int,
        commentaire: String
    ) -> Data {
        let texte = Data(commentaire.utf8)
        var fin = Data()
        fin.ajouter32(0x0605_4B50)
        fin.ajouter16(0)
        fin.ajouter16(0)
        fin.ajouter16(UInt16(nombre))
        fin.ajouter16(UInt16(nombre))
        fin.ajouter32(UInt32(taille))
        fin.ajouter32(UInt32(offset))
        fin.ajouter16(UInt16(texte.count))
        fin.append(texte)

        return fin
    }

    /// Compresse en deflate brut, comme le fait un outil d archivage.
    static func deflate(_ contenu: Data) -> Data {
        let capacite = contenu.count + 4096
        var sortie = Data(count: capacite)

        let ecrits = sortie.withUnsafeMutableBytes { destination -> Int in
            guard let cible = destination.bindMemory(to: UInt8.self).baseAddress else { return 0 }

            return contenu.withUnsafeBytes { origine -> Int in
                guard let base = origine.bindMemory(to: UInt8.self).baseAddress else { return 0 }

                return compression_encode_buffer(
                    cible,
                    capacite,
                    base,
                    contenu.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }

        return sortie.prefix(ecrits)
    }

    /// Somme de controle attendue par le format, recalculee ici pour ne pas
    /// verifier le code de production avec lui meme.
    static func crc32(_ donnees: Data) -> UInt32 {
        var accumulateur: UInt32 = 0xFFFF_FFFF

        for octet in donnees {
            accumulateur ^= UInt32(octet)
            for _ in 0..<8 {
                accumulateur = (accumulateur & 1) == 1
                    ? (accumulateur >> 1) ^ 0xEDB8_8320
                    : accumulateur >> 1
            }
        }

        return accumulateur ^ 0xFFFF_FFFF
    }
}

extension Data {
    fileprivate mutating func ajouter16(_ valeur: UInt16) {
        append(contentsOf: [UInt8(valeur & 0xFF), UInt8(valeur >> 8 & 0xFF)])
    }

    fileprivate mutating func ajouter32(_ valeur: UInt32) {
        append(contentsOf: (0..<4).map { UInt8(valeur >> (8 * $0) & 0xFF) })
    }
}
