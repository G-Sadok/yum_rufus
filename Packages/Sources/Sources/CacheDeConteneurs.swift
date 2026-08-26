import Core
import CryptoKit
import Foundation

//
// CacheDeConteneurs
//
// Ou sont ranges les conteneurs rapatries par les sources qui ne savent pas
// servir une page seule.
//
// Le type est arrive avec Jellyfin et portait son nom. OPDS l emploie a son
// tour, pour la meme raison exactement : un catalogue qui ne publie pas
// l extension de diffusion page par page ne connait que le fichier du chapitre,
// jamais son contenu. Deux copies du meme cache auraient diverge au premier
// correctif, et l assainissement des noms qu il porte est une regle de
// securite, pas un detail d ecriture.
//
// Le nom de fichier est fait d un prefixe lisible et d une empreinte. Les deux
// moities repondent a un probleme distinct.
//
// Le prefixe est assaini parce que les identifiants viennent d un serveur
// distant. Un serveur hostile qui rendrait un identifiant fait de points et de
// barres ecrirait hors du cache, et la section 11 ne laisse pas ce chemin
// ouvert.
//
// L empreinte est la parce qu un identifiant OPDS est une adresse complete.
// Assainie telle quelle, elle depasse la longueur qu un systeme de fichiers
// accepte, et l ecriture echouerait sur les catalogues aux adresses longues.
// La tronquer sans empreinte ferait pointer deux chapitres voisins sur le meme
// fichier de cache, et l utilisateur lirait le mauvais chapitre.
//

/// Cache de fichiers rapatries, propre a une source.
struct CacheDeConteneursDistants: Sendable, Hashable {
    /// Dossier propre a la source.
    let dossier: URL

    /// Longueur du prefixe lisible d un nom de fichier.
    private static let longueurDuPrefixe = 40

    /// Longueur de l empreinte hexadecimale qui suit le prefixe.
    private static let longueurDeLEmpreinte = 32

    /// Le cache range dans le dossier de caches du systeme.
    ///
    /// Le dossier de caches et non celui de documents : un conteneur rapatrie se
    /// retelecharge, il n a donc rien a faire dans une sauvegarde, et le systeme
    /// a le droit de l effacer quand l appareil manque de place.
    ///
    /// - Parameter famille: le nom du type de source, qui separe les caches de
    ///   deux sources de natures differentes.
    static func parDefaut(famille: String, source: SourceID) -> CacheDeConteneursDistants {
        let racine = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory

        return CacheDeConteneursDistants(
            dossier: racine.appending(path: "Tsuzuki/\(assaini(famille))/\(source.brut.uuidString)")
        )
    }

    /// Le fichier ou ranger le conteneur d un chapitre.
    func fichier(chapitre: String, format: String) -> URL {
        dossier.appending(path: "\(Self.nomDeFichier(chapitre)).\(Self.assaini(format))")
    }

    /// Vrai quand ce conteneur est deja range.
    func contient(_ fichier: URL) -> Bool {
        FileManager.default.fileExists(atPath: fichier.path)
    }

    /// Le conteneur deja range pour ce chapitre, quel que soit son format.
    ///
    /// La recherche ignore l extension, et c est le sujet. Le format d un
    /// chapitre OPDS est annonce par le flux de sa serie, jamais par
    /// l identifiant du chapitre. Une lecture qui commence sans avoir vu ce
    /// flux, ce qui arrive apres un redemarrage, ne connait donc pas le format,
    /// et une recherche par nom complet manquerait un fichier deja rapatrie.
    /// L extension du fichier trouve redonne au passage le format perdu.
    func fichierExistant(chapitre: String) -> URL? {
        let prefixe = Self.nomDeFichier(chapitre)
        let ranges = try? FileManager.default.contentsOfDirectory(
            at: dossier,
            includingPropertiesForKeys: nil
        )

        return ranges?.first { $0.lastPathComponent.hasPrefix(prefixe) }
    }

    /// Ecrit un conteneur rapatrie, en creant le dossier au besoin.
    ///
    /// L ecriture est atomique : une lecture interrompue en plein
    /// telechargement laisserait sinon un fichier tronque dans le cache, que la
    /// visite suivante prendrait pour un conteneur complet et corrompu.
    func ecrire(_ octets: Data, dans fichier: URL) throws {
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        try octets.write(to: fichier, options: .atomic)
    }

    /// Efface tout ce que ce cache contient.
    func vider() throws {
        guard FileManager.default.fileExists(atPath: dossier.path) else {
            return
        }

        try FileManager.default.removeItem(at: dossier)
    }

    /// Le nom de fichier d un identifiant distant, borne et sans collision.
    static func nomDeFichier(_ identifiant: String) -> String {
        let prefixe = assaini(identifiant).prefix(longueurDuPrefixe)
        let empreinte = SHA256.hash(data: Data(identifiant.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
            .prefix(longueurDeLEmpreinte)

        return "\(prefixe)-\(empreinte)"
    }

    /// Un nom reduit a ce qui ne peut designer aucun autre dossier.
    ///
    /// Tout ce qui n est ni lettre, ni chiffre, ni tiret est remplace, ce qui
    /// interdit a la fois la remontee de dossier et le nom de fichier reserve.
    private static func assaini(_ brut: String) -> String {
        let propre = brut.map { caractere in
            caractere.isLetter || caractere.isNumber || caractere == "-" ? caractere : "_"
        }

        return propre.isEmpty ? "sans-nom" : String(propre)
    }
}
