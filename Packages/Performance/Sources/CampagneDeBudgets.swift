import Archive
import Core
import Foundation
import GRDB
import ImagePipeline
import ReaderEngine
import Storage

//
// CampagneDeBudgets
//
// Une mesure par budget de la section 12.
//
// Chaque mesure porte sur ce que la couche metier fait reellement, jamais sur du
// code ecrit pour l occasion. Une mesure qui chronometre une boucle inventee ne
// peut pas regresser, donc ne protege rien. Ce qui reste hors de portee ici est
// le rendu lui meme, qui appartient a la couche vue : c est dit mesure par
// mesure, parce qu un budget dont on ignore ce qu il ne couvre pas est un budget
// qu on croit tenir.
//

/// Execution d une mesure de budget, dans son propre processus.
public struct CampagneDeBudgets: Sendable {
    /// Zone d affichage servant de reference au decodage.
    ///
    /// C est la dalle d un iPad Pro de onze pouces en pixels reels, le materiel
    /// le plus modeste sur lequel la section 12 demande de tenir les budgets a
    /// cette densite.
    public static let zoneDAffichage = TailleEnPixels(largeur: 1668, hauteur: 2388)

    /// Nombre d images deroulees par une mesure de defilement.
    static let imagesDeDefilement = 1200

    /// Hauteur de la fenetre de defilement, en points.
    static let hauteurDeLaFenetre: Double = 900

    /// Nombre de series visibles dans une fenetre de la grille.
    ///
    /// Six colonnes sur dix rangs, ce que la grille de DESIGN-SPEC.md affiche au
    /// plus large, plus la rangee entamee en haut et celle en bas.
    static let seriesVisibles = 66

    let emplacement: EmplacementDuJeuDeTest
    let chronometre: Chronometre

    public init(emplacement: EmplacementDuJeuDeTest, chronometre: Chronometre = Chronometre()) {
        self.emplacement = emplacement
        self.chronometre = chronometre
    }

    /// Mesure le budget demande et rend la valeur dans son unite.
    public func mesurer(_ cle: CleDeBudget) throws -> MesureDeBudget {
        switch cle {
        case .lancementAFroid: try lancementAFroid()
        case .ouvertureDeChapitreLocal: try ouvertureDeChapitreLocal()
        case .tourneDePage: try tourneDePage()
        case .defilementDeLaGrille: try defilementDeLaGrille()
        case .defilementWebtoon: defilementWebtoon()
        case .memoireEnLecture: try memoireEnLecture()
        case .memoireAuRepos: try memoireAuRepos()
        }
    }

    // MARK: Lancement

    /// Ce que coute l ouverture de la base, sa migration et le premier
    /// remplissage de la grille sur une bibliotheque de 5000 series.
    ///
    /// Hors de portee : le rendu de la grille et le decodage des vignettes, qui
    /// arrivent apres l affichage et n entrent pas dans le lancement.
    func lancementAFroid() throws -> MesureDeBudget {
        guard let budget = BudgetDePerformance.pour(.lancementAFroid) else {
            throw ErreurDeMesure.jeuDeTestIncomplet(raison: "budget de lancement absent")
        }

        try exigerLeCorpus()

        var series = 0
        let valeur = try chronometre.meilleure(sous: budget) {
            try Chronometre.millisecondes {
                let base = try BaseDeDonnees.surDisque(a: emplacement.bibliotheque)

                series = try base.ecrivain.read { connexion in
                    try MangaDeGrille.enBibliotheque().fetchAll(connexion).count
                }
            }
        }

        return MesureDeBudget(
            cle: .lancementAFroid,
            valeur: valeur,
            detail: "ouverture de la base, lecture des reglages et remplissage de la grille de \(series) series"
        )
    }

    // MARK: Lecture locale

