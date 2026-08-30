import Foundation

//
// SynchronisationICloud
//
// Ce qui decide qu un changement part vers iCloud, a quelle cadence il part, et
// ce que l indicateur d etat montre pendant ce temps.
//
// La decision est batie exactement comme celle des suivis, et pour la meme
// raison : un changement qui ne part pas parce que l interrupteur est inactif
// ressemble en tout point a un changement qui ne part pas parce que la session
// est incognito ou parce que le reseau est tombe. Un booleen ne distinguerait
// pas les trois, l indicateur d etat afficherait la meme chose dans les trois
// cas, et le premier support utilisateur commencerait par une devinette.
//
// L ordre des questions est la garantie. Le mode incognito passe avant
// l abonnement, avant les interrupteurs et avant le reseau, il gagne donc
// toujours. Le reseau vient en dernier, et c est aussi voulu : un changement
// refuse par une regle n a rien a faire dans le journal, alors qu un changement
// autorise mais bloque par le reseau doit y entrer pour partir plus tard.
//

/// Ce que la regle repond quand un changement est pret a partir vers iCloud.
public enum DecisionDeSynchronisationICloud: Sendable, Equatable, Hashable {
    /// Le changement part maintenant.
    case envoyer

    /// Une session incognito court, section 11.
    case suspendueParIncognito

    /// La synchronisation iCloud demande un abonnement que l utilisateur n a
    /// pas, section 10.
    case verrouilleeParPremium

    /// L interrupteur de la section iCloud qui gouverne cette entite est
    /// inactif.
    case desactiveeParReglage

    /// Aucun compte iCloud n est ouvert sur cet appareil.
    case compteAbsent

    /// Le reseau est absent. Le changement est garde et repartira.
    case differeeHorsLigne

    /// Vrai quand le changement part maintenant.
    public var envoie: Bool {
        self == .envoyer
    }

    /// Vrai quand le changement doit entrer au journal.
    ///
    /// Hors ligne est le seul refus qui garde. C est tout le mode hors ligne :
    /// ce qui est autorise mais empeche attend, ce qui est interdit ne s ecrit
    /// nulle part. Un changement produit pendant une session incognito ne doit
    /// pas repartir a la fin de la session, sinon la session aurait laisse une
    /// trace, avec du retard.
    public var entreAuJournal: Bool {
        switch self {
        case .envoyer, .differeeHorsLigne: true
        case .suspendueParIncognito, .verrouilleeParPremium, .desactiveeParReglage, .compteAbsent: false
        }
    }
}

/// Ce qui entoure un envoi vers iCloud au moment ou il est decide.
public struct ContexteICloud: Sendable, Equatable {
    /// Reglages de l application, pour les deux interrupteurs de la section
    /// iCloud.
    public let reglages: ReglagesDeLApplication

    /// Etat de l abonnement.
    public let premium: EtatDePremium

    /// Session incognito au moment de la question.
    public let session: SessionIncognito

    /// Vrai quand un compte iCloud est ouvert sur l appareil.
    public let compteOuvert: Bool

    /// Vrai quand le reseau est joignable.
    public let enLigne: Bool

    public init(
        reglages: ReglagesDeLApplication,
        premium: EtatDePremium,
        session: SessionIncognito = .inactive,
        compteOuvert: Bool = true,
        enLigne: Bool = true
    ) {
        self.reglages = reglages
        self.premium = premium
        self.session = session
        self.compteOuvert = compteOuvert
        self.enLigne = enLigne
    }

    /// Le meme contexte avec un autre etat de reseau.
    public func avecReseau(_ joignable: Bool) -> ContexteICloud {
        ContexteICloud(
            reglages: reglages,
            premium: premium,
            session: session,
            compteOuvert: compteOuvert,
            enLigne: joignable
        )
    }
}

/// Cadence de la synchronisation, et budget de propagation entre appareils.
///
/// Les trois durees ne sont pas des reglages. Elles sont le critere
/// d acceptation lui meme, ecrit sous une forme que la suite de tests peut
/// verifier : la propagation d une progression d un appareil a l autre tient
/// dans trente secondes, et la somme des attentes le prouve avant meme qu un
/// octet ne parte.
public struct CadenceDeSynchronisation: Sendable, Equatable, Hashable {
    /// Temps pendant lequel un changement mure avant de partir.
    ///
    /// Il existe pour le regroupement. La position part toutes les deux
    /// secondes pendant la lecture, et envoyer chaque enregistrement ferait
    /// autant d appels reseau que de tournes de page. Deux secondes suffisent a
    /// coller les rafales sans se voir.
    public let delaiDeRegroupement: TimeInterval

