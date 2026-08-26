import Archive
import Core
import Foundation
import ImagePipeline

//
// LectureICloud
//
// Comment les octets d une page arrivent, quand la source est un dossier
// iCloud Drive.
//
// Le trajet est toujours le meme, et il tient en deux temps. On s assure que le
// fichier est sur l appareil, en le rapatriant si besoin, puis on le lit sous
// la protection du coordinateur. Aucun des deux temps ne se saute : sans le
// premier la lecture porte sur un substitut vide, sans le second elle porte sur
// un fichier que le demon de synchronisation est peut etre en train de
// remplacer.
//
// Le moment ou le rapatriement se declenche est choisi. Lister les pages d un
// chapitre range en archive demande son index central, donc le fichier : le
// telechargement part la. Lister les pages d un chapitre range en dossier
// d images ne demande que des noms, que le systeme connait sans rien
// telecharger : le rapatriement de chaque image attend sa lecture. Une grille
// qui affiche vingt chapitres ne declenche ainsi aucun telechargement.
//
// Le conteneur est rouvert a chaque page plutot que garde ouvert. C est un
// index central relu par page, sur un fichier desormais local, contre la
// garantie que chaque lecture est bien encadree par le coordinateur. Un
// document garde ouvert d une lecture a l autre survivrait au remplacement du
// fichier sous lui, et rendrait les octets d une version qui n existe plus.
//

extension SourceICloudDrive {
    // MARK: Pages

    public func pages(pour chapitre: String) async throws -> [PageDistante] {
        if let connues = pagesRetenues[chapitre] {
            return connues
        }

        guard let trouve = try await analyse().chapitre(chapitre) else {
            throw ErreurDeSource.chapitreIntrouvable(identifiant: chapitre)
        }

        let emplacement = try await acces.dossier().appending(path: trouve.chapitre.identifiant)

        do {
            let pages = switch trouve.chapitre.forme {
            case .dossierDImages:
                pagesPosees(dans: emplacement, chapitre: chapitre)
            case let .archive(format):
                try await pagesDArchive(emplacement, format: format, chapitre: trouve.chapitre)
            }

            pagesRetenues[chapitre] = pages

            return pages
        } catch {
            throw ErreurDeSource.depuis(error, source: nom)
        }
    }

    /// Pages d un chapitre range sous forme de dossier d images.
    ///
    /// Le poids reste inconnu tant que l image n est pas sur l appareil. Le
    /// deviner a partir du substitut donnerait quelques centaines d octets pour
    /// une page de plusieurs mega octets, et toute couche qui dimensionne un
    /// tampon la dessus se tromperait.
    private func pagesPosees(dans dossier: URL, chapitre: String) -> [PageDistante] {
        analyseur.imagesPosees(dans: dossier).enumerated().map { index, nom in
            let fichier = dossier.appending(path: nom)
            let octets = (try? fichier.resourceValues(forKeys: [.fileSizeKey]))?.fileSize

            return PageDistante(
                identifiantChapitre: chapitre,
                index: index,
                emplacement: fichier,
                octets: octets
            )
        }
    }

    /// Pages d un chapitre range dans un conteneur, rapatrie au besoin.
    private func pagesDArchive(
        _ emplacement: URL,
        format: String,
        chapitre: ChapitreLocal
    ) async throws -> [PageDistante] {
        try await telechargeur.assurerLaPresence(de: emplacement, identifiant: chapitre.identifiant)

        let titre = chapitre.titre
        let references = try await coordination.lire(EmplacementICloud.surLeDisque(emplacement)) { url in
            try Self.ouvrir(url, format: format, titre: titre).toutesLesPages()
        }

        return references.map { reference in
            PageDistante(
                identifiantChapitre: chapitre.identifiant,
                index: reference.index,
                emplacement: emplacement,
                entree: reference.nom,
                octets: reference.tailleOctets
            )
        }
    }

    // MARK: Octets d une page

    /// Rend les octets bruts d une page, apres l avoir rapatriee si besoin.
    ///
    /// - Throws: `ErreurDeSource`, dans le cas nomme qui correspond a ce qui
    ///   s est passe. Un telechargement qui n avance plus y arrive sous
    ///   `reseau(.delaiDepasse)` ; relancer le meme appel repart d une nouvelle
    ///   demande au systeme.
    public func donnees(page: PageDistante) async throws -> Data {
        do {
            try await telechargeur.assurerLaPresence(
                de: page.emplacement,
                identifiant: page.identifiantChapitre
            )

            let surLeDisque = EmplacementICloud.surLeDisque(page.emplacement)

            guard page.entree != nil else {
                return try await coordination.lire(surLeDisque) { try Data(contentsOf: $0) }
            }

            let format = page.emplacement.pathExtension.lowercased()
            let titre = page.emplacement.deletingPathExtension().lastPathComponent
            let index = page.index

            return try await coordination.lire(surLeDisque) { url in
                let document = try Self.ouvrir(url, format: format, titre: titre)

                return try document.donneesPage(a: index)
            }
        } catch {
            throw ErreurDeSource.depuis(error, source: nom)
        }
    }

    /// Choisit le lecteur qui correspond a l extension du conteneur.
    ///
    /// Le format decide, jamais le contenu, pour la meme raison que dans la
    /// source de fichiers locaux : un fichier renomme en .cbz reste annonce
    /// comme un ZIP, et un lecteur qui devinerait au vu des premiers octets
    /// ouvrirait sans le dire une archive que l utilisateur croit d un autre
    /// type.
    static func ouvrir(_ emplacement: URL, format: String, titre: String) throws -> any DocumentLocal {
        if DocumentZip.extensions.contains(format) {
            return try DocumentZip(contenuDe: emplacement)
        }
        if DocumentTar.extensions.contains(format) {
            return try DocumentTar(contenuDe: emplacement)
        }
        // Le PDF protege remonte ici son `ErreurDeDocument.conteneurChiffre`
        // telle quelle. C est ce que l ecran attend pour demander le mot de
        // passe, et la traduire en erreur de source la rendrait indiscernable
        // d une archive cassee.
        if DocumentPdf.extensions.contains(format) {
            return try DocumentPdf(contenuDe: emplacement)
        }

        throw ErreurDeSource.formatNonPrisEnCharge(nom: titre, format: format)
    }
}
