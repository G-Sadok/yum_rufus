import Foundation

//
// DepotICloudDuSysteme
//
// L implementation reelle de `DepotICloud`, posee sur le systeme de fichiers.
//
// L avancement se lit dans les valeurs de ressource de l element et non par une
// requete de metadonnees. `NSMetadataQuery` donne un pourcentage exact, mais il
// veut une boucle d execution et un conteneur d ubiquite declare par
// l application : un paquet metier n a ni l une ni l autre, et le controle 7
// interdit d aller chercher la couche qui les a. Le rapport entre les octets
// reellement alloues et le poids annonce donne la meme information a un bloc de
// systeme de fichiers pres, ce qui est sous la resolution d une barre de
// progression.
//
// Le substitut est traite a part, et il le faut. Ses valeurs de ressource
// decrivent le petit fichier d annonce, pas le fichier annonce : les lire sans
// precaution ferait dire au depot qu un chapitre de 200 Mo est present et pese
// quelques centaines d octets.
//

/// Depot iCloud pose sur le systeme de fichiers de l appareil.
public struct DepotICloudDuSysteme: DepotICloud {
    /// Cle du poids annonce dans le contenu d un substitut.
    private static let cleDeTailleAnnoncee = "NSURLFileSizeKey"

    public init() {}

    public func etat(de fichier: URL) throws -> EtatDeFichierICloud {
        if EmplacementICloud.estUnSubstitut(fichier.lastPathComponent) {
            return EtatDeFichierICloud(
                presence: .absent,
                octetsPresents: 0,
                octetsAttendus: Self.tailleAnnoncee(par: fichier)
            )
        }

        let valeurs = try fichier.resourceValues(forKeys: [
            .isUbiquitousItemKey,
            .ubiquitousItemDownloadingStatusKey,
            .ubiquitousItemIsDownloadingKey,
            .ubiquitousItemDownloadingErrorKey,
            .fileSizeKey,
            .totalFileAllocatedSizeKey,
        ])

        if let erreur = valeurs.ubiquitousItemDownloadingError {
            throw erreur
        }

        let attendus = Int64(valeurs.fileSize ?? 0)
        let presents = min(Int64(valeurs.totalFileAllocatedSize ?? 0), attendus)

        // Un fichier ordinaire est toujours la, en entier. Le tester avant
        // l etat de telechargement evite de traiter le contenu d un dossier
        // local comme un contenu a rapatrier.
        guard valeurs.isUbiquitousItem == true,
              valeurs.ubiquitousItemDownloadingStatus == .notDownloaded
        else {
            return EtatDeFichierICloud(presence: .local, octetsPresents: attendus, octetsAttendus: attendus)
        }

        return EtatDeFichierICloud(
            presence: valeurs.ubiquitousItemIsDownloading == true ? .enCours : .absent,
            octetsPresents: presents,
            octetsAttendus: attendus
        )
    }

    public func demanderLeTelechargement(de fichier: URL) throws {
        let gestionnaire = FileManager.default

        do {
            try gestionnaire.startDownloadingUbiquitousItem(at: fichier)
        } catch {
            // Le systeme attend tantot le substitut, tantot le vrai nom, selon
            // la facon dont le dossier est monte. Le second essai porte sur
            // l autre nom, et son echec est celui qui remonte.
            let autre = EmplacementICloud.visible(fichier)

            guard autre != fichier else { throw error }

            try gestionnaire.startDownloadingUbiquitousItem(at: autre)
        }
    }

    /// Poids annonce par un substitut, lu dans sa liste de proprietes.
    ///
    /// Rend zero quand le contenu ne se laisse pas lire. La progression est
    /// alors sans echelle jusqu au premier octet recu, ce qui reste preferable
    /// a un refus d ouvrir le chapitre.
    private static func tailleAnnoncee(par substitut: URL) -> Int64 {
        guard let octets = try? Data(contentsOf: substitut),
              let lue = try? PropertyListSerialization.propertyList(from: octets, format: nil),
              let proprietes = lue as? [String: Any],
              let taille = proprietes[cleDeTailleAnnoncee] as? NSNumber
        else {
            return 0
        }

        return taille.int64Value
    }
}