    /// Ce que coute l ouverture d un chapitre local jusqu a sa premiere page
    /// affichable : index central du CBZ, extraction de l entree, decodage sous
    /// echantillonne a la zone d affichage.
    ///
    /// Hors de portee : la pose de l image dans une vue.
    func ouvertureDeChapitreLocal() throws -> MesureDeBudget {
        guard let budget = BudgetDePerformance.pour(.ouvertureDeChapitreLocal) else {
            throw ErreurDeMesure.jeuDeTestIncomplet(raison: "budget d ouverture absent")
        }

        let chapitre = try exigerUnChapitre()
        let decodeur = DecodeurDePage()
        var taille = TailleEnPixels.nulle

        let valeur = try chronometre.meilleure(sous: budget) {
            try Chronometre.millisecondes {
                let document = try DocumentZip(contenuDe: chapitre)
                let reference = try document.referencePage(0)
                let octets = try document.donneesPage(reference)
                let page = try decodeur.decoder(
                    octets,
                    nom: reference.nom,
                    dans: Self.zoneDAffichage
                )

                taille = page.tailleDecodee
            }
        }

        return MesureDeBudget(
            cle: .ouvertureDeChapitreLocal,
            valeur: valeur,
            detail: "index CBZ, extraction et decodage de la page une en \(taille.largeur) par \(taille.hauteur)"
        )
    }

    /// Ce que coute la page suivante quand elle n a pas ete prechargee.
    ///
    /// C est le pire cas et c est volontaire : une tourne de page servie par le
    /// cache de precharge ne coute rien, la mesurer donnerait un budget tenu par
    /// construction. Ce qui est mesure est la pire tourne des pages du chapitre.
    func tourneDePage() throws -> MesureDeBudget {
        guard let budget = BudgetDePerformance.pour(.tourneDePage) else {
            throw ErreurDeMesure.jeuDeTestIncomplet(raison: "budget de tourne de page absent")
        }

        let chapitre = try exigerUnChapitre()
        let document = try DocumentZip(contenuDe: chapitre)
        let decodeur = DecodeurDePage()

        guard document.nombrePages > 1 else {
            throw ErreurDeMesure.jeuDeTestIncomplet(raison: "le chapitre du corpus n a qu une page")
        }

        let valeur = try chronometre.meilleure(sous: budget) {
            var pire: Double = 0

            for index in 1..<document.nombrePages {
                let duree = try Chronometre.millisecondes {
                    let reference = try document.referencePage(index)
                    let octets = try document.donneesPage(reference)
                    _ = try decodeur.decoder(octets, nom: reference.nom, dans: Self.zoneDAffichage)
                }

                pire = max(pire, duree)
            }

            return pire
        }

        return MesureDeBudget(
            cle: .tourneDePage,
            valeur: valeur,
            detail: "pire des \(document.nombrePages - 1) tournes de page du chapitre, sans precharge"
        )
    }

    // MARK: Defilements

    /// Ce que coute une image de defilement de la grille sur 5000 series.
    ///
    /// La fenetre visible est relue a chaque image, ce qui est le pire cas : une
    /// grille qui garde ses lignes en memoire coute moins. La mesure protege
    /// surtout contre la cinquieme erreur de la section 1 du cahier, le comptage
    /// de chapitres non lus a la volee : la pastille se lit ici dans une colonne
    /// denormalisee, et le jour ou un COUNT reapparait cette mesure s effondre.
    ///
    /// Hors de portee : la composition et le rendu des vignettes.
    func defilementDeLaGrille() throws -> MesureDeBudget {
        guard let budget = BudgetDePerformance.pour(.defilementDeLaGrille) else {
            throw ErreurDeMesure.jeuDeTestIncomplet(raison: "budget de grille absent")
        }

        try exigerLeCorpus()

        let base = try BaseDeDonnees.surDisque(a: emplacement.bibliotheque)
        let total = try base.ecrivain.read { connexion in
            try MangaDeGrille.enBibliotheque().fetchCount(connexion)
        }

        guard total > Self.seriesVisibles else {
            throw ErreurDeMesure.jeuDeTestIncomplet(raison: "la bibliotheque du corpus est trop courte")
        }

        let dernier = total - Self.seriesVisibles
        let valeur = try chronometre.meilleure(sous: budget) {
            var pire: Double = 0

            try base.ecrivain.read { connexion in
                for image in 0..<Self.imagesDeDefilement {
                    let position = (image * dernier) / Self.imagesDeDefilement
                    let debut = ContinuousClock.now

                    _ = try MangaDeGrille.enBibliotheque()
                        .limit(Self.seriesVisibles, offset: position)
                        .fetchAll(connexion)

                    pire = max(pire, Chronometre.duree(depuis: debut))
                }
            }

            return Chronometre.cadenceSoutenue(pireImage: pire)
        }

        return MesureDeBudget(
            cle: .defilementDeLaGrille,
            valeur: valeur,
            detail: "cadence deduite de la pire de \(Self.imagesDeDefilement) images sur \(total) series"
        )
    }

