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

    /// Le registre de Core, qui sait poser la meme question a toutes les
    /// sources en isolant chacune et en bornant son delai.
    ///
    /// Il vient des services et n est pas construit ici : la recherche, la
    /// veille et la verification de connexion posent la meme question au meme
    /// jeu de sources, et deux registres finiraient par ne plus contenir les
    /// memes. Il etait construit au lancement et personne ne l alimentait.
    let registre: RegistreDeSources

    private let magasin: MagasinDeSources?

    init(magasin: MagasinDeSources?, registre: RegistreDeSources) {
        self.magasin = magasin
        self.registre = registre
    }

    /// Reconstruit toutes les sources que la base connait.
    ///
    /// Une source qui ne se reconstruit pas est passee, pas signalee : son
    /// serveur peut etre injoignable ou son signet revoque, et ce n est pas au
    /// lancement de trancher. L ecran qui l interrogera le dira mieux.
    func reconstruire() async {
        guard let magasin, let lignes = try? magasin.sources() else {
            sources = [:]
            await registre.remplacerPar([])

            return
        }

        var vivantes: [UUID: any SourceProvider] = [:]

        for ligne in lignes {
            if let source = try? await construire(ligne) {
                vivantes[ligne.id] = source
            }
        }

        sources = vivantes

        await registre.remplacerPar(Array(vivantes.values))
    }

    /// Source prete pour cet identifiant, nulle quand rien ne l a reconstruite.
    func source(_ identifiant: UUID) -> (any SourceProvider)? {
        sources[identifiant]
    }

    /// Fichier d un chapitre sur le disque, quand il y en a un.
    ///
    /// Ne repond que pour les sources de fichiers locaux, ou l identifiant
    /// distant d un chapitre est son chemin sous la racine de la source. Un
    /// chapitre servi par un serveur n a pas de fichier a ouvrir : il se lit
    /// page par page par le reseau, ce que le lecteur ne sait pas encore faire.
    func fichier(de adresse: AdresseDeChapitre) async -> URL? {
        guard let locale = sources[adresse.source] as? SourceFichiersLocaux,
              let racine = try? await locale.racine()
        else {
            return nil
        }

        return racine.appending(path: adresse.chapitre)
    }

    private func construire(_ ligne: Source) async throws -> any SourceProvider {
        let identifiant = SourceID(ligne.id)

        if ligne.type == .fichiersLocaux {
            return try SourceFichiersLocaux.depuisLeSignet(
                id: identifiant,
                nom: ligne.nom,
                magasin: MagasinDeSignetsFichier.parDefaut(nomApplication: Self.nomDuDossier)
            )
        }

        guard let donnees = ligne.configurationChiffree else {
            throw ErreurDeConfigurationDeSource.illisible
        }

        return try await FabriqueDeSource.reconstruire(
            type: ligne.type,
            nom: ligne.nom,
            configuration: ConfigurationDeSource(donnees: donnees),
            identifiant: identifiant
        )
    }

    private static let nomDuDossier = Bundle.main.bundleIdentifier ?? "Yum"
}
