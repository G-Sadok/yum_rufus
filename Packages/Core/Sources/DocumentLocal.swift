import Foundation

//
// DocumentLocal
//
// Protocole de lecture d un conteneur de pages, section 5.1 du cahier de
// developpement.
//
// La section 5.1 fait aussi porter `decoder(_:tailleCible:)` par ce protocole.
// Ce projet le laisse a la chaine de traitement des images, pour une raison de
// frontiere entre paquets : la valeur rendue par ce decodage porte une image
// CoreGraphics et un budget memoire, donc des types d ImagePipeline, alors que
// Core ne depend d aucun paquet. Le conteneur rend les octets bruts d une page,
// la chaine d images decide seule du sous echantillonnage impose par la
// section 6.1. Le decodage arrive avec la fonctionnalite de chaine d images,
// sous la forme d une extension de ce protocole.
//

/// Designation stable d une page a l interieur d un document ouvert.
///
/// Une reference ne vaut que pour le document qui l a produite. La presenter a
/// un autre document leve `ErreurDeDocument.entreeIntrouvable`, plutot que de
/// rendre silencieusement la page d un autre chapitre.
public struct ReferencePage: Sendable, Hashable {
    /// Position dans l ordre de lecture, a partir de zero.
    public let index: Int

    /// Chemin de l entree a l interieur du conteneur.
    public let nom: String

    /// Taille annoncee de la page une fois decompressee, en octets.
    ///
    /// C est une annonce du conteneur, pas une mesure. Elle sert a dimensionner
    /// un tampon et a decider d une strategie, jamais a faire confiance a une
    /// archive : la taille reellement obtenue est verifiee a l extraction.
    public let tailleOctets: Int

    public init(index: Int, nom: String, tailleOctets: Int) {
        self.index = index
        self.nom = nom
        self.tailleOctets = tailleOctets
    }
}

/// Conteneur de pages ouvert, pret a servir n importe quelle page.
///
/// L implementation garantit l acces aleatoire : demander la page N ne coute
/// jamais la lecture des pages precedentes, sauf pour les formats qui rendent
/// cet acces impossible et qui basculent alors sur une extraction complete,
/// comme le prevoit la section 5.3 pour le 7z solide.
public protocol DocumentLocal: Sendable {
    /// Nombre de pages affichables, parasites et metadonnees exclus.
    var nombrePages: Int { get }

    /// Rend la reference de la page a la position demandee.
    ///
    /// - Throws: `ErreurDeDocument.indexHorsBornes` si la position sort du
    ///   document.
    func referencePage(_ index: Int) throws -> ReferencePage

    /// Rend les octets bruts de la page, dans le format du fichier d origine.
    ///
    /// - Throws: `ErreurDeDocument.entreeCorrompue` si le contenu ne correspond
    ///   pas a ce que le conteneur annonce.
    func donneesPage(_ reference: ReferencePage) throws -> Data

    /// Rend les octets du fichier de metadonnees `ComicInfo.xml`, s il existe.
    ///
    /// L analyse de ce document appartient a la fonctionnalite de metadonnees.
    /// Ici le conteneur se contente de le retrouver et de le rendre, parce que
    /// sa localisation depend du conteneur et rien d autre.
    func donneesDeMetadonnees() throws -> Data?
}

extension DocumentLocal {
    /// Rend les octets de la page a la position demandee.
    ///
    /// Raccourci des appelants qui n ont pas besoin de conserver la reference.
    public func donneesPage(a index: Int) throws -> Data {
        try donneesPage(referencePage(index))
    }

    /// Rend les references de toutes les pages, dans l ordre de lecture.
    public func toutesLesPages() throws -> [ReferencePage] {
        try (0..<nombrePages).map(referencePage)
    }
}
