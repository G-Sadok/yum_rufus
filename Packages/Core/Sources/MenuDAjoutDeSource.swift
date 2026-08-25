import Foundation

//
// MenuDAjoutDeSource
//
// Le menu plus de l ecran Parcourir, section 5.3 de DESIGN-SPEC.md. Douze
// entrees, dans un ordre impose, un separateur apres la premiere.
//
// L ordre vit ici et non dans la vue pour la meme raison que le tableau des
// actions de source : une liste declarative se compare au document dans un
// test, une suite d entrees ecrites a la main dans un menu SwiftUI ne se
// compare a rien. La recette de la section 9 exige explicitement que ce menu
// compte douze entrees.
//
// Chaque entree designe un `TypeDeSource`. Les douze entrees couvrent les douze
// cas de l enumeration, sans doublon et sans oubli, ce que la suite de tests
// verifie dans les deux sens.
//

/// Une entree du menu d ajout de l ecran Parcourir.
public struct EntreeDuMenuDAjout: Sendable, Hashable, Identifiable {
    /// Type de source que l entree configure.
    public let type: TypeDeSource

    /// Libelle tel que le document l ecrit.
    ///
    /// Il ne s affiche jamais : une vue passe par le catalogue de chaines. Il
    /// existe pour que la suite de tests compare l ordre et le contenu du menu
    /// a la section 5.3 sans recopier cette section.
    public let nomDuDocument: String

    public init(type: TypeDeSource, nomDuDocument: String) {
        self.type = type
        self.nomDuDocument = nomDuDocument
    }

    public var id: TypeDeSource {
        type
    }
}

/// Le menu plus de l ecran Parcourir, section 5.3.
public enum MenuDAjoutDeSource {
    /// Les douze entrees, dans l ordre impose.
    public static let entrees: [EntreeDuMenuDAjout] = [
        EntreeDuMenuDAjout(type: .transfertWiFi, nomDuDocument: "Transfert Wi-Fi"),
        EntreeDuMenuDAjout(type: .komga, nomDuDocument: "Ajouter un serveur Komga"),
        EntreeDuMenuDAjout(type: .kavita, nomDuDocument: "Ajouter un serveur Kavita"),
        EntreeDuMenuDAjout(type: .jellyfin, nomDuDocument: "Ajouter un serveur Jellyfin"),
        EntreeDuMenuDAjout(type: .opds, nomDuDocument: "Ajouter un catalogue OPDS"),
        EntreeDuMenuDAjout(type: .smb, nomDuDocument: "Ajouter SMB / NAS"),
        EntreeDuMenuDAjout(type: .nfs, nomDuDocument: "Ajouter un partage NFS"),
        EntreeDuMenuDAjout(type: .webdav, nomDuDocument: "Ajouter un serveur WebDAV"),
        EntreeDuMenuDAjout(type: .fichiersLocaux, nomDuDocument: "Parcourir un dossier local"),
        EntreeDuMenuDAjout(type: .iCloudDrive, nomDuDocument: "Ajouter une bibliotheque iCloud Drive"),
        EntreeDuMenuDAjout(type: .depotExtensions, nomDuDocument: "Ajouter un depot"),
        EntreeDuMenuDAjout(type: .extensionDeclarative, nomDuDocument: "Installer une extension"),
    ]

    /// Nombre d entrees du premier groupe, avant le separateur.
    ///
    /// La section 5.3 place un separateur apres la premiere entree : le
    /// transfert Wi-Fi ne configure pas une source distante, il ouvre une
    /// reception temporaire.
    public static let tailleDuPremierGroupe = 1

    /// Les entrees du premier groupe, au dessus du separateur.
    public static var premierGroupe: [EntreeDuMenuDAjout] {
        Array(entrees.prefix(tailleDuPremierGroupe))
    }

    /// Les entrees du second groupe, sous le separateur.
    public static var secondGroupe: [EntreeDuMenuDAjout] {
        Array(entrees.dropFirst(tailleDuPremierGroupe))
    }

    /// Entree qui configure ce type de source.
    public static func entree(pour type: TypeDeSource) -> EntreeDuMenuDAjout? {
        entrees.first { $0.type == type }
    }
}
