import Foundation

//
// ModeIncognito
//
// La session sans trace de la section 11 du cahier de developpement, ecrite une
// seule fois et consultee partout.
//
// Le document tient en une phrase : aucune ecriture dans l historique, aucune
// mise a jour de progression, aucune synchronisation vers les suivis, et la
// banniere reste visible pendant toute la session.
//
// La garantie n est pas tenue par une promesse ecrite en commentaire, elle est
// tenue par le type des ecritures. `EcritureDeSession` enumere tout ce que le
// produit peut deposer quelque part pendant une session de lecture, et chaque
// cas dit lui meme s il laisse une trace de lecture. Une ecriture ajoutee au
// produit et oubliee ici ne compile pas : l aiguillage de
// `laisseUneTraceDeLecture` est exhaustif.
//
// Arbitrage a poser une fois pour toutes, parce qu il decide de ce que le mot
// aucune recouvre. La section 11 nomme trois familles d ecriture, et ce sont
// exactement celles qui tracent ce que l utilisateur a lu. Elle n interdit pas
// au produit de fonctionner : un reglage change pendant la session s enregistre,
// sans quoi l interrupteur qui arrete le mode incognito ne pourrait pas
// s arreter lui meme. Un signet pose a la main s enregistre aussi, parce que
// c est un geste explicite dont l utilisateur attend un resultat visible, et
// qu une commande qui ne fait rien en silence est un bogue, pas une protection.
// La frontiere est donc la trace de lecture, pas l ecriture en general.
//

/// Une ecriture que le produit peut faire pendant une session de lecture.
///
/// Les deux familles vivent dans la meme enumeration plutot que dans deux
/// listes, pour la meme raison que la matrice premium : une ecriture qui passe
/// d une famille a l autre se voit dans un diff, et la suite de tests confronte
/// la liste bloquee a la phrase du document au lieu de la recopier.
public enum EcritureDeSession: String, Sendable, CaseIterable, Hashable {
    // Ecritures qui tracent ce que l utilisateur a lu.

    /// Une entree dans l historique de lecture.
    case historiqueDeLecture

    /// La page atteinte et le decalage de defilement d un chapitre.
    case positionDeLecture

    /// Le passage automatique d un chapitre a l etat lu.
    case marquageDUnChapitreLu

    /// La date de derniere lecture portee par la serie, qui decide de son rang
    /// dans la grille.
    case dateDeDerniereLectureDeLaSerie

    /// L envoi de la progression vers un service de suivi.
    case synchronisationVersLesSuivis

    /// Le comptage d un passage de lecture dans les statistiques.
    case statistiquesDeLecture

    // Ecritures qui ne tracent aucune lecture.

    /// Une valeur de l ecran Reglages.
    case reglagesDeLApplication

    /// L ajout ou le retrait d une serie de la bibliotheque.
    case bibliotheque

    /// Les categories et leur ordre.
    case categories

    /// Un signet pose a la main sur une page.
    case signets

    /// La file de telechargements et les chapitres poses sur le disque.
    case telechargements

    /// La configuration d une source.
    case sourcesConfigurees

    /// Le cache d images sur le disque.
    case cacheDImages

    /// Vrai quand cette ecriture dit quelque chose de ce que l utilisateur a lu.
    ///
    /// C est la seule question que le mode incognito pose. Une ecriture qui
    /// repond oui est suspendue pendant la session, les autres continuent.
    public var laisseUneTraceDeLecture: Bool {
        switch self {
        case .historiqueDeLecture, .positionDeLecture, .marquageDUnChapitreLu,
             .dateDeDerniereLectureDeLaSerie, .synchronisationVersLesSuivis,
             .statistiquesDeLecture:
            true

        case .reglagesDeLApplication, .bibliotheque, .categories, .signets,
             .telechargements, .sourcesConfigurees, .cacheDImages:
            false
        }
    }

    /// Les ecritures qu une session incognito suspend.
    public static var tracesDeLecture: [EcritureDeSession] {
        allCases.filter(\.laisseUneTraceDeLecture)
    }
}

