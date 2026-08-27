import Core
import Foundation
import GRDB

//
// MagasinDeSignets
//
// Seul point d acces aux signets persistes : pose et retrait depuis le lecteur,
// liste de l ecran de consultation, saut vers la page marquee, et part signets
// de la sauvegarde de la section 10.
//
// La table `signet` existe depuis la creation du schema, avec les six colonnes
// de la section 3.1 et l unicite du couple chapitre et page. Aucune migration
// n est donc ajoutee ici. C est cette unicite qui donne son sens au bouton
// Signet du tableau 6.5 : un second appui sur la meme page retire le signet au
// lieu d en empiler un deuxieme.
//
// La vignette n est pas fabriquee ici. Storage ne decode aucune image, et le
// paquet ImagePipeline ne connait pas la base : l appelant produit la vignette,
// puis passe son nom de fichier a la pose.
//

/// Lit et ecrit les signets de page.
public struct MagasinDeSignets: Sendable {
    private let base: BaseDeDonnees

    public init(base: BaseDeDonnees) {
        self.base = base
    }

    // MARK: Lecture

    /// Signets tels que l ecran de consultation les affiche.
    ///
    /// La jointure sur `chapitre` et `manga` remplace deux allers retours par
    /// ligne : la liste porte le titre de la serie et le numero du chapitre, que
    /// la table `signet` ne connait pas.
    public func signets() throws -> [SignetAffiche] {
        try base.ecrivain.read(Self.signets)
    }

    /// Nombre de signets poses.
    ///
    /// Un comptage plutot qu une lecture complete suivie d un `count` : la
    /// surface qui affiche un decompte n a besoin que du nombre.
    public func nombre() throws -> Int {
        try base.ecrivain.read { connexion in
            try Signet.fetchCount(connexion)
        }
    }

    /// Signet pose sur une page precise, s il existe.
    ///
    /// C est ce que la barre du lecteur interroge pour savoir si son bouton
    /// Signet doit poser ou retirer.
    public func signet(chapitre: UUID, page: Int) throws -> Signet? {
        try base.ecrivain.read { connexion in
            try Self.signet(connexion, chapitre: chapitre, page: page)
        }
    }

    /// Flux de la liste, reemis a chaque ecriture.
    ///
    /// L ecran de consultation s abonne et ne recharge jamais a la main : poser
    /// un signet depuis le lecteur met la liste a jour sans que personne ne
    /// pense a le demander.
    public func flux() -> AsyncThrowingStream<[SignetAffiche], any Error> {
        let observation = ValueObservation.tracking(Self.signets)
        let ecrivain = base.ecrivain

        return AsyncThrowingStream { suite in
            let tache = Task {
                do {
                    for try await signets in observation.values(in: ecrivain) {
                        suite.yield(signets)
                    }

                    suite.finish()
                } catch {
                    suite.finish(throwing: error)
                }
            }

            suite.onTermination = { _ in tache.cancel() }
        }
    }

    // MARK: Saut

    /// Position de lecture que le saut depuis l ecran des signets doit ouvrir.
    ///
    /// La position est relue en base et non recomposee par l appelant : un signet
    /// supprime pendant que la liste etait a l ecran doit faire echouer le saut
    /// plutot qu ouvrir une page au hasard.
    ///
    /// - Throws: `ErreurDeSignet.signetInconnu` quand le signet n existe plus.
    public func position(de identifiant: UUID) throws -> PositionDeLecture {
        try base.ecrivain.read { connexion in
            let lignes = try Self.lignes(connexion, filtreSurLIdentifiant: identifiant)

            guard let ligne = lignes.first else {
                throw ErreurDeSignet.signetInconnu(identifiant: identifiant)
            }

            return Self.affiche(depuis: ligne).position
        }
    }

    // MARK: Ecriture

