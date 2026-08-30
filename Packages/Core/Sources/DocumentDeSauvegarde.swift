import Foundation

//
// DocumentDeSauvegarde
//
// Le fichier JSON versionne que l archive de la section 10 du cahier de
// developpement contient, et les deux modes que son import propose.
//
// Le document assemble six parts, une par element de la liste de la section 10 :
// `la bibliotheque, les categories, la progression, les signets, les
// prereglages et la configuration des sources`. Chaque part porte sa propre
// version, en plus de celle du document. C est ce qui permet d ajouter un champ
// a une seule part sans faire changer de version tout le reste, donc sans
// obliger a ecrire une etape de migration pour les cinq autres.
//
// Aucun mot de passe ne peut figurer ici, et pas par filtrage. La seule part qui
// pourrait en porter un est la part sources, qui relit la colonne de
// configuration dans `ConfigurationDeSource`, un type ferme sans champ secret.
// Les identifiants ne sont meme pas atteignables : `IdentifiantsDeSource` ne
// conforme pas a `Codable` et le trousseau n est interroge nulle part sur ce
// chemin.
//

/// Ce que l import fait des donnees deja presentes.
///
/// La section 10 pose les deux modes, et l ecran de restauration fait choisir
/// avant d ecrire quoi que ce soit.
public enum ModeDImport: String, Sendable, Codable, Hashable, CaseIterable {
    /// Les donnees de la sauvegarde s ajoutent a celles deja presentes. Une
    /// entree deja connue sous le meme identifiant est mise a jour.
    case fusion

    /// Le perimetre sauvegarde est vide avant l ecriture. Ce qui n etait pas
    /// dans la sauvegarde n est pas conserve.
    case remplacement

    /// Vrai quand le mode vide le perimetre avant d ecrire.
    public var remplace: Bool {
        self == .remplacement
    }
}

/// Le fichier de sauvegarde complet, versionne.
public struct DocumentDeSauvegarde: Sendable, Codable, Hashable {
    /// Version du format du document.
    ///
    /// La version 1 ne portait que les parts sources, signets et prereglages.
    /// La version 2 ajoute la bibliotheque, les categories et la progression,
    /// et `MigrationDeSauvegarde` amene automatiquement un fichier de version 1
    /// jusqu ici.
    public static let versionCourante = 2

    public let version: Int
    public let bibliotheque: SauvegardeDeLaBibliotheque
    public let categories: SauvegardeDesCategories
    public let progression: SauvegardeDeLaProgression
    public let signets: SauvegardeDesSignets
    public let prereglages: SauvegardeDesPrereglages
    public let sources: SauvegardeDesSources

    public init(
        version: Int = DocumentDeSauvegarde.versionCourante,
        bibliotheque: SauvegardeDeLaBibliotheque,
        categories: SauvegardeDesCategories,
        progression: SauvegardeDeLaProgression,
        signets: SauvegardeDesSignets,
        prereglages: SauvegardeDesPrereglages,
        sources: SauvegardeDesSources
    ) {
        self.version = version
        self.bibliotheque = bibliotheque
        self.categories = categories
        self.progression = progression
        self.signets = signets
        self.prereglages = prereglages
        self.sources = sources
    }

    // MARK: Ecriture

    /// Encode le fichier de sauvegarde.
    ///
    /// Les cles sont triees : deux exports d un meme etat rendent alors les
    /// memes octets, ce qui rend le cycle export puis import verifiable par
    /// comparaison directe plutot que champ par champ.
    public func donnees() throws -> Data {
        let encodeur = JSONEncoder()
        encodeur.outputFormatting = [.sortedKeys]

        return try encodeur.encode(self)
    }

    // MARK: Lecture

    /// Relit un fichier de sauvegarde, en le migrant au besoin.
    ///
    /// - Throws: `ErreurDeSauvegarde.fichierIllisible` quand les octets ne
    ///   decrivent pas une sauvegarde, `.formatInconnu` quand ils viennent d une
    ///   version que celle ci ne sait pas amener a jour.
    public init(donnees: Data) throws {
        let version = try MigrationDeSauvegarde.version(de: donnees)

        // Le fichier deja a jour se decode sur ses octets d origine. Le passage
        // par la migration reecrirait ses nombres, donc ses dates.
        let aJour = version == Self.versionCourante
            ? donnees
            : try MigrationDeSauvegarde.migrer(donnees)

        guard let relu = try? JSONDecoder().decode(Self.self, from: aJour) else {
            throw ErreurDeSauvegarde.fichierIllisible
        }

        try relu.verifierLesVersions()

        self = relu
    }

    /// Verifie que le document et chacune de ses parts sont a la version que
    /// cette application sait appliquer.
    ///
    /// Le decodage synthetise par Swift ne regarde pas les numeros de version
    /// des parts. Sans ce controle, une part d une version future se lirait
    /// silencieusement avec ses seuls champs connus, ce qui est exactement la
    /// lecture de travers que la section 10 interdit.
    private func verifierLesVersions() throws {
        let attendues = [
            (version, Self.versionCourante),
            (bibliotheque.version, SauvegardeDeLaBibliotheque.versionCourante),
            (categories.version, SauvegardeDesCategories.versionCourante),
            (progression.version, SauvegardeDeLaProgression.versionCourante),
            (signets.version, SauvegardeDesSignets.versionCourante),
            (prereglages.version, SauvegardeDesPrereglages.versionCourante),
            (sources.version, SauvegardeDesSources.versionCourante),
        ]

        for (lue, courante) in attendues where lue != courante {
            throw ErreurDeSauvegarde.formatInconnu(version: lue)
        }
    }
}
