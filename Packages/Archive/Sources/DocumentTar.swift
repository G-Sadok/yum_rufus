import Core
import Foundation

//
// DocumentTar
//
// Implementation de `DocumentLocal` pour les conteneurs TAR, donc pour les CBT.
//
// Le TAR ne porte aucun index, la section 5.3 impose donc de le balayer une fois
// et de conserver le resultat. C est ce que fait l ouverture : elle calcule
// l empreinte du fichier, demande au cache l index qui lui correspond, et ne
// balaie que si le cache ne repond pas. La seconde ouverture d une meme archive
// inchangee ne relit que les douze kilo octets de l empreinte.
//
// Le TAR ne compresse rien. Une fois l index connu, lire la page N est donc une
// simple lecture a une position donnee, sans le detour par un decompresseur que
// le ZIP impose.
//

/// Un conteneur TAR ou CBT ouvert en lecture.
public struct DocumentTar: DocumentLocal {
    /// Extensions de fichier que ce lecteur prend en charge.
    public static let extensions: Set<String> = ["tar", "cbt"]

    private let source: any SourceDOctets
    private let entreesParNom: [String: EntreeTar]
    private let references: [ReferencePage]
    private let entreeDeMetadonnees: EntreeTar?

    /// Indique que l index a ete relu depuis le cache au lieu d etre recalcule.
    ///
    /// Expose parce que c est la seule facon de prouver le critere de la
    /// section 5.3 : sans lui, on ne peut affirmer qu une seconde ouverture ne
    /// rescanne pas qu en mesurant un temps, ce qui depend de la machine.
    public let indexVenaitDuCache: Bool

    public var nombrePages: Int {
        references.count
    }

    /// Ouvre le conteneur porte par une source d octets.
    ///
    /// - Parameters:
    ///   - source: octets du conteneur.
    ///   - dateDeModification: date du fichier, quand la source en vient. Elle
    ///     entre dans l empreinte et rend la detection d un changement plus
    ///     fine.
    ///   - cache: rangement des index. `nil` force un balayage a chaque
    ///     ouverture, ce dont seuls les tests ont besoin.
    /// - Throws: `ErreurDeDocument.conteneurIllisible` si les octets ne forment
    ///   pas un TAR, `ErreurDeDocument.aucunePage` si l archive ne porte aucune
    ///   image affichable.
    public init(
        source: any SourceDOctets,
        dateDeModification: Date? = nil,
        cache: (any CacheDIndexDArchive)? = CacheDIndexSurDisque.partage
    ) throws {
        let empreinte = try EmpreinteDeConteneur.calculer(
            pour: source,
            dateDeModification: dateDeModification
        )

        let index: IndexTar
        if let conserve = cache?.index(pour: empreinte) {
            index = conserve
            indexVenaitDuCache = true
        } else {
            index = try IndexTar.scanner(source)
            cache?.enregistrer(index, pour: empreinte)
            indexVenaitDuCache = false
        }

        let entreesParNom = Dictionary(
            index.entrees.map { ($0.nom, $0) },
            uniquingKeysWith: { premiere, _ in premiere }
        )

        let noms = EntreesDArchive.pages(parmi: index.entrees.map(\.nom))
        guard noms.isEmpty == false else {
            throw ErreurDeDocument.aucunePage(chemin: source.nom)
        }

        self.source = source
        self.entreesParNom = entreesParNom
        references = noms.enumerated().map { rang, nom in
            ReferencePage(
                index: rang,
                nom: nom,
                tailleOctets: Int(entreesParNom[nom]?.taille ?? 0)
            )
        }
        entreeDeMetadonnees = EntreesDArchive
            .metadonneesComic(parmi: index.entrees.map(\.nom))
            .flatMap { entreesParNom[$0] }
    }

    /// Ouvre le conteneur range a l emplacement indique.
    public init(
        contenuDe url: URL,
        cache: (any CacheDIndexDArchive)? = CacheDIndexSurDisque.partage
    ) throws {
        try self.init(
            source: OctetsEnMemoire(contenuDe: url),
            dateDeModification: EmpreinteDeConteneur.dateDeModification(de: url),
            cache: cache
        )
    }

    public func referencePage(_ index: Int) throws -> ReferencePage {
        guard references.indices.contains(index) else {
            throw ErreurDeDocument.indexHorsBornes(demande: index, nombrePages: references.count)
        }

        return references[index]
    }

    public func donneesPage(_ reference: ReferencePage) throws -> Data {
        guard let entree = entreesParNom[reference.nom] else {
            throw ErreurDeDocument.entreeIntrouvable(nom: reference.nom)
        }

        return try octets(de: entree)
    }

    public func donneesDeMetadonnees() throws -> Data? {
        guard let entreeDeMetadonnees else { return nil }

        return try octets(de: entreeDeMetadonnees)
    }

    /// Rend les octets d une entree, positions verifiees.
    ///
    /// L index peut venir du cache, donc d une execution anterieure. Les bornes
    /// sont donc revalidees ici plutot que supposees : un index qui deborderait
    /// du fichier doit produire une erreur typee, pas une lecture hasardeuse.
    private func octets(de entree: EntreeTar) throws -> Data {
        guard entree.taille <= UInt64(Int.max) else {
            throw ErreurDeDocument.entreeCorrompue(nom: entree.nom)
        }

        return try source.lire(a: entree.offset, longueur: Int(entree.taille))
    }
}
