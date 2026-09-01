import Core
import Foundation
import Sources

//
// FabriqueDeSource
//
// Construit une source a partir de ce que la feuille de configuration a saisi.
//
// Les identifiants ne passent jamais par la configuration : ils vont au
// trousseau, et la configuration ne garde que l adresse. Une configuration
// exportee ou sauvegardee ne porte donc aucune trace du compte de
// l utilisateur, ce que la section des contraintes juridiques impose.
//

enum FabriqueDeSource {
    /// Ce que la fabrique refuse de construire.
    enum Erreur: Error, LocalizedError {
        case adresseIllisible
        case typeNonPrisEnCharge(TypeDeSource)

        var errorDescription: String? {
            switch self {
            case .adresseIllisible: Chaines.Configuration.adresseIllisible
            case .typeNonPrisEnCharge: Chaines.Configuration.typeNonPrisEnCharge
            }
        }
    }

    /// Construit la source et range ses identifiants dans le trousseau.
    ///
    /// - Parameters:
    ///   - type: type choisi dans le menu d ajout.
    ///   - adresse: adresse saisie, telle quelle.
    ///   - compte: compte saisi, vide quand la source n en demande pas.
    ///   - motDePasse: mot de passe saisi.
    ///   - identifiant: identifiant que la source portera en base.
    static func construire(
        type: TypeDeSource,
        adresse: String,
        compte: String,
        motDePasse: String,
        identifiant: UUID
    ) async throws -> (source: any SourceProvider, configuration: ConfigurationDeSource) {
        guard let url = URL(string: adresse.trimmingCharacters(in: .whitespaces)),
              url.host() != nil
        else {
            throw Erreur.adresseIllisible
        }

        let trousseau = TrousseauDuSysteme()
        let source = SourceID(identifiant)

        if compte.isEmpty == false {
            try trousseau.enregistrer(
                .basique(compte: compte, motDePasse: motDePasse),
                pour: source
            )
        }

        let configuration = ConfigurationDeSource(
            adresse: url,
            authentification: compte.isEmpty ? .aucune : .basique
        )

        let construite = try await provider(
            type: type,
            source: source,
            configuration: configuration,
            trousseau: trousseau,
            compte: compte,
            motDePasse: motDePasse
        )

        // La configuration revient avec la source : elle doit etre persistee
        // pour que la source se reconstruise au prochain lancement. Sans elle,
        // l adresse serait perdue et la source deviendrait une ligne morte.
        return (construite, configuration)
    }

    /// Reconstruit une source depuis sa configuration persistee.
    ///
    /// Les identifiants ne sont pas relus ici : chaque source va les chercher
    /// au trousseau quand elle en a besoin, sous la cle de son identifiant.
    static func reconstruire(
        type: TypeDeSource,
        nom: String,
        configuration: ConfigurationDeSource,
        identifiant: SourceID
    ) async throws -> any SourceProvider {
        let trousseau = TrousseauDuSysteme()
        let ranges = (try? trousseau.identifiants(pour: identifiant)) ?? .aucun

        // Seul le compte simple se relit ici. Les sources a serveur vont
        // chercher elles memes ce dont elles ont besoin sous la cle de leur
        // identifiant ; les partages reseau, non, et c est pour eux que ces
        // deux chaines sont extraites.
        let compte: String
        let motDePasse: String

        if case let .basique(compte: saisi, motDePasse: secret) = ranges {
            compte = saisi
            motDePasse = secret
        } else {
            compte = ""
            motDePasse = ""
        }

        return try await provider(
            type: type,
            source: identifiant,
            configuration: configuration,
            trousseau: trousseau,
            compte: compte,
            motDePasse: motDePasse,
            nom: nom
        )
    }