    /// Ce que coute une image de defilement webtoon.
    ///
    /// Le chapitre mesure est le plus couteux : des bandes de quatorze mille
    /// pixels sur une colonne etroite, donc beaucoup de tuiles courtes, donc une
    /// fenetre qui change presque a chaque image.
    ///
    /// Hors de portee : le rendu des tuiles par Metal, et le decodage, qui vit
    /// dans l atelier et non dans la boucle de defilement.
    func defilementWebtoon() -> MesureDeBudget {
        let budget = BudgetDePerformance.pour(.defilementWebtoon)
        let pile = Self.chapitreDeWebtoon(bandes: 60)
        let capacite = pile.budgetDeTuiles(hauteurDeLaFenetre: Self.hauteurDeLaFenetre)
        let pas = pile.pile.hauteurTotale / Double(Self.imagesDeDefilement)

        let passe: () -> Double = {
            var pool = RecyclageDeVues(capacite: capacite)
            var pire: Double = 0

            // Chauffe : la mesure porte sur le regime etabli, pas sur
            // l ouverture du chapitre, qui alloue les tables du pool.
            for image in 0..<200 {
                _ = pool.mettreAJour(
                    fenetre: pile.fenetreDeTuiles(
                        auDecalage: Double(image) * pas,
                        hauteurDeLaFenetre: Self.hauteurDeLaFenetre,
                        budget: capacite
                    )
                )
            }

            for image in 0..<Self.imagesDeDefilement {
                let decalage = Double(image) * pas
                let debut = ContinuousClock.now

                let fenetre = pile.fenetreDeTuiles(
                    auDecalage: decalage,
                    hauteurDeLaFenetre: Self.hauteurDeLaFenetre,
                    budget: capacite
                )
                _ = pool.mettreAJour(fenetre: fenetre)
                _ = pile.tuilesVisibles(auDecalage: decalage, hauteurDeLaFenetre: Self.hauteurDeLaFenetre)

                pire = max(pire, Chronometre.duree(depuis: debut))
            }

            return Chronometre.cadenceSoutenue(pireImage: pire)
        }

        let valeur = budget.map { chronometre.meilleure(sous: $0, passe: passe) } ?? passe()

        return MesureDeBudget(
            cle: .defilementWebtoon,
            valeur: valeur,
            detail: "cadence deduite de la pire de \(Self.imagesDeDefilement) images sur \(pile.nombreDeTuiles) tuiles"
        )
    }

    /// Un chapitre de webtoon fait de bandes trop hautes pour une seule texture.
    static func chapitreDeWebtoon(bandes: Int) -> PileDeTuiles {
        let tuilage = TuilageDImageLongue.parDefaut
        var hauteurs: [Double] = []
        var decoupes: [[DecoupeDeTuile]] = []

        for bande in 0..<bandes {
            let hauteurEnPixels = 14000 + (bande % 7) * 1000
            let taille = TailleEnPixels(largeur: 800, hauteur: hauteurEnPixels)

            hauteurs.append(Double(hauteurEnPixels) * 0.1)
            decoupes.append(tuilage.decoupes(de: taille))
        }

        return PileDeTuiles(
            pile: DefilementContinu(hauteurs: hauteurs, interstice: EspacementEntrePages(points: 8).interstice),
            decoupes: decoupes
        )
    }

