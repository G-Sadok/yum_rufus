import Core
import DesignSystem
import Foundation
import Storage

//
// SessionDeParcourir
//
// Porte l ecran Parcourir : la liste des sources installees, et ce que le menu
// d ajout declenche.
//
// Le menu propose les douze entrees, mais toutes ne menent pas encore a une
// feuille de configuration. Celles qui n en ont pas ne font rien plutot que
// d ouvrir une feuille vide : la source ne serait pas ajoutee, et l utilisateur
// croirait avoir echoue alors que rien ne lui a ete demande.
//
// Le dossier local fait exception : il n a pas de feuille a remplir, un
// selecteur de dossier suffit, et c est la source qu un lecteur installe en
// premier.
//

@MainActor
@Observable
final class SessionDeParcourir {
    private(set) var etat: EtatDeParcourir = .chargement

    /// Vrai quand le selecteur de dossier est demande.
    var choisitUnDossier = false

    private let magasin: MagasinDeSources?

    init(magasin: MagasinDeSources?) {
        self.magasin = magasin
    }

    func recharger() {
        guard let magasin else {
            etat = .erreur(erreurDeLecture())

            return
        }

        do {
            etat = .chargee(
                try magasin.sources().map {
                    SourceAffichee(id: $0.id, nom: $0.nom, type: $0.type)
                }
            )
        } catch {
            etat = .erreur(erreurDeLecture())

            NSLog("Parcourir : %@", String(describing: error))
        }
    }

    var commandes: CommandesDeParcourir {
        CommandesDeParcourir(
            ajouter: { [weak self] type in
                guard type == .fichiersLocaux else { return }

                self?.choisitUnDossier = true
            },
            ouvrir: { _ in
                // Le catalogue d une source est l ecran de la section 5.3 qui
                // n existe pas encore.
            },
            supprimer: { [weak self] identifiant in
                self?.agir { _ = try $0.supprimer(identifiant) }
            }
        )
    }

    /// Enregistre le dossier choisi comme source locale.
    func ajouterLeDossier(_ url: URL) {
        agir { magasin in
            try magasin.enregistrer(
                Source(
                    id: UUID(),
                    type: .fichiersLocaux,
                    nom: url.lastPathComponent
                )
            )
        }
    }

    private func erreurDeLecture() -> EtatDeContenu {
        .erreur(
            titre: Chaines.Erreur.reglagesTitre,
            phrase: Chaines.Erreur.reglagesPhrase,
            reessayer: ActionDEtat(libelle: Chaines.Erreur.reessayer) { [weak self] in
                self?.recharger()
            },
            repli: nil
        )
    }

    private func agir(_ operation: (MagasinDeSources) throws -> Void) {
        guard let magasin else { return }

        do {
            try operation(magasin)
            recharger()
        } catch {
            NSLog("Parcourir : %@", String(describing: error))
        }
    }
}
