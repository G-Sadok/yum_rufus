import Foundation

//
// SynchronisationDesSuivis
//
// Ce qui decide si une progression part vers un service, et pourquoi elle ne
// part pas quand elle ne part pas.
//
// Le troisieme critere de la fonctionnalite est le plus facile a croire tenu
// sans l etre. Un envoi qui ne part pas parce que le reglage est inactif
// ressemble en tout point a un envoi qui ne part pas parce que la session est
// incognito, et une installation dont l interrupteur est reste sur inactif ne
// prouve rien du tout. La decision est donc une valeur nommee, pas un booleen,
// et chaque refus dit sa cause.
//
// L ordre des questions n est pas un detail de style, c est la garantie elle
// meme. Le mode incognito est demande en premier, avant l abonnement, avant le
// reglage, avant meme de savoir si un service est connecte. Il gagne donc
// toujours, quel que soit l etat du reste, et aucune combinaison ne peut le
// contourner.
//
// La question posee au mode incognito n est pas reecrite ici. Elle passe par
// `SessionIncognito.autorise(_:)` avec l ecriture `synchronisationVersLesSuivis`
// de la section 11. Recopier la regle aurait donne deux verites : celle de
// F051, et celle d ici, qui divergeraient au premier changement.
//

/// Ce que la regle repond quand une progression est prete a partir.
public enum DecisionDeSynchronisation: Sendable, Equatable, Hashable {
    /// La progression peut partir.
    case envoyer

    /// Une session incognito court, section 11.
    case suspendueParIncognito

    /// Les suivis demandent un abonnement que l utilisateur n a pas.
    case verrouilleeParPremium

    /// L interrupteur d envoi de la progression est inactif.
    case desactiveeParReglage

    /// Aucun compte n est connecte a ce service, ou sa session a expire.
    case serviceDeconnecte

    /// La serie n est liee a aucune entree de ce service.
    case aucuneLiaison

    /// L utilisateur demande a confirmer chaque envoi et n a pas confirme.
    case confirmationRequise

    /// Le service connait deja cette progression.
    case dejaAJour

    /// Vrai quand la progression part.
    public var envoie: Bool {
        self == .envoyer
    }
}

/// Ce qui entoure un envoi au moment ou il est decide.
///
/// Les cinq valeurs voyagent ensemble parce qu elles se lisent ensemble : une
/// decision prise avec le bon etat de connexion mais l ancienne session
/// incognito serait fausse, et rien dans une liste de parametres separes
/// n empeche de melanger deux instants. Les reunir donne aussi a l appelant un
/// seul objet a fabriquer, la ou il en assemblait cinq a chaque chapitre lu.
public struct ContexteDeSynchronisation: Sendable, Equatable {
    /// Etat de connexion du service vise.
    public let etat: EtatDeConnexionDeSuivi

    /// Reglages de l application, pour les deux interrupteurs de la section
    /// Suivis.
    public let reglages: ReglagesDeLApplication

    /// Etat de l abonnement.
    public let premium: EtatDePremium

    /// Session incognito au moment de la question.
    public let session: SessionIncognito

    /// Vrai quand l utilisateur vient d accepter cet envoi la.
    ///
    /// Sans effet quand la confirmation n est pas demandee par les reglages.
    public let confirmationAccordee: Bool

    public init(
        etat: EtatDeConnexionDeSuivi,
        reglages: ReglagesDeLApplication,
        premium: EtatDePremium,
        session: SessionIncognito,
        confirmationAccordee: Bool = false
    ) {
        self.etat = etat
        self.reglages = reglages
        self.premium = premium
        self.session = session
        self.confirmationAccordee = confirmationAccordee
    }

    /// Contexte compose de ce que l appelant apporte et de ce que le registre
    /// tient.
    public init(_ conditions: ConditionsDEnvoi, etat: EtatDeConnexionDeSuivi, session: SessionIncognito) {
        self.init(
            etat: etat,
            reglages: conditions.reglages,
            premium: conditions.premium,
            session: session,
            confirmationAccordee: conditions.confirmationAccordee
        )
    }
}

