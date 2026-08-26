import Core
import Foundation

//
// ReceptionDeDepot
//
// Ou vont les fichiers recus par le transfert Wi-Fi.
//
// La section 4.4 le dit en une phrase : dans la source Fichiers locaux. C est
// un protocole et non un appel direct a la source pour deux raisons. La
// premiere est que le serveur n a pas a savoir ce qu est un signet de securite
// ni une analyse de dossier ; il recoit des octets et un nom. La seconde est
// qu un test doit pouvoir prouver qu un depot refuse n ecrit rien, ce qui se
// verifie sur un double bien plus surement que sur un disque.
//
// L implementation reelle, `ReceptionDansFichiersLocaux`, pose trois refus
// avant d ecrire, et chacun repare une facon connue de sortir du dossier.
//
// Le premier est le nom compose. Un navigateur peut annoncer
// `../../Bibliotheque/mot de passe.txt`, et un serveur qui colle ce nom a la
// racine ecrit hors du dossier de la source. Seul le dernier composant est
// retenu, sur les deux separateurs, et le resultat est verifie une seconde fois
// contre la racine avant l ecriture.
//
// Le deuxieme est le nom cache. Un fichier qui commence par un point est retire
// par l analyse du dossier, il n apparaitrait donc jamais dans la
// bibliotheque : l accepter reviendrait a annoncer un depot reussi qui ne
// produit rien de visible.
//
// Le troisieme est le format. Seuls les conteneurs connus de l analyse et les
// images le sont ; le reste est refuse en nommant le format. Accepter un
// binaire ou un document quelconque remplirait la bibliotheque de fichiers que
// rien ne sait ouvrir.
//

/// Ce qui accueille les fichiers recus par la reception Wi-Fi.
public protocol ReceptionDeDepot: Sendable {
    /// Ecrit un fichier recu et rend le nom sous lequel il a ete range.
    ///
    /// - Throws: `ErreurDeTransfert.nomDeFichierRefuse`,
    ///   `ErreurDeTransfert.formatNonRecevable` ou
    ///   `ErreurDeTransfert.ecritureImpossible`.
    func recevoir(nomPropose: String, octets: Data) async throws -> String

    /// Prend acte de la fin de la reception.
    ///
    /// C est ici que la source relit son dossier, une fois, quel que soit le
    /// nombre de fichiers deposes. Relire apres chaque fichier couterait une
    /// analyse complete de la bibliotheque par depot, sur une bibliotheque qui
    /// peut compter 5000 series.
    func conclure() async
}

/// Reception qui pose les fichiers dans le dossier d une source Fichiers
/// locaux.
public actor ReceptionDansFichiersLocaux: ReceptionDeDepot {
    /// Longueur maximale d un nom de fichier recu.
    ///
    /// Les systemes de fichiers d Apple s arretent a 255 octets par composant.
    /// La marge laisse la place au suffixe de doublon.
    public static let longueurMaximaleDuNom = 200

    /// Extensions acceptees : les conteneurs connus de l analyse et les images.
    public static var extensionsRecevables: Set<String> {
        FormatsDeConteneur.connus.union(FormatDImage.toutesLesExtensions)
    }

    private let source: SourceFichiersLocaux
    private var aRecuQuelqueChose = false

    public init(source: SourceFichiersLocaux) {
        self.source = source
    }

    public func recevoir(nomPropose: String, octets: Data) async throws -> String {
        let nom = try Self.nomAcceptable(nomPropose)
        let racine = try await racineDeLaSource()
        let destination = try emplacementLibre(pour: nom, dans: racine)

        guard destination.deletingLastPathComponent().standardizedFileURL.path
            == racine.standardizedFileURL.path
        else {
            throw ErreurDeTransfert.nomDeFichierRefuse
        }

        do {
            try octets.write(to: destination, options: .atomic)
        } catch {
            throw ErreurDeTransfert.ecritureImpossible
        }

        aRecuQuelqueChose = true

        return destination.lastPathComponent
    }

    public func conclure() async {
        guard aRecuQuelqueChose else {
            return
        }

        aRecuQuelqueChose = false

        // L echec d une relecture n a pas a faire echouer la fin de la
        // reception : les fichiers sont ecrits, et la prochaine ouverture de la
        // source les trouvera.
        _ = try? await source.reanalyser()
    }

    // MARK: Nom

    /// Ramene un nom propose a un nom de fichier posable, ou refuse.
    ///
    /// - Throws: `ErreurDeTransfert.nomDeFichierRefuse` quand rien d utilisable
    ///   ne reste, et `ErreurDeTransfert.formatNonRecevable` quand l extension
    ///   n est pas celle d un chapitre.
    static func nomAcceptable(_ propose: String) throws -> String {
        let dernier = propose
            .split(whereSeparator: { $0 == "/" || $0 == "\\" })
            .last
            .map(String.init) ?? ""
        let nom = dernier.trimmingCharacters(in: .whitespacesAndNewlines)

        guard nom.isEmpty == false,
              nom.hasPrefix(".") == false,
              nom.count <= longueurMaximaleDuNom,
              nom.unicodeScalars.allSatisfy({ $0.value >= 0x20 && $0.value != 0x7F }),
              nom.contains(":") == false
        else {
            throw ErreurDeTransfert.nomDeFichierRefuse
        }

        let format = (nom as NSString).pathExtension.lowercased()

        guard format.isEmpty == false else {
            throw ErreurDeTransfert.nomDeFichierRefuse
        }
        guard extensionsRecevables.contains(format) else {
            throw ErreurDeTransfert.formatNonRecevable(format: format)
        }

        return nom
    }

    /// Rend le dossier de la source, resolu si besoin.
    private func racineDeLaSource() async throws -> URL {
        do {
            return try await source.racine()
        } catch {
            throw ErreurDeTransfert.ecritureImpossible
        }
    }

    /// Un emplacement qui n ecrase rien.
    ///
    /// Un depot ne remplace jamais un chapitre deja range. Deux appareils qui
    /// envoient le meme `Chapitre 1.cbz` produisent deux fichiers, et
    /// l utilisateur tranche ensuite, plutot qu une version perdue en silence.
    private func emplacementLibre(pour nom: String, dans racine: URL) throws -> URL {
        let gestionnaire = FileManager.default
        let base = (nom as NSString).deletingPathExtension
        let format = (nom as NSString).pathExtension
        var candidat = racine.appending(path: nom)
        var rang = 2

        while gestionnaire.fileExists(atPath: candidat.path) {
            guard rang < 1000 else {
                throw ErreurDeTransfert.nomDeFichierRefuse
            }

            candidat = racine.appending(path: "\(base) (\(rang)).\(format)")
            rang += 1
        }

        return candidat
    }
}
