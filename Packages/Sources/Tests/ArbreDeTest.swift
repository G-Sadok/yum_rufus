import CoreGraphics
import Foundation

//
// ArbreDeTest
//
// Fabrique une arborescence de fichiers dans un dossier temporaire, et la
// supprime a la fin du test.
//
// Les arbres sont construits plutot que deposes dans le depot, pour la meme
// raison que les archives d Archive : un arbre decrit ici se relit dans une
// revue, alors qu un dossier de fixtures binaires ne se relit pas. Et un test
// qui cree son arbre teste aussi ce que le systeme de fichiers rend vraiment,
// dates de modification comprises.
//

/// Arborescence de test posee dans un dossier temporaire.
final class ArbreDeTest {
    private(set) var racine: URL

    private let gestionnaire = FileManager.default

    init(nom: String = "arbre") throws {
        racine = FileManager.default.temporaryDirectory
            .appendingPathComponent("yum-tests-\(nom)-\(UUID().uuidString)", isDirectory: true)

        try gestionnaire.createDirectory(at: racine, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: racine)
    }

    /// Cree un dossier, chemins intermediaires compris.
    @discardableResult
    func dossier(_ chemin: String) throws -> URL {
        let url = racine.appending(path: chemin)

        try gestionnaire.createDirectory(at: url, withIntermediateDirectories: true)

        return url
    }

    /// Ecrit un fichier, en creant son dossier parent au besoin.
    @discardableResult
    func fichier(_ chemin: String, contenu: Data = Data([0x00])) throws -> URL {
        let url = racine.appending(path: chemin)

        try gestionnaire.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try contenu.write(to: url)

        return url
    }

    /// Ecrit une image factice. Seule l extension compte pour l analyse.
    @discardableResult
    func image(_ chemin: String, octets: Int = 16) throws -> URL {
        try fichier(chemin, contenu: Data(repeating: 0xFF, count: octets))
    }

    /// Ecrit une archive CBZ contenant les pages nommees.
    @discardableResult
    func archive(_ chemin: String, pages: [String]) throws -> URL {
        let entrees = pages.map { nom in
            EntreeDeZipDeTest(nom: nom, contenu: Data(repeating: 0x2A, count: 24))
        }

        return try fichier(chemin, contenu: ConstructeurDeZipDeTest.octets(entrees))
    }

    /// Ecrit un PDF de `pages` pages vides au format A4.
    @discardableResult
    func pdf(_ chemin: String, pages: Int, motDePasse: String? = nil) throws -> URL {
        try fichier(chemin, contenu: ConstructeurDePdfDeTest.octets(pages: pages, motDePasse: motDePasse))
    }

    /// Renomme une entree de l arbre et rend sa nouvelle URL.
    @discardableResult
    func renommer(_ chemin: String, en nouveau: String) throws -> URL {
        let source = racine.appending(path: chemin)
        let cible = racine.appending(path: nouveau)

        try gestionnaire.moveItem(at: source, to: cible)

        return cible
    }

    /// Supprime une entree de l arbre.
    func supprimer(_ chemin: String) throws {
        try gestionnaire.removeItem(at: racine.appending(path: chemin))
    }

    /// Supprime la racine, pour simuler un dossier disparu.
    func supprimerLaRacine() throws {
        try gestionnaire.removeItem(at: racine)
    }

    /// Renomme la racine, pour simuler un dossier que l utilisateur deplace
    /// entre deux lancements.
    @discardableResult
    func renommerLaRacine(en nom: String) throws -> URL {
        let cible = racine.deletingLastPathComponent()
            .appendingPathComponent("\(nom)-\(UUID().uuidString)", isDirectory: true)

        try gestionnaire.moveItem(at: racine, to: cible)
        racine = cible

        return cible
    }
}

/// Ecrit des PDF de test, en clair ou proteges.
///
/// Meme raison que pour le ZIP ci dessous : le constructeur de la suite
/// ImagePipeline n est pas visible d ici, et ces tests n ont pas besoin de ses
/// options. Une page A4 vide suffit a verifier que la source enumere bien le
/// chapitre et que la protection remonte jusqu a l appelant.
enum ConstructeurDePdfDeTest {
    static func octets(pages: Int, motDePasse: String? = nil) -> Data {
        let sortie = NSMutableData()

        guard let consommateur = CGDataConsumer(data: sortie) else { return Data() }

        var boite = CGRect(x: 0, y: 0, width: 595, height: 842)
        var informations: [CFString: Any] = [:]

        if let motDePasse {
            informations[kCGPDFContextUserPassword] = motDePasse
            informations[kCGPDFContextOwnerPassword] = motDePasse
        }

        guard let contexte = CGContext(
            consumer: consommateur,
            mediaBox: &boite,
            informations as CFDictionary
        ) else {
            return Data()
        }

        for _ in 0..<pages {
            contexte.beginPDFPage(nil)
            contexte.setFillColor(gray: 0.5, alpha: 1)
            contexte.fill(boite)
            contexte.endPDFPage()
        }

        contexte.closePDF()

        return sortie as Data
    }
}

