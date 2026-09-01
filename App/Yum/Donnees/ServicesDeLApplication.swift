import Core
import Foundation
import Observation
import Sources
import Storage
import Sync

//
// Ouverture de la base de donnees de l application.
//
// La base vit dans le dossier de support de l application, a cote de ce que
// l utilisateur n a pas a manipuler. Elle est ouverte une fois, au lancement,
// et migree par `BaseDeDonnees` elle meme.
//
// L echec d ouverture n est pas fatal : il devient l etat d erreur des ecrans
// qui ont besoin de la base, chacun nommant sa propre cause avec les libelles
// du tableau 6.4.
//

/// Ce que l application partage entre ses ecrans.
@MainActor
@Observable
final class ServicesDeLApplication {
    /// Base ouverte et migree, nulle quand l ouverture a echoue.
    private(set) var base: BaseDeDonnees?

    /// Nom du fichier de base, range dans le dossier de support.
    static let nomDuFichier = "bibliotheque.sqlite"

    /// Etat du mode incognito, partage avec les magasins qui ecrivent.
    ///
    /// Il est construit ici et non dans l ecran des reglages, parce que c est
    /// ici que les magasins sont construits. Un registre cree plus tard
    /// n atteindrait plus la couche qui ecrit, et le mode incognito n aurait
    /// d effet que sur la banniere.
    let incognito = RegistreDIncognito()

    /// Les sources configurees, partagees par les ecrans qui les interrogent.
    ///
    /// Il vit ici pour la meme raison que le registre d incognito : c est le
    /// seul endroit construit une fois, au lancement. Une veille qui inscrirait
    /// ses propres sources interrogerait un autre jeu que celui des ecrans.
    let sources = RegistreDeSources()

    /// Tache qui reveille la veille de nouveaux chapitres.
    private var tacheDeVeille: Task<Void, Never>?

    /// Ouvre la base et retient l echec plutot que de le laisser remonter.
    init() {
        base = try? Self.ouvrir()

        demarrerLaVeille()
    }

    /// Construit les services autour d une base deja ouverte.
    ///
    /// Employe par les apercus et par les tests, qui travaillent en memoire.
    init(base: BaseDeDonnees?) {
        self.base = base
    }

    /// Range en bibliotheque ce qu une source rend, nul sans base.
    var importateur: MagasinDImportDeSource? {
        base.map { MagasinDImportDeSource(base: $0) }
    }

    /// Magasin de fiche de serie, nul tant que la base n est pas ouverte.
    var ficheDeSerie: MagasinDeFicheDeSerie? {
        base.map { MagasinDeFicheDeSerie(base: $0) }
    }

    /// Resolution d un chapitre vers sa source, nulle sans base.
    var resolutionDeChapitre: MagasinDeResolutionDeChapitre? {
        base.map { MagasinDeResolutionDeChapitre(base: $0) }
    }

    /// Magasin du sens de lecture, nul tant que la base n est pas ouverte.
    var sensDeLecture: MagasinDeSensDeLecture? {
        base.map { MagasinDeSensDeLecture(base: $0) }
    }

    /// Magasin de categories, nul tant que la base n est pas ouverte.
    var categories: MagasinDeCategories? {
        base.map { MagasinDeCategories(base: $0) }
    }

    /// Magasin de sources, nul tant que la base n est pas ouverte.
    var sourcesInstallees: MagasinDeSources? {
        base.map { MagasinDeSources(base: $0) }
    }

    /// Magasin de prereglages, nul tant que la base n est pas ouverte.
    var prereglages: MagasinDePrereglages? {
        base.map { MagasinDePrereglages(base: $0) }
    }

    /// Emplacements peses par l ecran de gestion du stockage.
    ///
    /// Les trois racines vivent a cote de la base, dans le dossier de support
    /// de l application. Les caches y sont aussi, plutot que dans le dossier de
    /// caches du systeme : le systeme les y viderait sans prevenir, et un
    /// chapitre telecharge qui disparait entre deux lancements serait pris pour
    /// une perte de donnees.
    var emplacementsDuStockage: EmplacementsDuStockage {
        let racine = Self.dossierDeSupport()

        return EmplacementsDuStockage(
            telechargements: racine.appendingPathComponent("Telechargements", isDirectory: true),
            cacheDeChapitres: racine.appendingPathComponent("CacheDeChapitres", isDirectory: true),
            cacheDImages: racine.appendingPathComponent("CacheDImages", isDirectory: true)
        )
    }

