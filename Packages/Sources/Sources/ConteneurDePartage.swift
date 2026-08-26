import Archive
import Core
import Foundation

//
// ConteneurDePartage
//
// L archive posee sur un partage reseau, ouverte sans etre copiee.
//
// C est la moitie asynchrone du mecanisme decrit dans `OctetsDePartage`. Le
// lecteur d archive est synchrone et ne connait que `SourceDOctets` ; le partage
// est asynchrone et ne connait que des plages. Cette classe fait le va et vient
// entre les deux : elle rejoue l operation synchrone sur la vue des octets deja
// rapatries, et chaque fois que la vue signale une plage absente, elle la
// rapatrie et recommence.
//
// Rejouer plutot que reprendre la ou l on s est arrete peut surprendre. C est
// pourtant ce qui coute le moins. Une reprise supposerait de suspendre l analyse
// du format ZIP au milieu, donc de la reecrire ici, hors du paquet Archive qui
// en a la charge. Le rejeu, lui, ne coute que la relecture d un index deja en
// memoire, quelques dizaines de microsecondes, et il tombe a zero ligne de
// duplication. Le nombre de tours est borne, et pour un CBZ reel il vaut trois :
// la queue du fichier, l index central, puis les octets de l entree.
//
// Seuls les conteneurs a acces aleatoire passent par ici, donc le ZIP et le CBZ.
// Le TAR n a pas d index et se parcourt en entier pour en construire un, ce qui
// reviendrait a rapatrier tout le fichier par blocs de un demi mega octet, plus
// lentement qu un telechargement direct. Le PDF est lu par PDFKit, qui exige un
// fichier. Les deux passent par le rapatriement complet de `CacheDeConteneurs`,
// comme chez Jellyfin et OPDS, et la source le dit dans son commentaire.
//

/// Une archive ZIP lue directement sur un partage reseau.
public actor ConteneurDePartage {
    /// Formats que la lecture en flux prend en charge.
    public static let formatsEnFlux: Set<String> = DocumentZip.extensions

    /// Nombre maximal de tours de rejeu pour une seule operation.
    ///
    /// Un CBZ reel en demande trois. La borne existe pour qu une archive dont
    /// la lecture redemanderait sans cesse la meme plage, cas d une taille
    /// annoncee fausse, s arrete au lieu de tourner sans fin.
    static let rejeuxMaximum = 32

    private let tampon: TamponDePartage
    private let nom: String

    /// Nombre d octets reellement transmis par le partage depuis l ouverture.
    public var octetsRapatries: UInt64 {
        get async { await tampon.octetsRapatries }
    }

    /// Ouvre un conteneur pose sur un partage, sans lire un seul octet.
    ///
    /// Rien ne part sur le reseau ici. La premiere plage est demandee au premier
    /// appel de `pages()`, ce qui laisse une source enumerer des chapitres sans
    /// payer l ouverture de ceux que l utilisateur n ouvrira pas.
    public init(
        partage: any PartageReseau,
        chemin: String,
        taille: UInt64,
        nom: String,
        reglages: ReglagesDeFlux = .parDefaut
    ) {
        tampon = TamponDePartage(
            partage: partage,
            chemin: chemin,
            taille: taille,
            nom: nom,
            reglages: reglages
        )
        self.nom = nom
    }

    /// Vrai quand ce format se lit en flux, sans rapatriement complet.
    public static func litEnFlux(_ format: String) -> Bool {
        formatsEnFlux.contains(format.lowercased())
    }

    // MARK: Lecture

    /// Les pages du conteneur, dans l ordre de lecture.
    ///
    /// Seul l index central traverse le reseau, jamais les pages.
    public func pages() async throws -> [ReferencePage] {
        try await executer { document in
            try (0..<document.nombrePages).map { try document.referencePage($0) }
        }
    }

    /// Les octets bruts d une page.
    public func donnees(page reference: ReferencePage) async throws -> Data {
        try await executer { document in
            try document.donneesPage(reference)
        }
    }

    /// Les octets du `ComicInfo.xml` du conteneur, s il en porte un.
    public func donneesDeMetadonnees() async throws -> Data? {
        try await executer { document in
            try document.donneesDeMetadonnees()
        }
    }

    /// Le commentaire global de l archive, ou vit le `ComicBookInfo`.
    public func commentaireDeConteneur() async throws -> String? {
        try await executer { document in
            document.commentaireDeConteneur
        }
    }

    /// Oublie les octets rapatries.
    ///
    /// A appeler quand le fichier distant a change : ce qui est retenu decrit
    /// alors une archive qui n existe plus.
    public func vider() async {
        await tampon.vider()
    }

    // MARK: Rejeu

    /// Execute une operation synchrone sur le conteneur, en rapatriant a la
    /// demande les plages qui lui manquent.
    ///
    /// - Throws: `ErreurDeDocument.conteneurIllisible` quand la borne de rejeu
    ///   est atteinte, ce qui signale une archive dont les positions annoncees
    ///   ne convergent pas, et sinon l erreur levee par l operation ou par le
    ///   rapatriement.
    private func executer<Valeur: Sendable>(
        _ operation: (DocumentZip) throws -> Valeur
    ) async throws -> Valeur {
        for _ in 0..<Self.rejeuxMaximum {
            try Task.checkCancellation()

            do {
                return try await operation(DocumentZip(source: tampon.vue()))
            } catch let absente as PlageAbsente {
                try await tampon.hydrater(offset: absente.offset, longueur: absente.longueur)
            }
        }

        throw ErreurDeDocument.conteneurIllisible(chemin: nom)
    }
}