/// Ce que l appelant apporte quand il demande un envoi.
///
/// La separation avec le contexte n est pas cosmetique. L etat de connexion et
/// la session incognito appartiennent au registre, qui les tient a jour ; les
/// reglages, l abonnement et la confirmation appartiennent a l ecran qui
/// declenche l envoi. Un appelant qui pourrait fournir les cinq pourrait
/// affirmer une session close alors qu elle court.
public struct ConditionsDEnvoi: Sendable, Equatable {
    /// Reglages de l application.
    public let reglages: ReglagesDeLApplication

    /// Etat de l abonnement.
    public let premium: EtatDePremium

    /// Vrai quand l utilisateur vient d accepter cet envoi la.
    public let confirmationAccordee: Bool

    public init(
        reglages: ReglagesDeLApplication,
        premium: EtatDePremium,
        confirmationAccordee: Bool = false
    ) {
        self.reglages = reglages
        self.premium = premium
        self.confirmationAccordee = confirmationAccordee
    }
}

/// Regle d envoi de la progression vers un service de suivi.
public enum SynchronisationDesSuivis {
    /// Ecriture de session que cette regle commande, section 11.
    public static let ecritureConcernee = EcritureDeSession.synchronisationVersLesSuivis

    /// Fonction de la matrice premium dont l envoi depend, section 10.
    public static let fonctionConcernee = FonctionDeLApplication.suivis

    /// Decide si une progression part vers ce service.
    ///
    /// - Parameters:
    ///   - liaison: liaison de la serie avec le service, nulle quand la serie
    ///     n est liee a rien.
    ///   - chapitreLu: dernier chapitre lu localement.
    ///   - contexte: etat de connexion, reglages, abonnement et session au
    ///     moment de la question.
    public static func decision(
        liaison: LiaisonSuivi?,
        chapitreLu: Double,
        contexte: ContexteDeSynchronisation
    ) -> DecisionDeSynchronisation {
        // Premiere question, et elle passe avant toutes les autres.
        guard contexte.session.autorise(ecritureConcernee) else {
            return .suspendueParIncognito
        }

        guard MatriceDeVerrouillage.acces(a: fonctionConcernee, selon: contexte.premium).estOuvert else {
            return .verrouilleeParPremium
        }

        guard contexte.reglages.booleen(.envoyerLaProgression) else {
            return .desactiveeParReglage
        }

        guard contexte.etat.peutEnvoyer else {
            return .serviceDeconnecte
        }

        guard let liaison else {
            return .aucuneLiaison
        }

        guard liaison.chapitreVu < chapitreLu else {
            return .dejaAJour
        }

        if contexte.reglages.booleen(.confirmerAvantDEnvoyer), contexte.confirmationAccordee == false {
            return .confirmationRequise
        }

        return .envoyer
    }

    /// Liaison mise a jour pour l envoi, nulle quand rien ne doit partir.
    ///
    /// Le chapitre vu ne recule jamais. Un chapitre relu, ou une serie ouverte
    /// a la premiere page pour verifier un detail, ne doit pas ramener le
    /// service en arriere : ce que l utilisateur a lu, il l a lu, et une
    /// progression qui recule fait disparaitre une serie de sa liste en cours
    /// chez le service.
    public static func liaisonAEnvoyer(
        _ liaison: LiaisonSuivi,
        chapitreLu: Double,
        statut: StatutDeSuivi? = nil,
        le date: Date
    ) -> LiaisonSuivi? {
        guard liaison.chapitreVu < chapitreLu else {
            return nil
        }

        var partante = liaison
        partante.chapitreVu = chapitreLu
        partante.dateSynchronisation = date

        if let statut {
            partante.statut = statut
        }

        return partante
    }
}