/// Entree a ecrire dans une archive de test.
struct EntreeDeZipDeTest {
    let nom: String
    let contenu: Data
}

/// Ecrit des archives ZIP sans compression.
///
/// Le constructeur d Archive n est pas visible d ici, et le dupliquer en entier
/// n aurait pas de sens : ces tests n ont pas besoin d archives cassees, juste
/// d un conteneur valide que `DocumentZip` sait relire. Les entrees sont donc
/// rangees telles quelles, methode zero.
enum ConstructeurDeZipDeTest {
    static func octets(_ entrees: [EntreeDeZipDeTest]) -> Data {
        var archive = Data()
        var index = Data()
        var nombre: UInt16 = 0

        for entree in entrees {
            let nom = Data(entree.nom.utf8)
            let somme = crc32(entree.contenu)
            let taille = UInt32(entree.contenu.count)
            let position = UInt32(archive.count)

            archive.append(entete(signature: 0x0403_4B50, somme: somme, taille: taille, nom: nom))
            archive.append(entree.contenu)

            index.append(entreeCentrale(somme: somme, taille: taille, nom: nom, position: position))
            nombre += 1
        }

        let debutIndex = UInt32(archive.count)
        let tailleIndex = UInt32(index.count)

        archive.append(index)
        archive.append(finDIndex(nombre: nombre, taille: tailleIndex, debut: debutIndex))

        return archive
    }

    private static func entete(signature: UInt32, somme: UInt32, taille: UInt32, nom: Data) -> Data {
        var entete = Data()

        entete.ajouter(signature)
        entete.ajouter(UInt16(20)) // version minimale
        entete.ajouter(UInt16(0)) // drapeaux
        entete.ajouter(UInt16(0)) // methode, zero pour range tel quel
        entete.ajouter(UInt16(0)) // heure
        entete.ajouter(UInt16(0)) // date
        entete.ajouter(somme)
        entete.ajouter(taille) // taille compressee
        entete.ajouter(taille) // taille decompressee
        entete.ajouter(UInt16(nom.count))
        entete.ajouter(UInt16(0)) // champ supplementaire
        entete.append(nom)

        return entete
    }

    private static func entreeCentrale(somme: UInt32, taille: UInt32, nom: Data, position: UInt32) -> Data {
        var entree = Data()

        entree.ajouter(UInt32(0x0201_4B50))
        entree.ajouter(UInt16(20)) // version d ecriture
        entree.ajouter(UInt16(20)) // version minimale
        entree.ajouter(UInt16(0)) // drapeaux
        entree.ajouter(UInt16(0)) // methode
        entree.ajouter(UInt16(0)) // heure
        entree.ajouter(UInt16(0)) // date
        entree.ajouter(somme)
        entree.ajouter(taille)
        entree.ajouter(taille)
        entree.ajouter(UInt16(nom.count))
        entree.ajouter(UInt16(0)) // champ supplementaire
        entree.ajouter(UInt16(0)) // commentaire
        entree.ajouter(UInt16(0)) // disque
        entree.ajouter(UInt16(0)) // attributs internes
        entree.ajouter(UInt32(0)) // attributs externes
        entree.ajouter(position)
        entree.append(nom)

        return entree
    }

    private static func finDIndex(nombre: UInt16, taille: UInt32, debut: UInt32) -> Data {
        var fin = Data()

        fin.ajouter(UInt32(0x0605_4B50))
        fin.ajouter(UInt16(0)) // disque courant
        fin.ajouter(UInt16(0)) // disque de l index
        fin.ajouter(nombre)
        fin.ajouter(nombre)
        fin.ajouter(taille)
        fin.ajouter(debut)
        fin.ajouter(UInt16(0)) // commentaire

        return fin
    }

    /// Somme de controle CRC 32, polynome inverse de la norme ZIP.
    static func crc32(_ donnees: Data) -> UInt32 {
        var somme: UInt32 = 0xFFFF_FFFF

        for octet in donnees {
            somme ^= UInt32(octet)

            for _ in 0..<8 {
                somme = (somme >> 1) ^ (0xEDB8_8320 & (somme & 1 == 1 ? 0xFFFF_FFFF : 0))
            }
        }

        return somme ^ 0xFFFF_FFFF
    }
}

extension Data {
    fileprivate mutating func ajouter(_ valeur: UInt16) {
        append(contentsOf: [UInt8(valeur & 0xFF), UInt8(valeur >> 8 & 0xFF)])
    }

    fileprivate mutating func ajouter(_ valeur: UInt32) {
        append(contentsOf: (0..<4).map { UInt8(valeur >> (8 * $0) & 0xFF) })
    }
}
