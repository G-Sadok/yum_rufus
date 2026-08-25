import Foundation

//
// ConfigurationDeSource
//
// Ce qu il faut savoir pour joindre une source, moins ce qui prouve qui on est.
// C est le contenu de la colonne `configurationChiffree` de la section 3.1, et
// c est aussi ce que la sauvegarde de la section 10 exporte.
//
// Le type est ferme, et c est la garantie du premier et du troisieme critere.
// Il ne porte aucun champ libre, aucun dictionnaire d options, aucune chaine
// fourre tout. Un mot de passe n a donc litteralement pas d endroit ou se
// glisser : la seule maniere d en ranger un dans la base ou dans un export
// serait d ajouter un champ ici, ce qui se voit dans un diff. Un dictionnaire
// d options aurait ete plus souple et aurait rendu la regle invisible.
//
// Le compte non plus ne figure pas ici. Il vit dans le trousseau avec le mot de
// passe, ou la ligne se suffit a elle meme, et un export ne dit alors meme pas
// sous quel nom l utilisateur se connecte a son serveur.
//

/// Ce qui peut mal tourner a la relecture d une configuration de source.
public enum ErreurDeConfigurationDeSource: Error, Sendable, Equatable {
    /// Les octets ranges dans la colonne ne decrivent pas une configuration.
    case illisible

    /// Message destine a l utilisateur, qui nomme la cause et indique la sortie.
    public var messageUtilisateur: String {
        switch self {
        case .illisible:
            "La configuration enregistree pour cette source n est plus lisible."
                + " Ouvre la feuille de configuration et enregistre la a nouveau."
        }
    }

    /// Identifiant stable pour le journal, sans aucune donnee personnelle.
    public var codeDeJournal: String {
        switch self {
        case .illisible: "configurationDeSource.illisible"
        }
    }
}

/// Comment joindre une source, sans rien de secret.
public struct ConfigurationDeSource: Sendable, Codable, Hashable {
    /// Adresse du serveur ou du catalogue. Nulle pour une source locale.
    public var adresse: URL?

    /// Chemin a l interieur du serveur, quand il en faut un.
    ///
    /// Le partage pour SMB, le sous dossier pour WebDAV, le catalogue racine
    /// pour OPDS.
    public var chemin: String?

    /// Forme d authentification que cette source attend.
    ///
    /// C est ce qui permet a la feuille de configuration de presenter les bons
    /// champs avant meme d avoir lu le trousseau, et c est tout ce que la base
    /// sait du sujet.
    public var authentification: NatureDAuthentification

    /// Vrai quand l utilisateur a confirme explicitement une adresse en clair.
    ///
    /// La section 11 exige que toute requete passe en HTTPS, et qu une
    /// exception pour un serveur local soit confirmee. Le consentement est
    /// persiste ici plutot que redemande a chaque ouverture.
    public var accepteLeHttpEnClair: Bool

    public init(
        adresse: URL? = nil,
        chemin: String? = nil,
        authentification: NatureDAuthentification = .aucune,
        accepteLeHttpEnClair: Bool = false
    ) {
        self.adresse = adresse
        self.chemin = chemin
        self.authentification = authentification
        self.accepteLeHttpEnClair = accepteLeHttpEnClair
    }

    /// Octets a ranger dans la colonne de configuration.
    public func donnees() throws -> Data {
        try JSONEncoder().encode(self)
    }

    /// Configuration relue depuis les octets de la colonne.
    ///
    /// - Throws: `ErreurDeConfigurationDeSource.illisible`.
    public init(donnees: Data) throws {
        guard let relue = try? JSONDecoder().decode(ConfigurationDeSource.self, from: donnees) else {
            throw ErreurDeConfigurationDeSource.illisible
        }

        self = relue
    }
}

extension Source {
    /// Configuration relue depuis la colonne, nulle quand la source n en a pas.
    ///
    /// - Throws: `ErreurDeConfigurationDeSource.illisible` quand la colonne
    ///   porte des octets qui ne decrivent pas une configuration. Une colonne
    ///   vide, elle, rend simplement nul : une source locale n a rien a
    ///   configurer et ce n est pas une erreur.
    public func configuration() throws -> ConfigurationDeSource? {
        guard let configurationChiffree else {
            return nil
        }

        return try ConfigurationDeSource(donnees: configurationChiffree)
    }

    /// Ecrit la configuration dans la colonne.
    ///
    /// C est le seul chemin par lequel la colonne se remplit, et il passe par
    /// un type ferme sans champ secret. Rien qui ressemble a un mot de passe ne
    /// peut donc atteindre la base par ici.
    public mutating func definirLaConfiguration(_ configuration: ConfigurationDeSource) throws {
        configurationChiffree = try configuration.donnees()
    }
}
