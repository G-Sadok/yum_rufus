import Foundation

//
// AnalyseJsonOpds
//
// La lecture d un flux OPDS 2.0, qui est un document JSON.
//
// La 2.0 ne ressemble pas a la 1.2. Elle ne parle pas d entrees mais de trois
// listes distinctes, `navigation` pour les sous catalogues, `publications` pour
// les fichiers a lire, et `groups` pour les rassemblements des deux. Elle
// separe aussi les metadonnees des liens, la ou Atom melange tout dans une
// entree. Le travail de ce fichier est de ramener ces trois listes a la forme
// commune de `ModeleOpds`, ou une entree porte des liens et rien d autre.
//
// Deux souplesses sont necessaires, et les deux viennent de serveurs reels.
//
// La premiere est la forme des auteurs et des sujets. La norme autorise une
// chaine, un objet nomme, ou une liste de l un ou de l autre, et les quatre
// s observent. Un decodage qui n accepterait que la liste d objets perdrait les
// auteurs de la moitie des catalogues sans rien dire.
//
// La seconde est l absence. Un flux de navigation n a pas de publications, un
// flux de serie n a pas de navigation, et un flux vide n a ni l une ni l autre.
// Toutes les listes sont donc optionnelles, et leur absence n est pas un defaut.
//

/// Lecture d un flux OPDS 2.0 au format JSON.
enum AnalyseJsonOpds {
    /// Analyse les octets d un flux JSON.
    ///
    /// - Returns: le flux lu, ou nul quand le document ne decrit pas un flux
    ///   OPDS 2.0.
    static func analyser(_ donnees: Data) -> FluxOpds? {
        guard donnees.isEmpty == false else {
            return nil
        }
        guard let document = try? JSONDecoder().decode(DocumentJsonOpds.self, from: donnees) else {
            return nil
        }

        let flux = document.flux()

        return flux.entrees.isEmpty && flux.liens.isEmpty ? nil : flux
    }
}

// MARK: - Document

/// Le document JSON d un flux OPDS 2.0, ou d un de ses groupes.
///
/// Le meme type sert aux deux : un groupe porte exactement les memes listes que
/// le flux qui le contient, et lui donner un type a part aurait duplique la
/// traduction en entrees.
private struct DocumentJsonOpds: Decodable {
    let metadata: MetadonneesJsonOpds?
    let links: [LienJsonOpds]?
    let navigation: [LienJsonOpds]?
    let publications: [PublicationJsonOpds]?
    let groups: [DocumentJsonOpds]?

    /// Le flux, dans la forme commune aux deux versions du protocole.
    ///
    /// Les entrees des groupes sont ramenees au meme niveau que les autres. Le
    /// regroupement est une presentation, pas une hierarchie : un catalogue qui
    /// range ses nouveautes dans un groupe et ses series dans un autre reste un
    /// catalogue de series, et perdre la moitie des lignes pour respecter une
    /// mise en page serait une regression visible.
    func flux() -> FluxOpds {
        let contenues = (groups ?? []).flatMap { $0.entrees() }

        return FluxOpds(
            titre: metadata?.title?.sansBlancs,
            liens: (links ?? []).map { $0.lien() },
            entrees: entrees() + contenues
        )
    }

    /// Les entrees de ce document, navigation puis publications.
    private func entrees() -> [EntreeOpds] {
        (navigation ?? []).map { $0.entreeDeNavigation() }
            + (publications ?? []).map { $0.entree() }
    }
}

/// Les metadonnees d un flux ou d une publication.
private struct MetadonneesJsonOpds: Decodable {
    let title: String?
    let identifier: String?
    let description: String?
    let language: ListeDeNomsJsonOpds?
    let author: ListeDeNomsJsonOpds?
    let subject: ListeDeNomsJsonOpds?
    let numberOfPages: Int?
    let modified: String?
    let published: String?
}

/// Une publication, donc un fichier a lire.
private struct PublicationJsonOpds: Decodable {
    let metadata: MetadonneesJsonOpds?
    let links: [LienJsonOpds]?
    let images: [LienJsonOpds]?

