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
    ) throws -> any SourceProvider {
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

        return try provider(
            type: type,
            source: source,
            configuration: configuration,
            trousseau: trousseau
        )
    }

    private static func provider(
        type: TypeDeSource,
        source: SourceID,
        configuration: ConfigurationDeSource,
        trousseau: TrousseauDuSysteme
    ) throws -> any SourceProvider {
        switch type {
        case .komga:
            try SourceKomga(
                id: source,
                nom: type.rawValue,
                configuration: configuration,
                magasin: trousseau
            )

        case .kavita:
            try SourceKavita(
                id: source,
                nom: type.rawValue,
                configuration: configuration,
                magasin: trousseau
            )

        case .jellyfin:
            try SourceJellyfin(
                id: source,
                nom: type.rawValue,
                configuration: configuration,
                magasin: trousseau
            )

        case .opds:
            try SourceOpds(
                id: source,
                nom: type.rawValue,
                configuration: configuration,
                magasin: trousseau
            )

        default:
            // Les partages reseau et les extensions demandent une saisie que
            // cette feuille ne pose pas : un chemin d export pour NFS, un nom
            // de partage pour SMB, une enveloppe signee pour une extension.
            throw Erreur.typeNonPrisEnCharge(type)
        }
    }
}
