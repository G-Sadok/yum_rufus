import Foundation

//
// VeilleDeChapitres
//
// Ce qui decide qu une verification de nouveaux chapitres part en arriere plan,
// et quelles series elle a le droit d interroger pendant le peu de temps que le
// systeme lui accorde. Les limites elles memes vivent dans `QuotaDeVeille`.
//
// La decision est une fonction pure, comme celle du rappel d objectif de F059 et
// celle de la synchronisation iCloud de F058. Elle n appelle ni le planificateur
// de taches du systeme, ni le centre de notifications, ni le reseau. C est ce
// qui rend le premier critere verifiable : le respect des quotas se lit dans une
// suite de tests qui avance une horloge, sans attendre quatre heures et sans
// dependre du bon vouloir du systeme.
//
// L ordre des questions est la garantie, exactement comme pour iCloud. Le mode
// incognito passe avant tout, il gagne donc toujours. Le reseau vient en
// dernier : une verification refusee par une regle n a pas a etre reprogrammee
// tout de suite, alors qu une verification autorisee mais sans reseau repartira
// des le prochain reveil.
//

/// Ce que la regle repond quand un reveil en arriere plan se presente.
public enum DecisionDeVeille: Sendable, Equatable, Hashable {
    /// La verification part maintenant.
    case verifier

    /// Une session incognito court, section 11.
    case suspendueParIncognito

    /// L interrupteur `Notifications de nouveaux chapitres` est inactif.
    case desactiveeParReglage

    /// L utilisateur n a pas accorde les notifications, ou les a retirees.
    ///
    /// Interroger les sources dans ce cas ferait depenser du reseau et de la
    /// batterie pour un resultat que personne ne verrait jamais.
    case autorisationRefusee

    /// Le dernier echec n a pas fini de reculer.
    case reculApresEchec(prochaine: Date)

    /// La derniere verification est trop recente.
    case intervalleNonEcoule(prochaine: Date)

    /// Le nombre d executions accordees a la journee est atteint.
    case quotaQuotidienAtteint(prochaine: Date)

    /// Le reseau manque. Rien n est interroge, rien n est perdu.
    case differeeHorsLigne

    /// Vrai quand la verification part maintenant.
    public var verifie: Bool {
        self == .verifier
    }

    /// Instant du prochain essai utile, quand la regle sait le nommer.
    ///
    /// Nul veut dire que l instant ne depend pas de l horloge mais d un
    /// changement d etat : un interrupteur, une autorisation, la fin de la
    /// session incognito ou le retour du reseau.
    public var prochaineTentative: Date? {
        switch self {
        case let .reculApresEchec(prochaine),
             let .intervalleNonEcoule(prochaine),
             let .quotaQuotidienAtteint(prochaine):
            prochaine

        case .verifier, .suspendueParIncognito, .desactiveeParReglage,
             .autorisationRefusee, .differeeHorsLigne:
            nil
        }
    }
}

/// Ce qui entoure un reveil au moment ou la veille est decidee.
public struct ContexteDeVeille: Sendable, Equatable {
    /// Reglages de l application, pour l interrupteur de la section General.
    public let reglages: ReglagesDeLApplication

    /// Session incognito au moment de la question.
    public let session: SessionIncognito

    /// Vrai quand l utilisateur a accorde les notifications.
    public let autorisationAccordee: Bool

    /// Vrai quand le reseau est joignable.
    public let enLigne: Bool

    public init(
        reglages: ReglagesDeLApplication,
        session: SessionIncognito = .inactive,
        autorisationAccordee: Bool = true,
        enLigne: Bool = true
    ) {
        self.reglages = reglages
        self.session = session
        self.autorisationAccordee = autorisationAccordee
        self.enLigne = enLigne
    }
}

/// Une serie de la bibliotheque que la veille suit.
public struct SerieSurveillee: Sendable, Equatable, Hashable, Identifiable {
    /// Identifiant de la serie dans la base.
    public let id: UUID

    /// Source qui sert cette serie.
    public let source: SourceID

    /// Identifiant de la serie chez cette source.
    public let identifiantDistant: String

    /// Titre affiche dans la notification.
    public let titre: String

    /// Identifiants distants des chapitres deja connus de cet appareil.
    public let chapitresConnus: Set<String>

    /// Derniere fois que cette serie a ete relue chez sa source.
    ///
    /// Nul veut dire jamais, et c est ce qui distingue une premiere visite
    /// d une visite ordinaire.
    public let derniereVerification: Date?