    private static func provider(
        type: TypeDeSource,
        source: SourceID,
        configuration: ConfigurationDeSource,
        trousseau: TrousseauDuSysteme,
        compte: String,
        motDePasse: String,
        nom: String? = nil
    ) async throws -> any SourceProvider {
        let libelle = nom ?? type.rawValue

        // Les partages reseau ne passent pas par le trousseau de la meme
        // facon : leurs clients portent leurs identifiants dans leur propre
        // type, et ne savent pas aller les chercher eux memes.
        if Self.partagesReseau.contains(type) {
            return try await partage(
                type: type,
                source: source,
                configuration: configuration,
                libelle: libelle,
                compte: compte,
                motDePasse: motDePasse
            )
        }

        // Le retour est explicite : le switch n est plus la seule instruction
        // de la fonction, il perd donc son retour implicite.
        return switch type {
        case .komga:
            try SourceKomga(
                id: source,
                nom: libelle,
                configuration: configuration,
                magasin: trousseau
            )

        case .kavita:
            try SourceKavita(
                id: source,
                nom: libelle,
                configuration: configuration,
                magasin: trousseau
            )

        case .jellyfin:
            try SourceJellyfin(
                id: source,
                nom: libelle,
                configuration: configuration,
                magasin: trousseau
            )

        case .opds:
            try SourceOpds(
                id: source,
                nom: libelle,
                configuration: configuration,
                magasin: trousseau
            )

        default:
            // Les extensions demandent une enveloppe signee, que cette feuille
            // ne pose pas et qu une adresse ne remplace pas.
            throw Erreur.typeNonPrisEnCharge(type)
        }
    }

    // MARK: Partages reseau

    /// Construit un partage SMB, NFS ou WebDAV depuis sa seule adresse.
    ///
    /// L adresse porte tout ce qu il faut. `smb://hote/partage` nomme l hote
    /// et le partage, `nfs://hote/export` l hote et l export, une adresse
    /// WebDAV est une adresse HTTP ordinaire. Demander en plus un champ qui
    /// repete ce que l adresse dit deja serait une saisie a se tromper.
    private static func partage(
        type: TypeDeSource,
        source: SourceID,
        configuration: ConfigurationDeSource,
        libelle: String,
        compte: String,
        motDePasse: String
    ) async throws -> any SourceProvider {
        guard let url = configuration.adresse, let hote = url.host() else {
            throw Erreur.adresseIllisible
        }

        let racine = premierSegment(de: url)
        let client: any PartageReseau

        switch type {
        case .smb:
            guard racine.isEmpty == false else {
                throw Erreur.adresseIllisible
            }

            client = PartageSmb(
                libelle: libelle,
                hote: hote,
                partage: racine,
                canal: CanalTcp(hote: hote, port: Self.portSmb),
                identifiants: compte.isEmpty
                    ? .invite
                    : .compte(compte: compte, motDePasse: motDePasse)
            )

        case .nfs:
            guard racine.isEmpty == false else {
                throw Erreur.adresseIllisible
            }

            // Le port du service de montage n est pas fixe : il change a chaque
            // demarrage du serveur. Il est demande au repertoire de ports,
            // ce que `surTcp` fait pour nous.
            client = try await PartageNfs.surTcp(
                libelle: libelle,
                hote: hote,
                export: racine
            )

        default:
            client = try PartageWebDav(
                libelle: libelle,
                base: url,
                identifiants: compte.isEmpty
                    ? .aucuns
                    : .compte(compte: compte, motDePasse: motDePasse),
                accepteLeHttpEnClair: configuration.accepteLeHttpEnClair
            )
        }

        return SourcePartageReseau(id: source, nom: libelle, partage: client, adresse: url)
    }

    /// Premier segment du chemin d une adresse, sans les barres obliques.
    private static func premierSegment(de url: URL) -> String {
        url.path()
            .split(separator: "/")
            .first
            .map(String.init) ?? ""
    }

    /// Port du service SMB, fixe par le protocole.
    private static let portSmb: UInt16 = 445

    /// Les trois types servis par un partage reseau.
    private static let partagesReseau: Set<TypeDeSource> = [.smb, .nfs, .webdav]
}
