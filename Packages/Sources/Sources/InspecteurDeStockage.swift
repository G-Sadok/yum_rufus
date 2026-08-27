import Core
import Foundation

//
// InspecteurDeStockage
//
// La mesure et la suppression des trois familles de fichiers de la section 15,
// faites sur le disque et nulle part ailleurs.
//
// Le premier critere de la fonctionnalite tient a une seule decision : ce qui
// est affiche est ce que la mesure a lu, jamais ce que la base avait note. La
// base connait le poids qu une source a annonce, pas celui du fichier ecrit :
// une page reprise apres coupure, une qualite de telechargement changee ou une
// suppression faite hors de l application suffisent a les separer. L inspecteur
// ne lit donc que le systeme de fichiers.
//
// La taille retenue est la somme des tailles de fichier, en base mille comme la
// sous ligne de la section 4.11 qui ecrit `Termine  32 Mo`. Ce n est pas la
// taille allouee en blocs : celle ci depend du systeme de fichiers, elle
// changerait d un appareil a l autre pour le meme chapitre, et elle ne
// correspondrait a aucun autre chiffre du produit.
//
// La profondeur des elements est declaree par emplacement plutot que devinee.
// Un dossier de telechargements porte un dossier par chapitre, et un chapitre
// est ce que l ecran liste. Le cache de conteneurs porte un dossier par famille
// de source puis un dossier par source, et c est la source que l ecran liste :
// une famille regrouperait plusieurs serveurs sous une seule ligne, et vider
// cette ligne emporterait le cache d un serveur que l utilisateur ne visait pas.
//

/// Ou vit une categorie de stockage, et a quel niveau elle se liste.
public struct EmplacementDeStockage: Sendable, Hashable {
    /// Categorie logee a cet emplacement.
    public let categorie: CategorieDeStockage

    /// Dossier racine de la categorie.
    public let dossier: URL

    /// Niveau ou se trouvent les elements que l ecran de detail liste.
    ///
    /// Un pour un enfant direct du dossier racine, deux pour un petit enfant.
    public let profondeurDesElements: Int

    public init(categorie: CategorieDeStockage, dossier: URL, profondeurDesElements: Int = 1) {
        self.categorie = categorie
        self.dossier = dossier
        self.profondeurDesElements = max(1, profondeurDesElements)
    }
}

/// Les trois emplacements de la section 15.
public struct EmplacementsDuStockage: Sendable, Hashable {
    private let parCategorie: [CategorieDeStockage: EmplacementDeStockage]

    /// Construit les trois emplacements a partir de leurs dossiers.
    ///
    /// - Parameters:
    ///   - telechargements: racine du depot des chapitres telecharges.
    ///   - cacheDeChapitres: racine des caches de conteneurs, celle qui porte un
    ///     dossier par famille de source.
    ///   - cacheDImages: dossier du cache disque de la chaine d images.
    public init(telechargements: URL, cacheDeChapitres: URL, cacheDImages: URL) {
        parCategorie = [
            .chapitresTelecharges: EmplacementDeStockage(
                categorie: .chapitresTelecharges,
                dossier: telechargements
            ),
            .cacheDeChapitres: EmplacementDeStockage(
                categorie: .cacheDeChapitres,
                dossier: cacheDeChapitres,
                profondeurDesElements: 2
            ),
            .cacheDImages: EmplacementDeStockage(
                categorie: .cacheDImages,
                dossier: cacheDImages
            ),
        ]
    }

    /// Emplacement d une categorie.
    public func emplacement(de categorie: CategorieDeStockage) -> EmplacementDeStockage {
        // Les trois cles sont posees par l initialiseur, la valeur de repli
        // n est donc jamais servie. Elle existe pour que la lecture reste sure
        // sans force unwrap, que le controle 9 interdit.
        parCategorie[categorie]
            ?? EmplacementDeStockage(categorie: categorie, dossier: URL(fileURLWithPath: "/dev/null"))
    }
}

/// Ce qui peut faire echouer la gestion du stockage.
public enum ErreurDeStockage: Error, Sendable, Equatable {
    /// Le nom vise ne designe pas un element de cette categorie.
    ///
    /// Le cas couvre la remontee de dossier autant que la faute de frappe. Un
    /// nom qui n a pas ete rendu par la mesure ne peut pas etre supprime, ce qui
    /// interdit a une commande d atteindre un chemin que personne n a liste.
    case elementInconnu(nom: String)

    /// Le systeme de fichiers a refuse de supprimer l element.
    case suppressionRefusee(nom: String)
}

/// Mesure et suppression des fichiers du stockage.
public struct InspecteurDeStockageSurDisque: Sendable {
    private let emplacements: EmplacementsDuStockage

    /// Gestionnaire de fichiers du systeme.
    ///
    /// Il n est pas injecte, pour la meme raison que celui de
    /// `DepotDeChapitresSurDisque` : les tests de cet inspecteur n ont rien a
    /// simuler, ils ecrivent dans un dossier temporaire reel, ce qui est
    /// exactement ce que le code fera en production.
    private var fichiers: FileManager {
        .default
    }

    public init(emplacements: EmplacementsDuStockage) {
        self.emplacements = emplacements
    }

    // MARK: Mesure

    /// Poids reel d une categorie sur le disque.
    public func octets(de categorie: CategorieDeStockage) -> Int {
        MesureDeDossier.octets(de: emplacements.emplacement(de: categorie).dossier)
    }