    /// Magasin de reglages, nul tant que la base n est pas ouverte.
    var reglages: MagasinDeReglages? {
        base.map { MagasinDeReglages(base: $0) }
    }

    /// Magasin d historique, nul tant que la base n est pas ouverte.
    var historique: MagasinDHistorique? {
        base.map { MagasinDHistorique(base: $0, incognito: incognito) }
    }

    /// Magasin de progression, nul tant que la base n est pas ouverte.
    var progression: MagasinDeProgression? {
        base.map { MagasinDeProgression(base: $0, incognito: incognito) }
    }

    /// Magasin des statistiques de lecture, nul tant que la base n est pas
    /// ouverte.
    ///
    /// Il recoit le meme registre que les deux autres. C est ce qui tient le
    /// premier critere de F059 : le comptage se suspend avec le reste des
    /// traces de lecture, et non selon un etat qui lui serait propre.
    var statistiques: MagasinDeStatistiques? {
        base.map { MagasinDeStatistiques(base: $0, incognito: incognito) }
    }

    /// Magasin de la veille de nouveaux chapitres, nul tant que la base n est
    /// pas ouverte.
    var veille: MagasinDeVeilleDeChapitres? {
        base.map { MagasinDeVeilleDeChapitres(base: $0) }
    }

    /// Cadence des reveils de la veille.
    ///
    /// Ce n est pas l intervalle entre deux verifications, qui appartient a
    /// `QuotaDeVeille` et vaut quatre heures. C est la frequence a laquelle la
    /// question est posee : le moteur repond presque toujours non, et le quart
    /// d heure existe pour qu une echeance atteinte pendant que l application
    /// tourne ne soit pas manquee de trois heures.
    private static let cadenceDesReveils: Duration = .seconds(15 * 60)

    /// Arme la veille de nouveaux chapitres, F060.
    ///
    /// La boucle ne decide de rien : elle repose la question, et c est
    /// `VeilleDeChapitres.decision` qui refuse ou accepte selon l interrupteur,
    /// l autorisation, la session incognito et les quotas. Un reveil de plus ne
    /// produit donc jamais une verification de plus.
    func demarrerLaVeille() {
        guard tacheDeVeille == nil, let base else {
            return
        }

        let moteur = moteurDeVeille(base: base)

        tacheDeVeille = Task {
            while Task.isCancelled == false {
                await moteur.tic()

                try? await Task.sleep(for: Self.cadenceDesReveils)
            }
        }
    }

    /// Coupe la veille.
    func arreterLaVeille() {
        tacheDeVeille?.cancel()
        tacheDeVeille = nil
    }

    /// Construit le moteur de veille autour des services de l application.
    private func moteurDeVeille(base: BaseDeDonnees) -> MoteurDeVeilleDeChapitres {
        let reglages = MagasinDeReglages(base: base)
        let incognito = incognito

        return MoteurDeVeilleDeChapitres(
            registre: sources,
            magasin: MagasinDeVeilleDeChapitres(base: base),
            centre: CentreDeNotificationsDuSysteme(),
            contexte: {
                // Les reglages sont relus a chaque decision. Une valeur figee a
                // la construction ferait continuer la veille apres l arret de
                // l interrupteur, jusqu au prochain lancement.
                ContexteDeVeille(
                    reglages: (try? reglages.reglages()) ?? .parDefaut,
                    session: incognito.sessionCourante
                )
            }
        )
    }

    private static func ouvrir() throws -> BaseDeDonnees {
        try BaseDeDonnees.surDisque(a: dossierDeSupport().appendingPathComponent(nomDuFichier))
    }

    /// Dossier de support de l application, ou vivent la base et les caches.
    ///
    /// Rend le dossier temporaire quand le systeme refuse le sien, ce qui n
    /// arrive qu en bac a sable mal configure. Mieux vaut une session qui ne
    /// garde rien qu une application qui ne demarre pas.
    static func dossierDeSupport() -> URL {
        let support = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        return (support ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "Yum", isDirectory: true)
    }
}
