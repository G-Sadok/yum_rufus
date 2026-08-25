import CryptoKit
import Foundation

//
// CacheDIndexDArchive
//
// Ou vit l index d un conteneur qui n en porte pas, entre deux ouvertures.
//
// Le contrat tient en deux gestes : rendre l index deja calcule pour une
// empreinte, ou l enregistrer. L empreinte est la cle : deux fichiers de meme
// chemin mais de contenu different n ont pas la meme, et le cache n a donc
// jamais a se demander s il est perime, il ne repond simplement pas.
//
// Aucun des deux gestes ne leve d erreur. Un cache est une optimisation : un
// disque plein, un dossier en lecture seule ou un fichier illisible doivent
// couter un balayage, jamais l ouverture du chapitre. Les erreurs sont donc
// absorbees ici, et nulle part ailleurs.
//

/// Rangement d index d archive entre deux ouvertures.
public protocol CacheDIndexDArchive: Sendable {
    /// Rend l index deja calcule pour cette empreinte, s il existe.
    func index(pour empreinte: EmpreinteDeConteneur) -> IndexTar?

    /// Range l index sous cette empreinte, en ecrasant ce qui s y trouvait.
    func enregistrer(_ index: IndexTar, pour empreinte: EmpreinteDeConteneur)
}

/// Ce qui est reellement ecrit sur disque pour un conteneur.
///
/// L empreinte est rangee avec l index, et non deduite du nom de fichier. Le nom
/// de fichier n est qu un condense du chemin : deux versions successives de la
/// meme archive se rangent au meme endroit, et c est la comparaison d empreinte
/// relue ici qui distingue l index encore valable de l index perime.
struct IndexPersiste: Codable {
    let version: Int
    let empreinte: EmpreinteDeConteneur
    let entrees: [EntreeTar]
}

/// Cache adosse a un dossier de caches du systeme.
public struct CacheDIndexSurDisque: CacheDIndexDArchive {
    /// Dossiers ou vivent les index, sous le dossier de caches du systeme.
    private static let composantsDuDossier = ["Tsuzuki", "IndexDArchive"]

    /// Cache partage par toutes les ouvertures de l application.
    public static let partage = CacheDIndexSurDisque()

    private let dossier: URL

    /// Ouvre un cache dans le dossier indique.
    ///
    /// - Parameter dossier: emplacement des index. Par defaut le dossier de
    ///   caches du systeme, que celui ci peut vider quand la place manque, ce
    ///   qui est exactement le comportement voulu pour une donnee recalculable.
    public init(dossier: URL? = nil) {
        self.dossier = dossier ?? CacheDIndexSurDisque.dossierParDefaut()
    }

    public func index(pour empreinte: EmpreinteDeConteneur) -> IndexTar? {
        guard let donnees = try? Data(contentsOf: fichier(pour: empreinte)) else { return nil }
        guard let persiste = try? JSONDecoder().decode(IndexPersiste.self, from: donnees) else {
            return nil
        }
        guard persiste.version == IndexTar.versionDeFormat else { return nil }
        guard persiste.empreinte == empreinte else { return nil }

        return IndexTar(entrees: persiste.entrees)
    }

    public func enregistrer(_ index: IndexTar, pour empreinte: EmpreinteDeConteneur) {
        let persiste = IndexPersiste(
            version: IndexTar.versionDeFormat,
            empreinte: empreinte,
            entrees: index.entrees
        )

        guard let donnees = try? JSONEncoder().encode(persiste) else { return }

        try? FileManager.default.createDirectory(
            at: dossier,
            withIntermediateDirectories: true
        )
        // L ecriture atomique evite qu une interruption laisse un index tronque,
        // qui serait relu comme un index valable et rendrait des positions
        // fausses jusqu a la prochaine modification du conteneur.
        try? donnees.write(to: fichier(pour: empreinte), options: .atomic)
    }

    /// Emplacement de l index d un conteneur.
    ///
    /// Le nom vient d un condense SHA 256 du chemin, pour trois raisons : il
    /// tient dans un nom de fichier quelle que soit la profondeur de
    /// l arborescence, il ne depose ni titre de serie ni nom d utilisateur en
    /// clair dans le dossier de caches, et il est stable d une execution a
    /// l autre, ce que le hachage de la bibliotheque standard n est pas.
    private func fichier(pour empreinte: EmpreinteDeConteneur) -> URL {
        let condense = SHA256.hash(data: Data(empreinte.identite.utf8))
        let nom = condense.map { String(format: "%02x", $0) }.joined()

        return dossier.appendingPathComponent(nom + ".json")
    }

    private static func dossierParDefaut() -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        var chemin = caches ?? FileManager.default.temporaryDirectory

        for composant in composantsDuDossier {
            chemin = chemin.appendingPathComponent(composant, isDirectory: true)
        }

        return chemin
    }
}