    func entree() -> EntreeOpds {
        // Les images sont une liste a part dans la 2.0, sans relation declaree.
        // Leur en donner une ici est ce qui permet a la couverture de se
        // retrouver par le meme chemin que dans un flux Atom.
        let couvertures = (images ?? []).map { $0.lien(relationParDefaut: RelationOpds.image) }

        return EntreeOpds(
            identifiant: metadata?.identifier?.sansBlancs,
            titre: metadata?.title?.sansBlancs ?? "",
            auteurs: metadata?.author?.noms ?? [],
            resume: metadata?.description?.sansBlancs,
            categories: metadata?.subject?.noms ?? [],
            langue: metadata?.language?.noms.first,
            miseAJour: LecteurDeDateDeServeur.lire(metadata?.published ?? metadata?.modified),
            nombreDePages: metadata?.numberOfPages,
            liens: (links ?? []).map { $0.lien() } + couvertures
        )
    }
}

/// Un lien de la 2.0, qui sert aussi d entree de navigation.
private struct LienJsonOpds: Decodable {
    let href: String?
    let type: String?
    let rel: RelationJsonOpds?
    let title: String?
    let templated: Bool?
    let properties: ProprietesJsonOpds?

    func lien(relationParDefaut: String = "") -> LienOpds {
        LienOpds(
            relation: rel?.premiere ?? relationParDefaut,
            type: type,
            adresse: href ?? "",
            titre: title?.sansBlancs,
            nombreDePages: properties?.count,
            gabarit: templated ?? false
        )
    }

    /// L entree que designe une ligne de la liste `navigation`.
    ///
    /// La relation par defaut est le sous catalogue. Un serveur qui n en
    /// declare aucune range pourtant bien cette ligne dans `navigation`, et
    /// c est cette place qui dit ce qu elle est.
    func entreeDeNavigation() -> EntreeOpds {
        EntreeOpds(
            titre: title?.sansBlancs ?? "",
            liens: [lien(relationParDefaut: RelationOpds.sousSection)]
        )
    }
}

/// Les proprietes d un lien, dont le nombre de pages de la diffusion.
private struct ProprietesJsonOpds: Decodable {
    let count: Int?
}

// MARK: - Valeurs souples

/// Une relation, que la norme autorise en chaine ou en liste de chaines.
private struct RelationJsonOpds: Decodable {
    let premiere: String?

    init(from decoder: any Decoder) throws {
        let conteneur = try decoder.singleValueContainer()

        if let texte = try? conteneur.decode(String.self) {
            premiere = texte

            return
        }

        premiere = (try? conteneur.decode([String].self))?.first
    }
}

/// Une liste de noms, que la norme autorise sous quatre formes.
///
/// Une chaine, un objet nomme, une liste de chaines, une liste d objets nommes.
/// Les quatre s observent chez des serveurs reels, et une seule d entre elles
/// est celle que les exemples de la norme montrent.
private struct ListeDeNomsJsonOpds: Decodable {
    let noms: [String]

    init(from decoder: any Decoder) throws {
        let conteneur = try decoder.singleValueContainer()

        if let liste = try? conteneur.decode([ValeurNommeeJsonOpds].self) {
            noms = liste.compactMap(\.nom)

            return
        }

        let seule = try? conteneur.decode(ValeurNommeeJsonOpds.self)
        noms = [seule?.nom].compactMap(\.self)
    }
}

/// Une valeur qui est soit une chaine, soit un objet portant un nom.
private struct ValeurNommeeJsonOpds: Decodable {
    let nom: String?

    init(from decoder: any Decoder) throws {
        let conteneur = try decoder.singleValueContainer()

        if let texte = try? conteneur.decode(String.self) {
            nom = texte.sansBlancs

            return
        }

        nom = (try? conteneur.decode(EnveloppeNommeeJsonOpds.self))?.name?.sansBlancs
    }
}

/// L objet nomme des auteurs et des sujets de la 2.0.
private struct EnveloppeNommeeJsonOpds: Decodable {
    let name: String?
}