/// Ce qui arrive a l application pendant qu une session incognito court.
///
/// L enumeration existe pour une seule raison : rendre mesurable le critere
/// selon lequel la banniere reste visible toute la session. Sans elle, la
/// permanence serait une intention, et la suite de tests ne pourrait que
/// verifier un booleen a un instant donne.
public enum EvenementDeSession: Sendable, Equatable, CaseIterable {
    /// L utilisateur change d ecran principal.
    case navigationVersUnAutreEcran

    /// Un chapitre s ouvre dans le lecteur.
    case ouvertureDUnChapitre

    /// Le lecteur se referme.
    case fermetureDuLecteur

    /// L application passe en arriere plan.
    case passageEnArrierePlan

    /// L application revient au premier plan.
    case retourAuPremierPlan

    /// Le verrouillage de l app se declenche.
    case verrouillageDeLApp

    /// L utilisateur deverrouille l application.
    case deverrouillageDeLApp

    /// Un reglage change pendant la session.
    case changementDUnReglage

    /// Vrai quand cet evenement met fin a la session incognito.
    ///
    /// La reponse est toujours fausse, et c est le sujet. Seul l arret explicite
    /// du mode termine la session. Ajouter un evenement qui la coupe demanderait
    /// de mentir ici, ce qui se voit dans un diff et fait virer la suite au
    /// rouge.
    public var termineLaSession: Bool {
        switch self {
        case .navigationVersUnAutreEcran, .ouvertureDUnChapitre, .fermetureDuLecteur,
             .passageEnArrierePlan, .retourAuPremierPlan, .verrouillageDeLApp,
             .deverrouillageDeLApp, .changementDUnReglage:
            false
        }
    }
}

/// Une session de lecture qui ne laisse aucune trace, section 11.
public struct SessionIncognito: Sendable, Equatable, Hashable {
    /// Instant ou la session a commence, nul quand aucune session ne court.
    public private(set) var demarreeLe: Date?

    /// Aucune session en cours.
    public static let inactive = SessionIncognito()

    public init(demarreeLe: Date? = nil) {
        self.demarreeLe = demarreeLe
    }

    /// Session commencee a cet instant.
    public static func demarree(le date: Date) -> SessionIncognito {
        SessionIncognito(demarreeLe: date)
    }

    /// Vrai quand une session court.
    public var estActive: Bool {
        demarreeLe != nil
    }

    /// Ouvre une session, ou laisse courir celle qui est deja ouverte.
    ///
    /// Redemarrer une session en cours reculerait sa date de debut sans rien
    /// changer a son effet, et ferait clignoter la banniere.
    public mutating func demarrer(le date: Date) {
        guard demarreeLe == nil else {
            return
        }

        demarreeLe = date
    }

    /// Ferme la session.
    public mutating func arreter() {
        demarreeLe = nil
    }

    /// Vrai quand cette ecriture peut partir dans l etat courant.
    public func autorise(_ ecriture: EcritureDeSession) -> Bool {
        estActive == false || ecriture.laisseUneTraceDeLecture == false
    }

    /// Ecritures que la session suspend, vides quand aucune session ne court.
    public var ecrituresSuspendues: Set<EcritureDeSession> {
        guard estActive else {
            return []
        }

        return Set(EcritureDeSession.tracesDeLecture)
    }

    /// Vrai quand la banniere doit etre a l ecran.
    ///
    /// La condition est la session elle meme, et rien d autre. Ni l ecran
    /// affiche, ni le temps ecoule, ni le passage en arriere plan n entrent
    /// dans la reponse : c est ce qui fait tenir le critere de permanence.
    public var porteLaBanniere: Bool {
        estActive
    }

    /// Session apres cet evenement.
    ///
    /// Elle est rendue telle quelle, et c est la regle de permanence elle meme.
    /// Le sens de cette fonction n est pas de calculer quelque chose, il est
    /// d etre le seul endroit ou une coupure de session pourrait s ecrire, et de
    /// ne pas en porter.
    public func apres(_ evenement: EvenementDeSession) -> SessionIncognito {
        evenement.termineLaSession ? .inactive : self
    }

    /// Session apres toute une suite d evenements.
    public func apres(_ evenements: [EvenementDeSession]) -> SessionIncognito {
        evenements.reduce(self) { session, evenement in session.apres(evenement) }
    }
}