    /// Pose un signet sur une page, ou remplace celui qui s y trouve deja.
    ///
    /// - Parameters:
    ///   - chapitre: chapitre marque.
    ///   - page: page marquee, indexee a partir de zero.
    ///   - note: note libre, nettoyee de ses espaces de bordure.
    ///   - vignette: nom du fichier de vignette produit par la chaine d images.
    ///   - date: instant de la pose.
    /// - Throws: `ErreurDeSignet.pageInvalide` pour un index negatif,
    ///   `.chapitreInconnu` quand le chapitre n existe pas.
    @discardableResult
    public func poser(
        chapitre: UUID,
        page: Int,
        note: String? = nil,
        vignette: String? = nil,
        le date: Date = Date()
    ) throws -> Signet {
        try base.ecrivain.write { connexion in
            try OrdreDesSignets.verifierLaPage(page)
            try Self.verifierLeChapitre(connexion, chapitre)

            // L identifiant du signet deja pose est repris, pour que la vignette
            // et la note remplacent les precedentes au lieu de laisser deux
            // lignes que l unicite refuserait de toute maniere.
            let existant = try Self.signet(connexion, chapitre: chapitre, page: page)

            let signet = Signet(
                id: existant?.id ?? UUID(),
                chapitreId: chapitre,
                pageIndex: page,
                note: OrdreDesSignets.noteNettoyee(note),
                dateCreation: existant?.dateCreation ?? date,
                vignetteLocale: vignette ?? existant?.vignetteLocale
            )

            try signet.upsert(connexion)

            return signet
        }
    }

    /// Pose le signet de cette page, ou retire celui qui s y trouve deja.
    ///
    /// C est le comportement du bouton Signet de la barre du lecteur, tableau
    /// 6.5 : un appui pose, un second appui retire.
    ///
    /// - Returns: le signet pose, ou nil quand l appui a retire le precedent.
    @discardableResult
    public func basculer(
        chapitre: UUID,
        page: Int,
        note: String? = nil,
        vignette: String? = nil,
        le date: Date = Date()
    ) throws -> Signet? {
        let existant = try signet(chapitre: chapitre, page: page)

        guard existant == nil else {
            try retirer(chapitre: chapitre, page: page)

            return nil
        }

        return try poser(chapitre: chapitre, page: page, note: note, vignette: vignette, le: date)
    }

    /// Remplace la note d un signet, sans toucher a sa page ni a sa vignette.
    ///
    /// - Throws: `ErreurDeSignet.signetInconnu` quand il n existe plus.
    @discardableResult
    public func modifierLaNote(_ identifiant: UUID, en note: String?) throws -> Signet {
        try base.ecrivain.write { connexion in
            guard var signet = try Signet.fetchOne(connexion, key: identifiant) else {
                throw ErreurDeSignet.signetInconnu(identifiant: identifiant)
            }

            signet.note = OrdreDesSignets.noteNettoyee(note)
            try signet.update(connexion)

            return signet
        }
    }

    /// Retire un signet.
    ///
    /// Le fichier de vignette n est pas supprime ici, Storage n ecrit rien sur
    /// le disque en dehors de la base. L appelant le supprime avec la fabrique
    /// qui l a produit, et le nom lui est rendu pour cela.
    ///
    /// - Returns: le nom du fichier de vignette du signet retire, s il en avait
    ///   un.
    /// - Throws: `ErreurDeSignet.signetInconnu` quand il n existe plus.
    @discardableResult
    public func retirer(_ identifiant: UUID) throws -> String? {
        try base.ecrivain.write { connexion in
            guard let signet = try Signet.fetchOne(connexion, key: identifiant) else {
                throw ErreurDeSignet.signetInconnu(identifiant: identifiant)
            }

            try signet.delete(connexion)

            return signet.vignetteLocale
        }
    }

    /// Retire le signet pose sur une page, s il existe.
    ///
    /// Rien a signaler quand la page n en porte aucun : le second appui du
    /// bouton Signet ne peut pas echouer parce que quelqu un a deja retire le
    /// signet depuis un autre ecran.
    @discardableResult
    public func retirer(chapitre: UUID, page: Int) throws -> String? {
        try base.ecrivain.write { connexion in
            guard let signet = try Self.signet(connexion, chapitre: chapitre, page: page) else {
                return nil
            }

            try signet.delete(connexion)

            return signet.vignetteLocale
        }
    }

    // MARK: Sauvegarde

    /// Part signets du fichier de sauvegarde de la section 10.
    public func sauvegarde() throws -> SauvegardeDesSignets {
        try base.ecrivain.read { connexion in
            try SauvegardeDesSignets(Signet.fetchAll(connexion))
        }
    }