    /// Intervalle entre deux interrogations du distant.
    ///
    /// C est le filet, pas le chemin normal. Le chemin normal est la
    /// notification poussee par CloudKit, qui arrive en quelques secondes.
    /// Le sondage existe parce qu une notification peut ne jamais arriver, et
    /// que le critere doit tenir meme dans ce cas la.
    public let intervalleDeSondage: TimeInterval

    /// Marge accordee aux allers retours reseau dans le calcul du budget.
    public let margeReseau: TimeInterval

    /// Temps maximal accorde a la propagation d un appareil a l autre.
    public let budgetDePropagation: TimeInterval

    public init(
        delaiDeRegroupement: TimeInterval,
        intervalleDeSondage: TimeInterval,
        margeReseau: TimeInterval,
        budgetDePropagation: TimeInterval
    ) {
        self.delaiDeRegroupement = delaiDeRegroupement
        self.intervalleDeSondage = intervalleDeSondage
        self.margeReseau = margeReseau
        self.budgetDePropagation = budgetDePropagation
    }

    /// Cadence du produit.
    public static let parDefaut = CadenceDeSynchronisation(
        delaiDeRegroupement: 2,
        intervalleDeSondage: 15,
        margeReseau: 5,
        budgetDePropagation: 30
    )

    /// Temps du pire cas entre le geste et son arrivee sur l autre appareil.
    ///
    /// Le pire cas est celui ou aucune notification n arrive : le changement
    /// mure, il part, et l autre appareil ne le decouvre qu au sondage suivant,
    /// qu il vient tout juste de manquer.
    public var pireCasDePropagation: TimeInterval {
        delaiDeRegroupement + intervalleDeSondage + margeReseau
    }

    /// Vrai quand le pire cas tient dans le budget.
    public var respecteLeBudget: Bool {
        pireCasDePropagation <= budgetDePropagation
    }
}

/// Ce que l indicateur d etat de la section iCloud montre.
///
/// L etat est une valeur du domaine et non une chaine. La couche vue lui donne
/// son libelle, sa couleur et son icone, et le paquet metier n a pas a savoir
/// ce qu est une couleur.
public enum EtatDeSynchronisationICloud: Sendable, Equatable, Hashable {
    /// Rien n est demande : les deux interrupteurs sont inactifs, ou
    /// l abonnement manque.
    case inactive

    /// Tout ce qui devait partir est parti, a cet instant.
    case aJour(le: Date?)

    /// Des changements attendent leur echeance ou leur tour.
    case enAttente(changements: Int)

    /// Un echange est en cours avec le distant.
    case echangeEnCours

    /// Le reseau manque. Les changements sont gardes.
    case horsLigne(changements: Int)

    /// La derniere tentative a echoue. Les changements sont gardes.
    case enEchec(changements: Int)

    /// Vrai quand quelque chose reste a envoyer.
    public var aDesChangementsEnAttente: Bool {
        changementsEnAttente > 0
    }

    /// Nombre de changements que l etat annonce comme non partis.
    public var changementsEnAttente: Int {
        switch self {
        case .inactive, .aJour, .echangeEnCours: 0
        case let .enAttente(nombre), let .horsLigne(nombre), let .enEchec(nombre): nombre
        }
    }
}

/// Regle d envoi vers iCloud.
public enum SynchronisationICloud {
    /// Fonction de la matrice premium dont la synchronisation depend,
    /// section 10.
    public static let fonctionConcernee = FonctionDeLApplication.synchronisationICloud

    /// Decide du sort d un changement de cette entite.
    public static func decision(
        pour entite: EntiteSynchronisee,
        selon contexte: ContexteICloud
    ) -> DecisionDeSynchronisationICloud {
        // Premiere question, et elle passe avant toutes les autres.
        guard contexte.session.autorise(entite.ecritureConcernee) else {
            return .suspendueParIncognito
        }

        guard MatriceDeVerrouillage.acces(a: fonctionConcernee, selon: contexte.premium).estOuvert else {
            return .verrouilleeParPremium
        }

        guard contexte.reglages.booleen(entite.reglageConcerne) else {
            return .desactiveeParReglage
        }

        guard contexte.compteOuvert else {
            return .compteAbsent
        }

        guard contexte.enLigne else {
            return .differeeHorsLigne
        }

        return .envoyer
    }

    /// Vrai quand au moins une entite peut circuler dans ce contexte.
    ///
    /// L indicateur s en sert pour distinguer une synchronisation qui n a rien
    /// a faire d une synchronisation eteinte.
    public static func estActive(selon contexte: ContexteICloud) -> Bool {
        EntiteSynchronisee.allCases.contains { entite in
            decision(pour: entite, selon: contexte).entreAuJournal
        }
    }
}
