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

    /// Type dont la feuille de configuration est ouverte, nul sans feuille.
    var typeEnConfiguration: TypeDeSource?

    /// Ou en est le test de connexion de la feuille ouverte.
    private(set) var etatDeConfiguration: EtatDeConfiguration = .saisie

    private let magasin: MagasinDeSources?
    private let import_: MagasinDImportDeSource?

    /// Sources reconstruites, celles qu on peut reinterroger.
    private let sources: RegistreDesSourcesVivantes

    /// Relit la bibliotheque quand l import y a ajoute des series.
    private let apresImport: @MainActor () -> Void

    /// Previent que la liste des sources a change.
    ///
    /// Une source ajoutee doit devenir interrogeable sans relancer
    /// l application, et une source supprimee doit cesser de repondre. Le
    /// registre des sources vivantes se rebatit donc a chaque ajout et a
    /// chaque suppression, pas seulement au lancement.
    private let sourcesOntChange: @MainActor () -> Void

    init(
        magasin: MagasinDeSources?,
        importateur: MagasinDImportDeSource?,
        sources: RegistreDesSourcesVivantes,
        apresImport: @escaping @MainActor () -> Void = {},
        sourcesOntChange: @escaping @MainActor () -> Void = {}
    ) {
        self.magasin = magasin
        import_ = importateur
        self.sources = sources
        self.apresImport = apresImport
        self.sourcesOntChange = sourcesOntChange
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
                if type == .fichiersLocaux {
                    self?.choisitUnDossier = true
                } else {
                    self?.etatDeConfiguration = .saisie
                    self?.typeEnConfiguration = type
                }
            },
            ouvrir: { [weak self] identifiant in
                self?.actualiser(identifiant)
            },
            supprimer: { [weak self] identifiant in
                self?.agir { _ = try $0.supprimer(identifiant) }
                self?.sourcesOntChange()
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
            sourcesOntChange()
        } catch {
            NSLog("Parcourir : %@", String(describing: error))

            return
        }

        analyseEnCours = true

        Task { [weak self] in
            await self?.analyser(url, source: identifiant, import_: import_)
        }
    }

    // MARK: Actualisation d une source installee

    /// Relit une source deja installee et range ce qu elle rend.
    ///
    /// C est ce que fait le clic sur une ligne. Ouvrir le catalogue d une
    /// source dans un ecran a part demanderait de choisir quoi importer, alors
    /// qu une source installee est deja un choix : ce qu elle contient a sa
    /// place en bibliotheque, et l y mettre est la seule chose que
    /// l utilisateur puisse vouloir en la designant.
    ///
    /// L import etant idempotent, actualiser une source deja lue met a jour
    /// ses series sans les dupliquer et sans toucher a la progression.
    func actualiser(_ identifiant: UUID) {
        guard let import_, let source = sources.source(identifiant) else { return }

        analyseEnCours = true

        Task { [weak self] in
            await self?.recolter(source, dans: identifiant, import_: import_)
        }
    }

    /// Parcourt le catalogue d une source, page par page, et range ce qu il rend.
    ///
    /// Le nombre de pages est borne. Une source qui annoncerait toujours une
    /// page suivante ferait tourner cette boucle sans fin, et l utilisateur
    /// n aurait aucun moyen de l arreter.
    private func recolter(
        _ source: any SourceProvider,
        dans identifiant: UUID,
        import_: MagasinDImportDeSource
    ) async {
        defer { analyseEnCours = false }

        var page = 0

        do {
            // Une source de fichiers garde son analyse en cache. Sans cette
            // relance, actualiser un dossier rendrait ce qu il contenait a la
            // premiere lecture, et un chapitre ajoute depuis resterait
            // invisible tant que l application ne serait pas relancee.
            if let locale = source as? SourceFichiersLocaux {
                try await locale.reanalyser()
            }

            while page < Self.pagesMaximalesParActualisation {
                let catalogue = try await source.parcourir(.tout, page: page)

                for serie in catalogue.elements {
                    let chapitres = try await source.chapitres(pour: serie.identifiant)

                    try import_.importer(serie, chapitres: chapitres, de: identifiant)
                }

                guard catalogue.ilResteDesPages else { break }

                page += 1
            }

            if page == Self.pagesMaximalesParActualisation {
                NSLog("Parcourir : catalogue tronque a %ld pages", page)
            }

            apresImport()
        } catch {
            NSLog("Actualisation de la source : %@", String(describing: error))
        }
    }

    /// Nombre de pages de catalogue lues au plus par actualisation.
    private static let pagesMaximalesParActualisation = 50

    /// Parcourt le dossier et range ce qu il contient.
    private func analyser(
        _ url: URL,
        source identifiant: UUID,
        import_: MagasinDImportDeSource
    ) async {
        defer { analyseEnCours = false }

        do {
            let signets = try MagasinDeSignetsFichier.parDefaut(nomApplication: Self.nomDuDossier)

            // L identifiant de la base voyage jusqu au signet. Sans lui la
            // source s en fabrique un au hasard, le signet se range sous cet
            // identifiant la, et au lancement suivant la reconstruction cherche
            // sous celui de la base et ne trouve rien : la source devient une
            // ligne morte, sans couverture et sans chapitre ouvrable.
            let source = try SourceFichiersLocaux.enregistrant(
                dossier: url,
                id: SourceID(identifiant),
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

    // MARK: Sources a serveur

    /// Teste la connexion avant d autoriser l enregistrement.
    ///
    /// Le test porte sur la source reelle, pas sur la seule forme de l adresse.
    /// Une adresse bien formee vers un serveur qui ne repond pas serait
    /// enregistree sans lui, et la source resterait vide sans dire pourquoi.
    func tester(adresse: String, compte: String, motDePasse: String) {
        guard let type = typeEnConfiguration else { return }

        etatDeConfiguration = .test

        Task { [weak self] in
            await self?.essayer(type: type, adresse: adresse, compte: compte, motDePasse: motDePasse)
        }
    }

    private func essayer(
        type: TypeDeSource,
        adresse: String,
        compte: String,
        motDePasse: String
    ) async {
        do {
            // Le test construit une source jetable. Ses identifiants vont dans
            // un magasin en memoire : les ecrire dans le trousseau y laisserait
            // une ligne par essai, sous un identifiant que plus rien ne
            // designe et que rien ne viendrait nettoyer.
            let construite = try await FabriqueDeSource.construire(
                type: type,
                adresse: adresse,
                compte: compte,
                motDePasse: motDePasse,
                identifiant: UUID(),
                trousseau: MagasinDIdentifiantsEnMemoire()
            )

            let etat = await construite.source.verifierConnexion()

            etatDeConfiguration = etat == .connecte
                ? .reussi
                : .echec(Chaines.Erreur.reglagesPhrase)
        } catch {
            etatDeConfiguration = .echec(
                (error as? LocalizedError)?.errorDescription ?? Chaines.Erreur.reglagesPhrase
            )
        }
    }

    /// Enregistre la source dont le test vient de reussir.
    func enregistrerLaSource(adresse: String, compte: String, motDePasse: String) {
        guard let type = typeEnConfiguration, magasin != nil else { return }

        Task { [weak self] in
            await self?.ranger(type: type, adresse: adresse, compte: compte, motDePasse: motDePasse)
        }
    }

    /// Construit la source une seconde fois et la range.
    ///
    /// Une seconde fois parce que le test a construit la sienne sous un
    /// identifiant jetable : c est celle ci qui vivra, et son identifiant est
    /// celui sous lequel le trousseau range ses secrets.
    private func ranger(
        type: TypeDeSource,
        adresse: String,
        compte: String,
        motDePasse: String
    ) async {
        guard let magasin else { return }

        let identifiant = UUID()

        do {
            let construite = try await FabriqueDeSource.construire(
                type: type,
                adresse: adresse,
                compte: compte,
                motDePasse: motDePasse,
                identifiant: identifiant
            )

            try magasin.enregistrer(
                Source(
                    id: identifiant,
                    type: type,
                    nom: type.rawValue,
                    configurationChiffree: try construite.configuration.donnees()
                )
            )

            typeEnConfiguration = nil
            recharger()
            sourcesOntChange()
        } catch {
            etatDeConfiguration = .echec(
                (error as? LocalizedError)?.errorDescription ?? Chaines.Erreur.reglagesPhrase
            )
        }
    }

    func fermerLaConfiguration() {
        typeEnConfiguration = nil
        etatDeConfiguration = .saisie
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