    /// Restaure une part signets.
    ///
    /// - Parameter enRemplacant: vrai pour vider la liste avant d ecrire, faux
    ///   pour fusionner. La section 10 pose ces deux modes a l import. En
    ///   fusion, un signet deja present sous le meme identifiant est mis a jour.
    ///
    /// Un signet dont le chapitre est absent de cette installation est ignore
    /// plutot que refuse : une sauvegarde peut contenir des series retirees
    /// depuis, et un import ne doit pas echouer en bloc pour cette raison. Un
    /// second signet deja pose sur la meme page cede la place au signet restaure,
    /// pour que la fusion ne bute pas sur l unicite du couple chapitre et page.
    public func restaurer(
        _ sauvegarde: SauvegardeDesSignets,
        enRemplacant remplacer: Bool
    ) throws {
        let restaures = sauvegarde.restaures()

        try base.ecrivain.write { connexion in
            if remplacer {
                _ = try Signet.deleteAll(connexion)
            }

            for signet in restaures {
                guard try Self.chapitreExiste(connexion, signet.chapitreId) else {
                    continue
                }

                if let occupant = try Self.signet(
                    connexion,
                    chapitre: signet.chapitreId,
                    page: signet.pageIndex
                ), occupant.id != signet.id {
                    try occupant.delete(connexion)
                }

                try signet.upsert(connexion)
            }
        }
    }

    // MARK: Acces a la connexion

    private static func signets(_ connexion: Database) throws -> [SignetAffiche] {
        try OrdreDesSignets.trier(lignes(connexion).map(affiche(depuis:)))
    }

    /// Lignes de la liste, jointes a leur chapitre et a leur serie.
    ///
    /// Le filtre optionnel evite d ecrire deux fois la meme requete pour la
    /// liste complete et pour le saut vers un signet.
    private static func lignes(
        _ connexion: Database,
        filtreSurLIdentifiant identifiant: UUID? = nil
    ) throws -> [Row] {
        let condition = identifiant == nil ? "" : "WHERE signet.id = ?"
        let arguments: StatementArguments = identifiant.map { [$0] } ?? []

        return try Row.fetchAll(
            connexion,
            sql: """
            SELECT signet.id AS id,
                   signet.chapitreId AS chapitreId,
                   signet.pageIndex AS pageIndex,
                   signet.note AS note,
                   signet.dateCreation AS dateCreation,
                   signet.vignetteLocale AS vignetteLocale,
                   chapitre.numero AS numeroDeChapitre,
                   chapitre.titre AS titreDuChapitre,
                   chapitre.nombrePages AS nombreDePages,
                   manga.id AS serieId,
                   manga.titre AS titreDeLaSerie
            FROM signet
            JOIN chapitre ON chapitre.id = signet.chapitreId
            JOIN manga ON manga.id = chapitre.mangaId
            \(condition)
            """,
            arguments: arguments
        )
    }

    private static func affiche(depuis ligne: Row) -> SignetAffiche {
        SignetAffiche(
            id: ligne["id"],
            chapitreId: ligne["chapitreId"],
            serieId: ligne["serieId"],
            titreDeLaSerie: ligne["titreDeLaSerie"],
            numeroDeChapitre: ligne["numeroDeChapitre"],
            titreDuChapitre: ligne["titreDuChapitre"],
            pageIndex: ligne["pageIndex"],
            nombreDePages: ligne["nombreDePages"] ?? 0,
            note: ligne["note"],
            dateCreation: ligne["dateCreation"],
            vignetteLocale: ligne["vignetteLocale"]
        )
    }

    private static func signet(
        _ connexion: Database,
        chapitre: UUID,
        page: Int
    ) throws -> Signet? {
        try Signet
            .filter(Column("chapitreId") == chapitre)
            .filter(Column("pageIndex") == page)
            .fetchOne(connexion)
    }

    private static func chapitreExiste(_ connexion: Database, _ identifiant: UUID) throws -> Bool {
        try Chapitre.filter(key: identifiant).fetchCount(connexion) > 0
    }

    private static func verifierLeChapitre(_ connexion: Database, _ identifiant: UUID) throws {
        guard try chapitreExiste(connexion, identifiant) else {
            throw ErreurDeSignet.chapitreInconnu(identifiant: identifiant)
        }
    }
}
