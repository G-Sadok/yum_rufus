import Core
import ImagePipeline

//
// PrechargeDesPagesVoisines
//
// File de precharge des pages voisines, distincte de la production de la page
// visible et annulable, comme l impose la section 6.2.
//
// Trois choix structurent ce type.
//
// La file est serielle. Lancer les trois voisines en parallele multiplierait
// par trois la memoire en vol et la charge processeur au moment precis ou la
// page visible en a besoin. Une seule precharge court a la fois, les autres
// attendent dans une file ordonnee par priorite, celle de `PlanDePrecharge`.
//
// La production de la page visible ne passe jamais par cette file. Elle est
// rendue par une methode non isolee, qui n emprunte ni l acteur ni la file, et
// ne peut donc pas se retrouver derriere une precharge en attente.
//
// L annulation est reelle et non differee. Un changement de page annule la
// precharge en cours si elle est devenue inutile, vide la file de ce qui ne
// sert plus, et une precharge annulee ne depose rien dans le cache, meme si son
// decodage etait deja termine au moment de l annulation.
//

/// Reglages de production des pages du lecteur.
public struct ReglagesDePrecharge: Sendable, Hashable {
    /// Zone d affichage en pixels reels.
    public let zone: TailleEnPixels

    /// Fenetre de precharge autour de la page lue.
    public let plan: PlanDePrecharge

    /// Etat de production des pages, repris dans les cles de cache.
    public let variante: String

    public init(zone: TailleEnPixels, plan: PlanDePrecharge = .parDefaut, variante: String = "") {
        self.zone = zone
        self.plan = plan
        self.variante = variante
    }
}