    /// Poids des trois categories, tel que l ecran d ensemble le montre.
    public func inventaire() -> InventaireDuStockage {
        InventaireDuStockage(
            octetsParCategorie: Dictionary(
                uniqueKeysWithValues: CategorieDeStockage.allCases.map { ($0, octets(de: $0)) }
            )
        )
    }

    /// Elements d une categorie, chacun avec son poids reel.
    ///
    /// Un dossier absent rend une liste vide plutot qu une erreur : une
    /// installation neuve n a pas encore de cache, et l ecran de detail doit
    /// montrer son etat vide, pas son etat d erreur.
    public func pesages(de categorie: CategorieDeStockage) -> [PesageSurDisque] {
        let emplacement = emplacements.emplacement(de: categorie)

        return elements(dans: emplacement.dossier, profondeur: emplacement.profondeurDesElements)
            .map { PesageSurDisque(nom: $0.nom, octets: MesureDeDossier.octets(de: $0.url)) }
            .sorted { $0.nom < $1.nom }
    }

    // MARK: Suppression

    /// Supprime les elements nommes d une categorie.
    ///
    /// - Throws: `ErreurDeStockage.elementInconnu` quand un nom ne designe aucun
    ///   element de la categorie, `ErreurDeStockage.suppressionRefusee` quand le
    ///   systeme de fichiers refuse.
    public func supprimer(_ noms: [String], de categorie: CategorieDeStockage) throws {
        let emplacement = emplacements.emplacement(de: categorie)
        let connus = Dictionary(
            elements(dans: emplacement.dossier, profondeur: emplacement.profondeurDesElements)
                .map { ($0.nom, $0.url) },
            uniquingKeysWith: { premier, _ in premier }
        )

        for nom in noms {
            guard let url = connus[nom] else {
                throw ErreurDeStockage.elementInconnu(nom: nom)
            }

            do {
                try fichiers.removeItem(at: url)
            } catch {
                throw ErreurDeStockage.suppressionRefusee(nom: nom)
            }
        }
    }

    /// Supprime le dossier d un chapitre telecharge.
    ///
    /// - Returns: vrai quand un dossier a ete supprime, faux quand il n y en
    ///   avait pas. Le second cas n est pas une erreur : le nettoyage apres
    ///   lecture peut viser un chapitre que l utilisateur vient de supprimer a
    ///   la main.
    @discardableResult
    public func supprimerLeChapitre(_ chapitre: UUID) throws -> Bool {
        let dossier = emplacements
            .emplacement(de: .chapitresTelecharges)
            .dossier
            .appendingPathComponent(chapitre.uuidString, isDirectory: true)

        guard fichiers.fileExists(atPath: dossier.path) else {
            return false
        }

        do {
            try fichiers.removeItem(at: dossier)
        } catch {
            throw ErreurDeStockage.suppressionRefusee(nom: chapitre.uuidString)
        }

        return true
    }

    /// Chapitres dont le telechargement est pose sur le disque.
    public func chapitresPoses() -> [UUID] {
        pesages(de: .chapitresTelecharges).compactMap { UUID(uuidString: $0.nom) }
    }

    // MARK: Enumeration

    /// Un element liste, avec le chemin qui permet de le peser et de l effacer.
    private struct ElementDeStockage {
        let nom: String
        let url: URL
    }

    /// Elements d un dossier au niveau demande.
    ///
    /// Le nom rendu au niveau deux est celui du dernier composant seul, jamais
    /// le chemin. Deux sources de familles differentes ne portent pas le meme
    /// identifiant, la cle reste donc unique, et un nom sans barre oblique ne
    /// peut designer que ce que la mesure a vu.
    private func elements(dans dossier: URL, profondeur: Int) -> [ElementDeStockage] {
        let contenu = (try? fichiers.contentsOfDirectory(
            at: dossier,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        guard profondeur > 1 else {
            return contenu.map { ElementDeStockage(nom: $0.lastPathComponent, url: $0) }
        }

        return contenu.flatMap { elements(dans: $0, profondeur: profondeur - 1) }
    }
}

// MARK: Mesure d un dossier

/// Poids reel d un fichier ou d un dossier sur le disque.
public enum MesureDeDossier {
    /// Somme des tailles des fichiers contenus, zero quand rien n existe.
    ///
    /// L enumeration descend dans toute l arborescence. Un chapitre est un
    /// dossier de pages, une source est un dossier de conteneurs, et une mesure
    /// qui s arreterait au premier niveau annoncerait zero octet sur un dossier
    /// qui en porte des millions.
    public static func octets(de url: URL) -> Int {
        let fichiers = FileManager.default
        var estUnDossier: ObjCBool = false

        guard fichiers.fileExists(atPath: url.path, isDirectory: &estUnDossier) else {
            return 0
        }

        guard estUnDossier.boolValue else {
            return taille(de: url)
        }

        let cles: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
        let enumerateur = fichiers.enumerator(
            at: url,
            includingPropertiesForKeys: cles,
            options: [],
            errorHandler: nil
        )

        var total = 0

        while let element = enumerateur?.nextObject() as? URL {
            total += taille(de: element)
        }

        return total
    }

    /// Taille d un fichier ordinaire, zero pour tout le reste.
    ///
    /// Les dossiers rendent zero et non leur propre entree de repertoire :
    /// compter celle ci ferait dependre le total du nombre de sous dossiers, et
    /// deux appareils annonceraient des poids differents pour le meme contenu.
    private static func taille(de url: URL) -> Int {
        guard let valeurs = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
              valeurs.isRegularFile == true
        else {
            return 0
        }

        return valeurs.fileSize ?? 0
    }
}
