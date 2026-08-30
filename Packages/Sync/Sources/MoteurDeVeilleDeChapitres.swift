import Core
import Foundation

//
// MoteurDeVeilleDeChapitres
//
// La verification periodique de F060 : ce qui interroge les sources declarant la
// veille, compare ce qu elles annoncent a ce que l appareil connait, et remet a
// l utilisateur une notification par serie.
//
// Le moteur ne dort jamais et ne cree aucune tache de fond. Il expose `tic`, et
// c est l appelant qui decide de la cadence reelle : le reveil accorde par le
// systeme en production, une horloge simulee dans la suite de tests. C est la
// meme separation que pour la synchronisation iCloud, et elle a la meme raison :
// verifier qu une verification ne repart pas avant quatre heures ne doit pas
// demander d attendre quatre heures.
//
// Le moteur vit dans Sync parce qu il est le seul endroit qui regarde a la fois
// les sources et l etat local. Sync est deja le paquet qui depend de Core, de
// Storage et de Sources, exactement pour cette raison.
//
// Quatre invariants tiennent la fonctionnalite.
//
// 1. L execution est comptee et enregistree avant d interroger quoi que ce soit.
//    Le systeme peut couper la tache a tout moment ; un comptage fait a la fin
//    disparaitrait avec elle, et le plafond quotidien ne serait jamais atteint.
// 2. Une source qui echoue n empeche jamais les autres d etre relues, et son
//    echec fait reculer la veille entiere au lieu de la marteler.
// 3. L etat du mode incognito est relu au moment d emettre, pas au moment de
//    decider. Une session ouverte pendant que les sources repondaient fait
//    taire ce qui allait partir.
// 4. Le budget de temps est verifie entre deux series, et l annulation est
//    propagee. Ce qui n a pas ete vu passe en tete de la prochaine execution,
//    la rotation garantissant qu aucune serie n est abandonnee.
//

/// Ce qu une execution de la veille a fait, ou pourquoi elle n a rien fait.
public struct RapportDeVeille: Sendable, Equatable {
    /// Ce que la regle a repondu au reveil.
    public let decision: DecisionDeVeille

    /// Series reellement interrogees pendant cette execution.
    public let seriesInterrogees: Int

    /// Notifications remises au centre, une par serie.
    public let notifications: [NotificationDeSerie]

    /// Sources qui n ont pas repondu.
    public let sourcesEnEchec: Int

    /// Vrai quand l execution s est arretee sur le budget de temps ou sur une
    /// annulation, en laissant des series pour la prochaine fois.
    public let interrompue: Bool

    public init(
        decision: DecisionDeVeille,
        seriesInterrogees: Int = 0,
        notifications: [NotificationDeSerie] = [],
        sourcesEnEchec: Int = 0,
        interrompue: Bool = false
    ) {
        self.decision = decision
        self.seriesInterrogees = seriesInterrogees
        self.notifications = notifications
        self.sourcesEnEchec = sourcesEnEchec
        self.interrompue = interrompue
    }

    /// Vrai quand la veille a travaille.
    public var aTravaille: Bool {
        decision.verifie
    }
}

