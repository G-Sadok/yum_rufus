import Core
import Foundation
@testable import Sources

//
// DepotICloudSimule
//
// Le dossier iCloud Drive des tests, avec ses fichiers non telecharges.
//
// Deux exigences ont dicte sa forme.
//
// La progression avance au rythme des sondages et jamais de l horloge. Un test
// qui attendrait un delai reel serait long quand la machine est libre et faux
// quand elle est chargee, alors que la progression est justement ce que le
// premier critere demande de mesurer. Chaque sondage rend donc un pas d octets,
// et le nombre de sondages decide de la duree, pas la montre.
//
// Les fichiers existent vraiment sur le disque. Un fichier non telecharge y est
// pose sous son nom de substitut, et la fin du telechargement le remplace par le
// vrai fichier, exactement comme le fait le systeme. C est ce qui permet a la
// source d ouvrir le conteneur apres coup, donc de prouver que le
// telechargement a servi a quelque chose plutot que de simplement compter des
// appels.
//

/// Depot iCloud de test, qui rend ses fichiers un sondage a la fois.
actor DepotICloudSimule: DepotICloud {
    /// Ce que le depot sait d un fichier qu il suit.
    private struct Fichier {
        let contenu: Data
        var octetsPresents: Int64
        var demande = false

        var octetsAttendus: Int64 {
            Int64(contenu.count)
        }

        var estLocal: Bool {
            octetsPresents >= octetsAttendus
        }
    }

    /// Racine du dossier servi, sur le disque.
    let racine: URL

    /// Octets rendus par sondage. Zero simule un telechargement qui n avance
    /// jamais, ce dont le delai depasse a besoin.
    private let pas: Int64

    private var fichiers: [String: Fichier] = [:]
    private var demandes: [String: Int] = [:]

    init(racine: URL, pas: Int64 = 4096) {
        self.racine = racine
        self.pas = pas
    }

    // MARK: Preparation

    /// Pose un fichier deja present en entier sur l appareil.
    func poserLocal(_ chemin: String, contenu: Data) throws {
        let url = racine.appending(path: chemin)

        try creerLeParent(de: url)
        try contenu.write(to: url)

        fichiers[chemin] = Fichier(contenu: contenu, octetsPresents: Int64(contenu.count))
    }

    /// Pose un fichier qui n est pas encore telecharge, sous son substitut.
    func poserAbsent(_ chemin: String, contenu: Data) throws {
        let url = racine.appending(path: chemin)

        try creerLeParent(de: url)
        try Data().write(to: substitut(de: url))

        fichiers[chemin] = Fichier(contenu: contenu, octetsPresents: 0)
    }

    /// Nombre de demandes de telechargement recues pour ce chemin.
    func nombreDeDemandes(pour chemin: String) -> Int {
        demandes[chemin] ?? 0
    }

    /// Nombre total de demandes recues, tous fichiers confondus.
    var nombreTotalDeDemandes: Int {
        demandes.values.reduce(0, +)
    }

    // MARK: Protocole

    func etat(de fichier: URL) throws -> EtatDeFichierICloud {
        let cle = chemin(de: fichier)

        guard var connu = fichiers[cle] else {
            // Un fichier dont le depot ne sait rien est un fichier ordinaire,
            // donc present en entier. C est le cas du dossier de la source et
            // de tout ce que le test n a pas declare non telecharge.
            let octets = Int64((try? fichier.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)

            return EtatDeFichierICloud(presence: .local, octetsPresents: octets, octetsAttendus: octets)
        }

        guard connu.estLocal == false else {
            return EtatDeFichierICloud(
                presence: .local,
                octetsPresents: connu.octetsAttendus,
                octetsAttendus: connu.octetsAttendus
            )
        }
        guard connu.demande else {
            return EtatDeFichierICloud(presence: .absent, octetsPresents: 0, octetsAttendus: connu.octetsAttendus)
        }

        connu.octetsPresents = min(connu.octetsPresents + pas, connu.octetsAttendus)
        fichiers[cle] = connu

        guard connu.estLocal else {
            return EtatDeFichierICloud(
                presence: .enCours,
                octetsPresents: connu.octetsPresents,
                octetsAttendus: connu.octetsAttendus
            )
        }

        try materialiser(cle, contenu: connu.contenu)

        return EtatDeFichierICloud(
            presence: .local,
            octetsPresents: connu.octetsAttendus,
            octetsAttendus: connu.octetsAttendus
        )
    }

    func demanderLeTelechargement(de fichier: URL) throws {
        let cle = chemin(de: fichier)

        demandes[cle, default: 0] += 1
        fichiers[cle]?.demande = true
    }

    // MARK: Disque

    /// Remplace le substitut par le vrai fichier, comme le fait le systeme a la
    /// fin d un telechargement.
    private func materialiser(_ chemin: String, contenu: Data) throws {
        let url = racine.appending(path: chemin)
        let gestionnaire = FileManager.default

        try contenu.write(to: url)
        try? gestionnaire.removeItem(at: substitut(de: url))
    }

    private func creerLeParent(de url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }

    private nonisolated func substitut(de url: URL) -> URL {
        url.deletingLastPathComponent()
            .appending(path: EmplacementICloud.nomDeSubstitut(de: url.lastPathComponent))
    }

    /// Chemin relatif a la racine, sous le nom visible par l utilisateur.
    ///
    /// Le depot est interroge tantot sur le substitut, tantot sur le vrai nom,
    /// selon l avancement du telechargement. Les deux designent le meme fichier
    /// et doivent donc tomber sur la meme cle.
    private nonisolated func chemin(de fichier: URL) -> String {
        let visible = EmplacementICloud.cheminNormalise(EmplacementICloud.visible(fichier))
        let base = racine.standardizedFileURL.path
        let prefixe = base.hasSuffix("/") ? base : base + "/"

        guard visible.hasPrefix(prefixe) else { return visible }

        return String(visible.dropFirst(prefixe.count))
    }
}
