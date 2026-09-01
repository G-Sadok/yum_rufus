import Core
import DesignSystem
import Foundation
import Sources
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

    /// Vrai pendant l analyse d un dossier, qui peut prendre du temps.
    private(set) var analyseEnCours = false

    private let magasin: MagasinDeSources?
    private let import_: MagasinDImportDeSource?

    /// Relit la bibliotheque quand l import y a ajoute des series.
    private let apresImport: @MainActor () -> Void

    init(
        magasin: MagasinDeSources?,
        importateur: MagasinDImportDeSource?,
        apresImport: @escaping @MainActor () -> Void = {}
    ) {
        self.magasin = magasin
        import_ = importateur
        self.apresImport = apresImport
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

    /// Enregistre le dossier choisi, puis range son contenu en bibliotheque.
    ///
    /// L analyse est ce qui distingue une source ajoutee d une source qui sert
    /// a quelque chose. Sans elle, la source apparait dans la liste et la
    /// bibliotheque reste vide, ce qui est le plus decourageant des resultats.
    func ajouterLeDossier(_ url: URL) {
        guard let magasin, let import_ else { return }

        let identifiant = UUID()

        do {
            try magasin.enregistrer(
                Source(id: identifiant, type: .fichiersLocaux, nom: url.lastPathComponent)
            )

            recharger()
        } catch {
            NSLog("Parcourir : %@", String(describing: error))

            return
        }

        analyseEnCours = true

        Task { [weak self] in
            await self?.analyser(url, source: identifiant, import_: import_)
        }
    }

    /// Parcourt le dossier et range ce qu il contient.
    private func analyser(
        _ url: URL,
        source identifiant: UUID,
        import_: MagasinDImportDeSource
    ) async {
        defer { analyseEnCours = false }

        do {
            let signets = try MagasinDeSignetsFichier.parDefaut(nomApplication: Self.nomDuDossier)
            let source = try SourceFichiersLocaux.enregistrant(
                dossier: url,
                nom: url.lastPathComponent,
                magasin: signets
            )

            let catalogue = try await source.parcourir(.tout, page: 0)

            for serie in catalogue.elements {
                let chapitres = try await source.chapitres(pour: serie.identifiant)

                try import_.importer(serie, chapitres: chapitres, de: identifiant)
            }

            apresImport()
        } catch {
            NSLog("Analyse du dossier : %@", String(describing: error))
        }
    }

    /// Nom du dossier de support, celui ou vivent la base et les signets.
    private static let nomDuDossier = Bundle.main.bundleIdentifier ?? "Yum"

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