    public init(
        id: UUID,
        source: SourceID,
        identifiantDistant: String,
        titre: String,
        chapitresConnus: Set<String> = [],
        derniereVerification: Date? = nil
    ) {
        self.id = id
        self.source = source
        self.identifiantDistant = identifiantDistant
        self.titre = titre
        self.chapitresConnus = chapitresConnus
        self.derniereVerification = derniereVerification
    }

    /// Vrai quand la serie n a jamais ete relue par la veille.
    public var estUnePremiereVisite: Bool {
        derniereVerification == nil
    }
}

/// Regle de depart de la veille, et choix des series a interroger.
public enum VeilleDeChapitres {
    /// Ligne de reglage qui gouverne la veille, section 9, General.
    public static let reglageConcerne = IdentifiantDeReglage.notificationsDeNouveauxChapitres

    /// Capacite que doit declarer une source pour etre relue.
    public static let capaciteRequise = SourceCapacites.veilleDeNouveautes

    /// Decide si une verification part a cet instant.
    public static func decision(
        etat: EtatDeVeille,
        quota: QuotaDeVeille = .parDefaut,
        selon contexte: ContexteDeVeille,
        le date: Date,
        calendrier: Calendar = .autoupdatingCurrent
    ) -> DecisionDeVeille {
        // Premiere question, et elle passe avant toutes les autres.
        guard contexte.session.estActive == false else {
            return .suspendueParIncognito
        }

        guard contexte.reglages.booleen(reglageConcerne) else {
            return .desactiveeParReglage
        }

        guard contexte.autorisationAccordee else {
            return .autorisationRefusee
        }

        if let attente = attenteRestante(etat: etat, quota: quota, le: date) {
            return attente
        }

        if etat.executions(le: date, calendrier: calendrier) >= quota.executionsParJour {
            return .quotaQuotidienAtteint(prochaine: demain(apres: date, calendrier: calendrier))
        }

        guard contexte.enLigne else {
            return .differeeHorsLigne
        }

        return .verifier
    }

    /// Debut du jour civil suivant, ou le compteur quotidien repart de zero.
    ///
    /// Passe par le calendrier et non par une addition de vingt quatre heures :
    /// deux jours de l annee ne durent pas vingt quatre heures dans les fuseaux
    /// a heure d ete, et la prochaine tentative tomberait alors une heure avant
    /// ou apres le changement de jour.
    private static func demain(apres date: Date, calendrier: Calendar) -> Date {
        let debutDuJour = calendrier.startOfDay(for: date)

        return calendrier.date(byAdding: .day, value: 1, to: debutDuJour)
            ?? debutDuJour.addingTimeInterval(24 * 3600)
    }

    /// Attente imposee par le recul ou par l intervalle minimal, s il y en a une.
    ///
    /// Le recul remplace l intervalle, il ne s y ajoute pas. Une source tombee
    /// revient donc plus vite qu au bout de quatre heures quand le recul est
    /// plus court, sans que le plafond quotidien cesse de s appliquer : le
    /// nombre de reveils accordes reste le meme, seule leur repartition change.
    private static func attenteRestante(
        etat: EtatDeVeille,
        quota: QuotaDeVeille,
        le date: Date
    ) -> DecisionDeVeille? {
        guard let derniereTentative = etat.derniereTentative else {
            return nil
        }

        let recul = quota.recul(apres: etat.echecsConsecutifs)

        if recul > 0 {
            let echeance = derniereTentative.addingTimeInterval(recul)

            return date < echeance ? .reculApresEchec(prochaine: echeance) : nil
        }

        let echeance = derniereTentative.addingTimeInterval(quota.intervalleMinimal)

        return date < echeance ? .intervalleNonEcoule(prochaine: echeance) : nil
    }

    /// Les series a interroger pendant cette execution.
    ///
    /// L ordre est celui de la plus anciennement vue a la plus recemment vue,
    /// une serie jamais vue passant devant toutes les autres. C est ce qui fait
    /// que le plafond par execution retarde une serie sans jamais l abandonner.
    /// L identifiant departage a date egale, sans quoi l ordre dependrait de
    /// celui que la base a rendu et deux executions successives pourraient
    /// reprendre les memes series.
    public static func seriesAInterroger(
        _ series: [SerieSurveillee],
        quota: QuotaDeVeille = .parDefaut
    ) -> [SerieSurveillee] {
        let ordonnees = series.sorted { premiere, seconde in
            switch (premiere.derniereVerification, seconde.derniereVerification) {
            case (nil, nil):
                premiere.id.uuidString < seconde.id.uuidString
            case (nil, _):
                true
            case (_, nil):
                false
            case let (gauche?, droite?):
                gauche == droite
                    ? premiere.id.uuidString < seconde.id.uuidString
                    : gauche < droite
            }
        }

        return Array(ordonnees.prefix(quota.seriesParExecution))
    }
}
