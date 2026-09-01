import Core
import Foundation
import Sources
import Storage

//
// RegistreDesSourcesVivantes
//
// Reconstruit les sources installees a partir de ce que la base garde.
//
// C est le maillon qui manquait pour que les sources servent apres le
// lancement qui les a ajoutees. La base garde leur ligne et leur
// configuration, le trousseau garde leurs identifiants, et rien ne
// rassemblait les deux : une source configuree hier etait une ligne morte
// aujourd hui.
//
// Les sources sont reconstruites une fois et gardees. Les rebatir a chaque
// requete relirait le trousseau a chaque frappe de recherche, ce que le
// systeme fait payer.
//

@MainActor
@Observable
final class RegistreDesSourcesVivantes {
    /// Sources pretes a repondre, par identifiant.
    private(set) var sources: [UUID: any SourceProvider] = [:]

    private let magasin: MagasinDeSources?

    init(magasin: MagasinDeSources?) {
        self.magasin = magasin
    }

    /// Reconstruit toutes les sources que la base connait.
    ///
    /// Une source qui ne se reconstruit pas est passee, pas signalee : son
    /// serveur peut etre injoignable ou son signet revoque, et ce n est pas au
    /// lancement de trancher. L ecran qui l interrogera le dira mieux.
    func reconstruire() {
        guard let magasin, let lignes = try? magasin.sources() else {
            sources = [:]

            return
        }

        var vivantes: [UUID: any SourceProvider] = [:]

        for ligne in lignes {
            if let source = try? construire(ligne) {
                vivantes[ligne.id] = source
            }
        }

        sources = vivantes
    }

    /// Source prete pour cet identifiant, nulle quand rien ne l a reconstruite.
    func source(_ identifiant: UUID) -> (any SourceProvider)? {
        sources[identifiant]
    }

    private func construire(_ ligne: Source) throws -> any SourceProvider {
        let identifiant = SourceID(ligne.id)

        if ligne.type == .fichiersLocaux {
            return SourceFichiersLocaux.depuisLeSignet(
                id: identifiant,
                nom: ligne.nom,
                magasin: try MagasinDeSignetsFichier.parDefaut(nomApplication: Self.nomDuDossier)
            )
        }

        guard let donnees = ligne.configurationChiffree else {
            throw ErreurDeConfigurationDeSource.illisible
        }

        return try FabriqueDeSource.reconstruire(
            type: ligne.type,
            nom: ligne.nom,
            configuration: try ConfigurationDeSource(donnees: donnees),
            identifiant: identifiant
        )
    }

    private static let nomDuDossier = Bundle.main.bundleIdentifier ?? "Yum"
}
