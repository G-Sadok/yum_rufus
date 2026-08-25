import Core
import Foundation

//
// DocumentZip
//
// Implementation de `DocumentLocal` pour les conteneurs ZIP, donc pour les CBZ,
// qui sont des ZIP sous un autre nom.
//
// L ouverture lit l index central, une seule fois, et n ouvre aucune page. La
// liste des pages en decoule : filtrage des parasites de la section 5.3, puis
// tri naturel, tous deux tenus par Core parce qu ils valent aussi pour un
// dossier d images. Lire la page N revient ensuite a sauter a la position que
// l index donne pour son entree.
//

/// Un conteneur ZIP ou CBZ ouvert en lecture.
public struct DocumentZip: DocumentLocal {
    /// Extensions de fichier que ce lecteur prend en charge.
    public static let extensions: Set<String> = ["zip", "cbz"]

    private let source: any SourceDOctets
    private let entreesParNom: [String: EntreeZip]
    private let references: [ReferencePage]
    private let entreeDeMetadonnees: EntreeZip?

    /// Commentaire global de l archive.
    ///
    /// La section 5.3 y range le `ComicBookInfo`, lu en secours quand l archive
    /// ne porte pas de `ComicInfo.xml`. Son analyse appartient a
    /// `LectureDeMetadonnees`, ce document se contente de l exposer.
    public let commentaireDeConteneur: String?

    public var nombrePages: Int {
        references.count
    }

    /// Ouvre le conteneur porte par une source d octets.
    ///
    /// - Throws: `ErreurDeDocument.conteneurIllisible` si les octets ne forment
    ///   pas un ZIP, `ErreurDeDocument.aucunePage` si l archive ne porte aucune
    ///   image affichable.
    public init(source: any SourceDOctets) throws {
        let contenu = try IndexCentralZip.lire(source)
        let entreesParNom = Dictionary(
            contenu.entrees.map { ($0.nom, $0) },
            uniquingKeysWith: { premiere, _ in premiere }
        )

        let noms = EntreesDArchive.pages(parmi: contenu.entrees.map(\.nom))
        guard noms.isEmpty == false else {
            throw ErreurDeDocument.aucunePage(chemin: source.nom)
        }

        self.source = source
        self.entreesParNom = entreesParNom
        commentaireDeConteneur = contenu.commentaire
        references = noms.enumerated().map { rang, nom in
            ReferencePage(
                index: rang,
                nom: nom,
                tailleOctets: Int(entreesParNom[nom]?.tailleDecompressee ?? 0)
            )
        }
        entreeDeMetadonnees = EntreesDArchive
            .metadonneesComic(parmi: contenu.entrees.map(\.nom))
            .flatMap { entreesParNom[$0] }
    }

    /// Ouvre le conteneur range a l emplacement indique.
    public init(contenuDe url: URL) throws {
        try self.init(source: OctetsEnMemoire(contenuDe: url))
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

        return try LecteurDeZip.donnees(de: entree, dans: source)
    }

    public func donneesDeMetadonnees() throws -> Data? {
        guard let entreeDeMetadonnees else { return nil }

        return try LecteurDeZip.donnees(de: entreeDeMetadonnees, dans: source)
    }
}
