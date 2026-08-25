import Core
import Foundation

//
// EmpreinteDeConteneur
//
// Signature bon marche d un conteneur, qui decide si un index mis en cache
// decrit encore le fichier qu on ouvre.
//
// Un cache d index n a de valeur que s il sait se declarer perime. La section
// 5.3 demande de scanner le TAR une seule fois ; elle demande donc, en creux,
// de detecter le jour ou le fichier change sous le cache, faute de quoi le
// lecteur servirait les octets d un autre chapitre a partir de positions
// devenues fausses.
//
// L empreinte croise quatre elements, aucun ne suffisant seul.
//
//   - la taille, qui elimine tout ajout ou retrait de page,
//   - la date de modification, quand la source est un fichier,
//   - une signature de trois zones echantillonnees, tete, milieu et queue,
//   - la version du format d index, pour que nos propres evolutions perime le
//     cache sans intervention.
//
// Le calcul lit douze kilo octets au plus, quelle que soit la taille de
// l archive. C est la condition pour que verifier l empreinte reste beaucoup
// moins cher que rescanner, sans quoi le cache ne servirait a rien.
//
// Sa limite est assumee et vaut la peine d etre nommee : une reecriture qui
// conserverait a la fois la taille exacte, la date de modification exacte et
// les octets des trois zones echantillonnees passerait inapercue. Cela suppose
// une falsification deliberee de la date, pas une manipulation ordinaire de
// fichier.
//

/// Signature d un conteneur, comparee avant de reutiliser un index en cache.
public struct EmpreinteDeConteneur: Sendable, Hashable, Codable {
    /// Taille d une zone echantillonnee, en octets.
    static let tailleDEchantillon = 4096

    /// Chemin ou libelle de la source, repris pour ranger l index.
    public let identite: String

    /// Taille totale du conteneur, en octets.
    public let taille: UInt64

    /// Date de modification en nanosecondes depuis 1970, zero si inconnue.
    ///
    /// Une source en memoire n en a pas. Elle repose alors sur la seule
    /// signature echantillonnee, ce qui reste correct mais moins fin.
    public let horodatage: Int64

    /// Somme de controle des zones echantillonnees.
    public let signature: UInt32

    public init(identite: String, taille: UInt64, horodatage: Int64, signature: UInt32) {
        self.identite = identite
        self.taille = taille
        self.horodatage = horodatage
        self.signature = signature
    }

    /// Calcule l empreinte d une source d octets.
    ///
    /// - Parameter dateDeModification: date portee par le systeme de fichiers,
    ///   quand la source en vient. Absente pour une source en memoire.
    /// - Throws: `ErreurDeDocument.conteneurTronque` si la source rend moins
    ///   d octets qu elle n en annonce.
    public static func calculer(
        pour source: any SourceDOctets,
        dateDeModification: Date? = nil
    ) throws -> EmpreinteDeConteneur {
        var echantillon = Data()
        for plage in plagesDEchantillon(taille: source.taille) {
            try echantillon.append(source.lire(a: plage.offset, longueur: plage.longueur))
        }

        return EmpreinteDeConteneur(
            identite: source.nom,
            taille: source.taille,
            horodatage: dateDeModification.map(nanosecondes) ?? 0,
            signature: SommeDeControle.crc32(echantillon)
        )
    }

    /// Lit la date de modification d un fichier, sans faire echouer l ouverture.
    ///
    /// Une date illisible rend `nil` plutot qu une erreur : l empreinte sait
    /// s en passer, et refuser d ouvrir une archive parce que ses attributs
    /// resistent serait une regression pour un gain nul.
    public static func dateDeModification(de url: URL) -> Date? {
        let attributs = try? FileManager.default.attributesOfItem(atPath: url.path)

        return attributs?[.modificationDate] as? Date
    }

    /// Zones lues pour former la signature.
    ///
    /// Un conteneur assez petit est lu en entier : trois zones de quatre kilo
    /// octets couvriraient deja tout, decouper n apporterait rien.
    private static func plagesDEchantillon(taille: UInt64) -> [(offset: UInt64, longueur: Int)] {
        guard taille > 0 else { return [] }

        let bloc = UInt64(tailleDEchantillon)
        guard taille > 3 * bloc else { return [(0, Int(taille))] }

        return [
            (0, tailleDEchantillon),
            (taille / 2 - bloc / 2, tailleDEchantillon),
            (taille - bloc, tailleDEchantillon),
        ]
    }

    /// Convertit une date en nanosecondes, sans jamais deborder.
    ///
    /// Un systeme de fichiers peut rendre une date absurde, `distantFuture` par
    /// exemple. La conversion directe ferait alors sauter le processus sur un
    /// depassement d entier, pour un champ qui n est qu un indice de fraicheur.
    private static func nanosecondes(_ date: Date) -> Int64 {
        let secondes = date.timeIntervalSince1970
        let limite = Double(Int64.max) / 1_000_000_000

        return Int64(min(max(secondes, -limite), limite) * 1_000_000_000)
    }
}
