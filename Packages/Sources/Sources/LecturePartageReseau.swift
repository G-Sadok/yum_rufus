import Archive
import Core
import Foundation
import ImagePipeline

//
// LecturePartageReseau
//
// Comment les octets d une page arrivent, quand la source est un partage reseau.
//
// Trois chemins, et un seul est le sujet de la fonctionnalite.
//
// Le premier est le chapitre range dans un CBZ. Il passe par
// `ConteneurDePartage`, donc par la lecture en flux : seuls l index central et
// les octets de l entree demandee traversent le reseau, et le fichier n est
// jamais copie sur le disque de l appareil, meme partiellement. C est le premier
// critere de la fonctionnalite.
//
// Le deuxieme est le chapitre range en dossier d images. Une page y est un
// fichier entier, qui se lit d un bloc parce qu une image ne s affiche pas a
// moitie. La lecture reste decoupee en plages : un serveur WebDAV derriere un
// proxy refuse couramment une reponse de plus de quelques mega octets d un seul
// tenant, et un serveur SMB borne la sienne a la taille negociee.
//
// Le troisieme est le format sans acces aleatoire, TAR ou PDF. Celui la est
// rapatrie en entier, et c est assume : un TAR n a pas d index et se parcourt
// en entier pour en construire un, donc le lire par plages couterait tout le
// fichier de toute facon, en plus lent. C est la meme conclusion que pour
// Jellyfin et OPDS.
//

extension SourcePartageReseau {
    // MARK: Pages

    /// Le chapitre porte par cet identifiant.
    func chapitreLocal(_ identifiant: String) async throws -> ChapitreLocal {
        guard let trouve = try await analyse().chapitre(identifiant) else {
            throw ErreurDeSource.chapitreIntrouvable(identifiant: identifiant)
        }

        return trouve.chapitre
    }

    /// Pages d un chapitre range sous forme de dossier d images.
    ///
    /// L entree est nommee meme si le chapitre n est pas une archive, et c est
    /// volontaire : `PageDistante.estDansUnConteneur` dit alors la seule chose
    /// qui compte pour l appelant, que ces octets ne s obtiennent pas par une
    /// requete mais par la source.
    func pagesPosees(dans chapitre: ChapitreLocal) async throws -> [PageDistante] {
        let entrees = try await partage.lister(chapitre.identifiant)
        let fichiers = entrees.filter { $0.estDossier == false }
        let tailles = Dictionary(fichiers.map { ($0.nom, $0.taille) }, uniquingKeysWith: { premiere, _ in premiere })
        let noms = EntreesDArchive.pages(parmi: fichiers.map(\.nom))

        return noms.enumerated().map { index, nom in
            PageDistante(
                identifiantChapitre: chapitre.identifiant,
                index: index,
                emplacement: adresse.appending(path: chapitre.identifiant),
                entree: nom,
                octets: tailles[nom].map(Int.init)
            )
        }
    }

    /// Pages d un chapitre range dans un conteneur.
    ///
    /// Seul l index du conteneur traverse le reseau, jamais une page. Pour un
    /// format que la lecture en flux ne prend pas en charge, le conteneur est
    /// rapatrie ici, et le dire une fois evite de le refaire a chaque page.
    func pagesDArchive(_ chapitre: ChapitreLocal, format: String) async throws -> [PageDistante] {
        let references = try await ConteneurDePartage.litEnFlux(format)
            ? conteneur(pour: chapitre).pages()
            : referencesApresRapatriement(de: chapitre, format: format)

        return references.map { reference in
            PageDistante(
                identifiantChapitre: chapitre.identifiant,
                index: reference.index,
                emplacement: adresse.appending(path: chapitre.identifiant),
                entree: reference.nom,
                octets: reference.tailleOctets
            )
        }
    }

    // MARK: Lecture en flux

    /// Le conteneur en flux de ce chapitre, ouvert au premier appel.
    func conteneur(pour chapitre: ChapitreLocal) async throws -> ConteneurDePartage {
        if let ouvert = conteneurs[chapitre.identifiant] {
            return ouvert
        }

        let attributs = try await partage.attributs(de: chapitre.identifiant)
        let ouvert = ConteneurDePartage(
            partage: partage,
            chemin: chapitre.identifiant,
            taille: attributs.taille,
            nom: chapitre.titre,
            reglages: reglages
        )
        conteneurs[chapitre.identifiant] = ouvert

        return ouvert
    }

    /// Les octets d une page lue en flux dans son conteneur.
    func octetsEnFlux(de chapitre: ChapitreLocal, index: Int) async throws -> Data {
        let ouvert = try await conteneur(pour: chapitre)
        let references = try await ouvert.pages()

        guard references.indices.contains(index) else {
            throw ErreurDeDocument.indexHorsBornes(demande: index, nombrePages: references.count)
        }

        return try await ouvert.donnees(page: references[index])
    }

    /// Les octets d un fichier entier du partage, lus par plages.
    func octets(de chemin: String) async throws -> Data {
        let attributs = try await partage.attributs(de: chemin)
        let taille = attributs.taille

        guard taille > 0 else {
            return Data()
        }

        var assemble = Data()
        var position: UInt64 = 0

        while position < taille {
            try Task.checkCancellation()

            let longueur = Int(min(UInt64(reglages.tailleDeBloc), taille - position))
            let morceau = try await partage.lire(chemin, a: position, longueur: longueur)

            guard morceau.isEmpty == false else {
                throw ErreurDeDocument.conteneurTronque(chemin: chemin)
            }

            assemble.append(morceau)
            position += UInt64(min(morceau.count, longueur))
        }

        return assemble
    }

    // MARK: Formats sans acces aleatoire

    /// Rapatrie le conteneur d un chapitre, ou rend celui deja range.
    private func rapatrier(_ chapitre: ChapitreLocal, format: String) async throws -> URL {
        let fichier = cache.fichier(chapitre: chapitre.identifiant, format: format)

        guard cache.contient(fichier) == false else {
            return fichier
        }

        let octets = try await octets(de: chapitre.identifiant)
        try cache.ecrire(octets, dans: fichier)

        return fichier
    }

    /// Les references de pages d un conteneur rapatrie.
    private func referencesApresRapatriement(
        de chapitre: ChapitreLocal,
        format: String
    ) async throws -> [ReferencePage] {
        let fichier = try await rapatrier(chapitre, format: format)
        let document = try LecteurDeConteneur.ouvrir(fichier, format: format, nom: chapitre.titre)

        return try document.toutesLesPages()
    }

    /// Les octets d une page d un conteneur rapatrie.
    func octetsApresRapatriement(
        de chapitre: ChapitreLocal,
        format: String,
        page: PageDistante
    ) async throws -> Data {
        let fichier = try await rapatrier(chapitre, format: format)
        let document = try LecteurDeConteneur.ouvrir(fichier, format: format, nom: chapitre.titre)

        return try document.donneesPage(document.referencePage(page.index))
    }
}