/// Precharge les pages voisines de la page lue, sur une file annulable.
public actor PrechargeDesPagesVoisines {
    /// Precharge en cours, avec le numero qui l identifie.
    ///
    /// Le numero sert a distinguer une precharge annulee de celle qui l a
    /// remplacee. Sans lui, la fin tardive d une precharge annulee effacerait
    /// l etat de la precharge suivante, deja lancee sur la meme cle.
    private struct PrechargeEnCours {
        let cle: ClePage
        let numero: Int
        let tache: Task<Void, Never>
    }

    /// Ce dont une precharge a besoin une fois detachee de l acteur.
    private struct ContexteDePrecharge: Sendable {
        let fournisseur: any FournisseurDeChapitre
        let atelier: any AtelierDeDecodage
        let arbitre: ArbitreDeDecodage
        let cache: CacheMemoireDePages
        let zone: TailleEnPixels
    }

    private nonisolated let fournisseur: any FournisseurDeChapitre
    private nonisolated let cache: CacheMemoireDePages
    private nonisolated let atelier: any AtelierDeDecodage
    private nonisolated let arbitre: ArbitreDeDecodage
    private nonisolated let reglages: ReglagesDePrecharge

    private var fileDAttente: [ClePage] = []
    private var enCours: PrechargeEnCours?
    private var numeroDeLaDerniere = 0

    public init(
        fournisseur: any FournisseurDeChapitre,
        cache: CacheMemoireDePages,
        reglages: ReglagesDePrecharge,
        atelier: any AtelierDeDecodage = AtelierSousEchantillonne(),
        arbitre: ArbitreDeDecodage = ArbitreDeDecodage()
    ) {
        self.fournisseur = fournisseur
        self.cache = cache
        self.reglages = reglages
        self.atelier = atelier
        self.arbitre = arbitre
    }

    /// Cles encore en file, de la plus utile a la moins utile.
    public var clesEnAttente: [ClePage] {
        fileDAttente
    }

    /// Cle en cours de precharge, s il y en a une.
    public var cleEnCours: ClePage? {
        enCours?.cle
    }

    /// Vrai quand plus rien n est ni en cours ni en attente.
    public var fileEstVide: Bool {
        enCours == nil && fileDAttente.isEmpty
    }

    /// Rend la page que l utilisateur regarde, et la marque visible au cache.
    ///
    /// Non isolee volontairement : elle ne prend jamais l acteur, donc jamais la
    /// file de precharge. Une page deja prechargee revient du cache sans le
    /// moindre decodage, ce qui est la raison d etre de la fonctionnalite.
    ///
    /// - Parameter index: page a afficher, indexee a partir de zero.
    /// - Throws: l erreur de la source ou du decodeur, telle quelle. C est
    ///   l ecran qui sait s il existe une sortie a proposer.
    public nonisolated func pageVisible(_ index: Int) async throws -> ImageDePage {
        let cle = cle(pour: index)

        await cache.marquerVisible(cle)

        if let dejaDecodee = await cache.image(pour: cle) {
            return dejaDecodee
        }

        await arbitre.commencerUnePageVisible()

        do {
            let image = try await produire(cle)
            await arbitre.terminerUnePageVisible()

            return image
        } catch {
            await arbitre.terminerUnePageVisible()

            throw error
        }
    }

    /// Annonce la page lue, annule les precharges devenues inutiles et relance
    /// la file sur les nouvelles voisines.
    ///
    /// A appeler a chaque changement de page, avant ou apres `pageVisible`,
    /// l ordre n a pas d importance.
    public func deplacerVers(_ index: Int) {
        let voulues = reglages.plan
            .voisines(de: index, nombreDePages: fournisseur.nombreDePages)
            .map { cle(pour: $0) }

        fileDAttente = voulues.filter { $0 != enCours?.cle }

        if let precharge = enCours, voulues.contains(precharge.cle) == false {
            precharge.tache.cancel()
            enCours = nil
        }

        lancerLaSuite()
    }

    /// Annule toute precharge, en cours comme en attente.
    ///
    /// A appeler a la fermeture du lecteur, sans quoi des pages continueraient
    /// d etre decodees pour un ecran que plus personne ne regarde.
    public func arreter() {
        fileDAttente.removeAll()
        enCours?.tache.cancel()
        enCours = nil
    }

    /// Lance la precharge suivante, s il y en a une et si la voie est libre.
    private func lancerLaSuite() {
        guard enCours == nil, fileDAttente.isEmpty == false else {
            return
        }

        let cle = fileDAttente.removeFirst()
        numeroDeLaDerniere += 1
        let numero = numeroDeLaDerniere
        let contexte = contexteDePrecharge

        // Detachee et non structuree : une precharge ne doit heriter ni de la
        // priorite ni de l isolation de qui l a declenchee, sans quoi elle
        // remonterait au niveau de la page visible.
        let tache = Task.detached(priority: .utility) { [weak self] in
            await Self.precharger(cle, contexte: contexte)
            await self?.achever(numero: numero)
        }

        enCours = PrechargeEnCours(cle: cle, numero: numero, tache: tache)
    }

    /// Referme une precharge et enchaine, si elle n a pas deja ete remplacee.
    private func achever(numero: Int) {
        guard enCours?.numero == numero else {
            return
        }

        enCours = nil
        lancerLaSuite()
    }

    /// Decode une voisine et la depose au cache, en cedant le pas a la page
    /// visible et en s arretant des que l annulation arrive.
    ///
    /// Les erreurs sont avalees, et c est voulu : une page illisible en
    /// precharge ne doit rien afficher ni rien interrompre. L utilisateur la
    /// rencontrera par `pageVisible`, qui lui, remonte l erreur avec son
    /// message.
    private static func precharger(_ cle: ClePage, contexte: ContexteDePrecharge) async {
        guard await contexte.cache.contient(cle) == false, Task.isCancelled == false else {
            return
        }

        guard let page = try? await contexte.fournisseur.octets(page: cle.index),
              Task.isCancelled == false
        else {
            return
        }

        await contexte.arbitre.attendreUnCreneau()

        guard Task.isCancelled == false,
              let image = try? contexte.atelier.decoder(page.donnees, nom: page.nom, dans: contexte.zone),
              Task.isCancelled == false
        else {
            return
        }

        await contexte.cache.deposer(image, pour: cle)
    }

    /// Produit la page visible : octets, decodage, depot au cache.
    private nonisolated func produire(_ cle: ClePage) async throws -> ImageDePage {
        let page = try await fournisseur.octets(page: cle.index)
        let image = try atelier.decoder(page.donnees, nom: page.nom, dans: reglages.zone)

        await cache.deposer(image, pour: cle)

        return image
    }

    private nonisolated var contexteDePrecharge: ContexteDePrecharge {
        ContexteDePrecharge(
            fournisseur: fournisseur,
            atelier: atelier,
            arbitre: arbitre,
            cache: cache,
            zone: reglages.zone
        )
    }

    private nonisolated func cle(pour index: Int) -> ClePage {
        ClePage(chapitre: fournisseur.chapitre, index: index, variante: reglages.variante)
    }
}