    // MARK: Memoire

    /// Empreinte du processus apres la lecture d un chapitre entier, cache LRU
    /// et precharge compris.
    ///
    /// Le cache est celui de l application, avec son plafond par defaut de six
    /// pages ou 220 Mo. Rien n est vide en cours de route : ce que la mesure
    /// veut savoir est ou monte l empreinte quand un lecteur enchaine les pages
    /// sans jamais fermer le chapitre.
    func memoireEnLecture() throws -> MesureDeBudget {
        let chapitre = try exigerUnChapitre()
        let document = try DocumentZip(contenuDe: chapitre)
        let decodeur = DecodeurDePage()
        let cache = CacheMemoireDePages()
        let identifiantDuChapitre = UUID()

        var pointe = try EmpreinteMemoire.megaOctetsUtilises()

        for index in 0..<document.nombrePages {
            let reference = try document.referencePage(index)
            let octets = try document.donneesPage(reference)
            let page = try decodeur.decoder(octets, nom: reference.nom, dans: Self.zoneDAffichage)
            let cle = ClePage(chapitre: identifiantDuChapitre, index: index)

            deposerSansAttendre(page, pour: cle, dans: cache)
            pointe = try max(pointe, EmpreinteMemoire.megaOctetsUtilises())
        }

        return MesureDeBudget(
            cle: .memoireEnLecture,
            valeur: pointe,
            detail: "pointe d empreinte sur la lecture des \(document.nombrePages) pages du chapitre"
        )
    }

    /// Empreinte du processus une fois la bibliotheque de 5000 series chargee,
    /// sans qu aucun chapitre soit ouvert.
    func memoireAuRepos() throws -> MesureDeBudget {
        try exigerLeCorpus()

        let base = try BaseDeDonnees.surDisque(a: emplacement.bibliotheque)
        let series = try base.ecrivain.read { connexion in
            try MangaDeGrille.enBibliotheque().fetchAll(connexion)
        }

        let empreinte = try EmpreinteMemoire.megaOctetsUtilises()

        return MesureDeBudget(
            cle: .memoireAuRepos,
            valeur: empreinte,
            detail: "empreinte avec les \(series.count) series de la bibliotheque chargees, aucun chapitre ouvert"
        )
    }

    /// Depose une page dans le cache et attend que l acteur l ait prise.
    ///
    /// Le cache est un acteur, la mesure est synchrone. Sans cette attente, la
    /// pointe d empreinte serait relevee avant que le cache ait retenu quoi que
    /// ce soit, et le budget memoire serait tenu par un cache vide.
    private func deposerSansAttendre(_ page: ImageDePage, pour cle: ClePage, dans cache: CacheMemoireDePages) {
        let verrou = DispatchSemaphore(value: 0)

        Task {
            await cache.marquerVisible(cle)
            _ = await cache.deposer(page, pour: cle)
            verrou.signal()
        }

        verrou.wait()
    }

    // MARK: Garde du corpus

    /// Refuse de mesurer sans corpus.
    ///
    /// Une mesure sur une base absente rendrait une duree minuscule et un budget
    /// tenu, ce qui est le pire resultat possible : vert et faux.
    private func exigerLeCorpus() throws {
        guard emplacement.estMaterialise else {
            throw ErreurDeMesure.jeuDeTestAbsent(chemin: emplacement.genere.path)
        }
    }

    private func exigerUnChapitre() throws -> URL {
        try exigerLeCorpus()

        return emplacement.chapitre(rang: 0)
    }
}
