import Core
import Foundation
@testable import Sources

//
// PartageSimule
//
// Le partage reseau des tests. Il ne parle a rien, il sert les octets qu on lui
// a decrits, et il compte ce qu il a reellement transmis.
//
// Les trois moities comptent autant l une que l autre.
//
// Servir une arborescence couvre l analyse a deux niveaux, la meme que pour un
// dossier local, sans avoir a monter un serveur SMB dans une suite de tests.
//
// Compter les octets transmis est ce qui prouve le premier critere. Verifier
// qu une page s ouvre ne prouve rien : une source qui rapatrierait le conteneur
// entier passerait ce test. Ce qui prouve la lecture en flux, c est le nombre
// d octets que le partage a reellement rendus, et lui seul le connait.
//
// Couper la connexion a un point choisi est ce qui prouve le deuxieme. Une
// coupure simulee par une erreur levee avant tout echange ne dirait rien de la
// reprise : ce qu il faut, c est que la coupure arrive apres que des octets sont
// deja passes, et que le compteur montre ensuite que ceux la n ont pas ete
// redemandes.
//

/// Ce qu une lecture demandait, sous une forme qui se compare.
struct LectureObservee: Sendable, Hashable {
    let chemin: String
    let offset: UInt64
    let longueur: Int
}

/// Contenu d un fichier du partage simule.
enum ContenuSimule: Sendable {
    /// Des octets tenus en memoire, pour les petits fichiers.
    case memoire(Data)

    /// Un CBZ dont les octets se calculent, pour les gros conteneurs.
    case archive(ArchiveSynthetique)

    var taille: UInt64 {
        switch self {
        case let .memoire(octets): UInt64(octets.count)
        case let .archive(archive): archive.taille
        }
    }

    func octets(a offset: UInt64, longueur: Int) -> Data {
        switch self {
        case let .memoire(octets):
            let debut = min(Int(offset), octets.count)
            let fin = min(debut + longueur, octets.count)

            return octets.subdata(in: (octets.startIndex + debut)..<(octets.startIndex + fin))
        case let .archive(archive):
            return archive.octets(a: offset, longueur: longueur)
        }
    }
}

/// Partage reseau qui sert des octets decrits, sans ouvrir de connexion.
actor PartageSimule: PartageReseau {
    /// Nombre maximal d octets rendus par lecture.
    ///
    /// Un vrai partage borne toujours sa reponse : SMB a la taille de lecture
    /// negociee, NFS a celle du montage, WebDAV a ce que le proxy laisse passer.
    /// Le double le fait aussi, sans quoi les tests ne verifieraient jamais que
    /// le tampon sait reclamer la suite d une reponse trop courte.
    static let plafondParDefaut = 512 * 1024

    nonisolated let libelle: String

    private var entrees: [String: EntreeDePartage] = [:]
    private var fichiers: [String: ContenuSimule] = [:]
    private let plafondParLecture: Int

    /// Nombre d octets reellement rendus depuis la construction.
    private(set) var octetsServis: UInt64 = 0

    /// Les lectures recues, dans l ordre.
    private(set) var lectures: [LectureObservee] = []

    /// Les listages recus, dans l ordre.
    private(set) var listages: [String] = []

    /// Seuil au dela duquel toute lecture echoue, ou nul quand la connexion tient.
    private var coupureApres: UInt64?

    /// Panne levee une fois le seuil franchi.
    private var panne: ErreurReseau = .horsLigne

    init(libelle: String = "Partage de test", plafondParLecture: Int = PartageSimule.plafondParDefaut) {
        self.libelle = libelle
        self.plafondParLecture = max(1, plafondParLecture)
    }

    // MARK: Description de l arborescence

    /// Ajoute un dossier, et tous ceux qui le portent.
    func ajouter(dossier chemin: String, dateModification: Date? = nil) {
        guard chemin.isEmpty == false, entrees[chemin] == nil else {
            return
        }

        let parent = Self.parent(de: chemin)
        if parent.isEmpty == false {
            ajouter(dossier: parent)
        }

        entrees[chemin] = EntreeDePartage(chemin: chemin, estDossier: true, dateModification: dateModification)
    }

    /// Ajoute un fichier, et les dossiers qui le portent.
    func ajouter(fichier chemin: String, contenu: ContenuSimule, dateModification: Date? = nil) {
        let parent = Self.parent(de: chemin)
        if parent.isEmpty == false {
            ajouter(dossier: parent)
        }

        entrees[chemin] = EntreeDePartage(
            chemin: chemin,
            estDossier: false,
            taille: contenu.taille,
            dateModification: dateModification
        )
        fichiers[chemin] = contenu
    }

    /// Ajoute un fichier dont le contenu tient en memoire.
    func ajouter(fichier chemin: String, octets: Data, dateModification: Date? = nil) {
        ajouter(fichier: chemin, contenu: .memoire(octets), dateModification: dateModification)
    }

    // MARK: Pilotage des pannes

    /// Fait echouer toute lecture une fois ce nombre d octets transmis.
    func couper(apres octets: UInt64, panne: ErreurReseau = .horsLigne) {
        coupureApres = octets
        self.panne = panne
    }

    /// Retablit la connexion.
    func retablir() {
        coupureApres = nil
    }

    /// Remet a zero le compteur d octets et le journal des lectures.
    func remettreLesCompteurs() {
        octetsServis = 0
        lectures.removeAll()
        listages.removeAll()
    }

    // MARK: Protocole

    func lister(_ chemin: String) async throws -> [EntreeDePartage] {
        listages.append(chemin)

        if chemin.isEmpty == false, entrees[chemin]?.estDossier != true {
            throw ErreurReseau.ressourceIntrouvable
        }

        return entrees.values
            .filter { Self.parent(de: $0.chemin) == chemin }
            .sorted { $0.chemin < $1.chemin }
    }

    func attributs(de chemin: String) async throws -> EntreeDePartage {
        guard let entree = entrees[chemin] else {
            throw ErreurReseau.ressourceIntrouvable
        }

        return entree
    }

    func lire(_ chemin: String, a offset: UInt64, longueur: Int) async throws -> Data {
        lectures.append(LectureObservee(chemin: chemin, offset: offset, longueur: longueur))

        guard let contenu = fichiers[chemin] else {
            throw ErreurReseau.ressourceIntrouvable
        }
        if let coupureApres, octetsServis >= coupureApres {
            throw panne
        }

        let rendus = contenu.octets(a: offset, longueur: min(longueur, plafondParLecture))
        octetsServis += UInt64(rendus.count)

        return rendus
    }

    // MARK: Chemins

    /// Le dossier qui porte ce chemin, chaine vide pour la racine.
    private static func parent(de chemin: String) -> String {
        guard let separateur = chemin.lastIndex(of: "/") else {
            return ""
        }

        return String(chemin[chemin.startIndex..<separateur])
    }
}
