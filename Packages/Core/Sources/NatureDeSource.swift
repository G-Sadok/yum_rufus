import Foundation

//
// NatureDeSource
//
// Ce qu une source expose a l ecran Parcourir, tableau 4.4 de DESIGN-SPEC.md.
//
// Le tableau distingue trois formes de sous titre et deux formes de pastille.
// Il ne le dit pas type par type, il le dit par nature : une source locale
// porte sa version, un serveur porte son adresse et son etat, une extension
// porte sa version et sa langue. La nature vit donc dans le modele, et la vue
// ne teste jamais un type de source pour decider ce qu elle affiche.
//

/// Ce qu une source montre dans la liste de l ecran Parcourir.
public enum NatureDeSource: String, Sendable, Codable, CaseIterable, Hashable {
    /// Un dossier ou une reception posee sur l appareil. Pas d adresse, pas de
    /// pastille d etat : rien de distant ne peut cesser de repondre.
    case locale

    /// Un serveur ou un partage joignable par le reseau. Adresse et pastille.
    case serveur

    /// Une extension declarative interpretee par nos soins. Version et langue.
    case extensionDeclarative
}

extension TypeDeSource {
    /// Ce que ce type de source montre dans la liste, tableau 4.4.
    public var nature: NatureDeSource {
        switch self {
        case .fichiersLocaux, .iCloudDrive, .transfertWiFi: .locale
        case .komga, .kavita, .jellyfin, .opds, .smb, .nfs, .webdav, .depotExtensions: .serveur
        case .extensionDeclarative: .extensionDeclarative
        }
    }

    /// Vrai quand la ligne porte une pastille d etat de connexion.
    ///
    /// Le tableau 4.4 ne pose aucune pastille sur une source locale. Une
    /// extension n en porte pas non plus : son sous titre annonce une version
    /// et une langue, pas une joignabilite.
    public var porteUnePastilleDEtat: Bool {
        nature == .serveur
    }
}