/// Verification periodique des nouveaux chapitres, section 9, ligne
/// `Notifications de nouveaux chapitres`.
public actor MoteurDeVeilleDeChapitres {
    private let registre: RegistreDeSources
    private let magasin: any MagasinDeVeille
    private let centre: any CentreDeNotifications
    private let quota: QuotaDeVeille
    private let calendrier: Calendar
    private let contexte: @Sendable () -> ContexteDeVeille
    private let horloge: @Sendable () -> Date

    /// Construit le moteur.
    ///
    /// - Parameters:
    ///   - registre: les sources configurees. Seules celles qui declarent
    ///     `SourceCapacites.veilleDeNouveautes` sont interrogees.
    ///   - magasin: la ou l etat de la veille survit a la fermeture.
    ///   - centre: la ou une notification quitte l application.
    ///   - quota: les limites que la veille s impose.
    ///   - contexte: reglages, session et reseau, relus a chaque decision. Une
    ///     valeur figee a la construction ferait continuer la veille apres
    ///     l arret de l interrupteur.
    ///   - horloge: instant courant. Elle est injectee parce que le budget de
    ///     temps se mesure avec elle, et qu un test doit pouvoir l avancer.
    public init(
        registre: RegistreDeSources,
        magasin: any MagasinDeVeille,
        centre: any CentreDeNotifications,
        quota: QuotaDeVeille = .parDefaut,
        calendrier: Calendar = .autoupdatingCurrent,
        contexte: @escaping @Sendable () -> ContexteDeVeille,
        horloge: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.registre = registre
        self.magasin = magasin
        self.centre = centre
        self.quota = quota
        self.calendrier = calendrier
        self.contexte = contexte
        self.horloge = horloge
    }

    /// Fait avancer la veille a cet instant.
    ///
    /// L appel ne fait rien tant qu aucune echeance n est atteinte, il peut donc
    /// etre appele a chaque reveil accorde par le systeme, aussi rapproches
    /// soient ils.
    @discardableResult
    public func tic() async -> RapportDeVeille {
        let maintenant = horloge()

        guard let etatInitial = try? await magasin.etatDeVeille() else {
            // Sans etat, aucune limite ne peut etre tenue. Refuser est le seul
            // choix sur : interroger les sources reviendrait a le faire sans
            // plafond ni intervalle, et donc a depasser les quotas.
            return RapportDeVeille(
                decision: .reculApresEchec(prochaine: maintenant.addingTimeInterval(quota.reculInitial))
            )
        }

        // L autorisation vient du centre et non de l appelant. Elle peut avoir
        // ete retiree dans les reglages du systeme depuis le dernier reveil, et
        // le seul a le savoir est celui qui emet.
        let annonce = contexte()
        let contexteCourant = await ContexteDeVeille(
            reglages: annonce.reglages,
            session: annonce.session,
            autorisationAccordee: centre.autorisationAccordee(),
            enLigne: annonce.enLigne
        )

        let decision = VeilleDeChapitres.decision(
            etat: etatInitial,
            quota: quota,
            selon: contexteCourant,
            le: maintenant,
            calendrier: calendrier
        )

        guard decision.verifie else {
            return RapportDeVeille(decision: decision)
        }

        return await executer(etatInitial, le: maintenant)
    }

    // MARK: Execution

    /// Interroge les series du tour, puis emet ce qui a paru.
    private func executer(_ etatInitial: EtatDeVeille, le maintenant: Date) async -> RapportDeVeille {
        var etat = etatInitial
        etat.compterUneExecution(le: maintenant, calendrier: calendrier)

        // Enregistree avant tout appel : une coupure du systeme au milieu du
        // tour ne doit pas rendre cette execution invisible au plafond.
        try? await magasin.enregistrer(etat)

        guard let series = try? await magasin.seriesSurveillees() else {
            etat.compterUnEchec()
            try? await magasin.enregistrer(etat)

            return RapportDeVeille(decision: .verifier, sourcesEnEchec: 1)
        }

        let surveillables = await seriesDesSourcesDeclarantes(series)
        let tour = VeilleDeChapitres.seriesAInterroger(surveillables, quota: quota)
        let recolte = await recolter(tour, depuis: maintenant)

        let notifications = RegroupementDeNotifications.notifications(
            pour: recolte.nouveautes,
            session: contexte().session
        )

        var echecs = recolte.echecs
        var emises = notifications

        if notifications.isEmpty == false {
            do {
                try await centre.publier(notifications)
            } catch {
                // Ce qui n a pas pu etre emis n est pas signale comme emis, et
                // les series concernees seront reprises au prochain tour :
                // leurs chapitres restent inconnus de l appareil.
                emises = []
                echecs += 1
            }
        }

        if echecs > 0 {
            etat.compterUnEchec()
        } else {
            etat.compterUneReussite(le: maintenant)
        }

        try? await magasin.enregistrer(etat)

        return RapportDeVeille(
            decision: .verifier,
            seriesInterrogees: recolte.interrogees,
            notifications: emises,
            sourcesEnEchec: echecs,
            interrompue: recolte.interrompue
        )
    }

    /// Ce qu un tour de veille a rapporte.
    private struct Recolte {
        var nouveautes: [NouveauChapitre] = []
        var interrogees = 0
        var echecs = 0
        var interrompue = false
    }

    /// Interroge les series une par une, sous le budget de temps.
    ///
    /// Une par une et non toutes ensemble : le budget de temps ne veut rien dire
    /// si le travail part en parallele, et une bibliotheque de cinq cents series
    /// ouvrirait autant de connexions simultanees vers le meme serveur.
    private func recolter(_ series: [SerieSurveillee], depuis debut: Date) async -> Recolte {
        var recolte = Recolte()

        for serie in series {
            guard Task.isCancelled == false else {
                recolte.interrompue = true
                break
            }

            guard horloge().timeIntervalSince(debut) < quota.budgetDeTemps else {
                recolte.interrompue = true
                break
            }

            guard let resultat = await registre.interroger(serie.source, { source in
                try await source.chapitres(pour: serie.identifiantDistant)
            }) else {
                // La source a ete retiree entre la lecture de la base et le
                // tour. Ce n est pas un echec, il n y a simplement plus rien a
                // interroger.
                continue
            }

            recolte.interrogees += 1

            guard let annonces = resultat.valeur else {
                recolte.echecs += 1
                continue
            }

            recolte.nouveautes += NouveautesDeSerie.nouveautes(de: serie, annonces: annonces)

            try? await magasin.enregistrerLaVerification(
                de: serie.id,
                chapitresConnus: Set(annonces.map(\.identifiant)),
                le: horloge()
            )
        }

        return recolte
    }

    /// Les series servies par une source qui declare la veille.
    private func seriesDesSourcesDeclarantes(_ series: [SerieSurveillee]) async -> [SerieSurveillee] {
        let declarantes = await Set(
            registre.sourcesDeclarant(VeilleDeChapitres.capaciteRequise).map(\.id)
        )

        return series.filter { declarantes.contains($0.source) }
    }
}
