import Foundation

//
// MurPremium
//
// Ce que le mur montre, et la regle qui decide s il a le droit de s ouvrir.
//
// Le mur est le seul point d entree vers l achat, section 10 du cahier de
// developpement. Cette phrase a une consequence que le code doit porter et non
// esperer : aucune autre surface ne vend, et le mur lui meme ne s ouvre jamais
// de sa propre initiative.
//
// La phrase suivante de la meme section est plus stricte encore. Le mur ne surgit
// jamais pendant la lecture. Un lecteur de manga qui interrompt une page par une
// offre commerciale detruit exactement ce que la these du produit protege : la
// page doit rester seule dans le champ de vision. La garde de ce fichier refuse
// donc deux choses distinctes. Elle refuse tout declencheur qui ne vient pas d un
// geste de l utilisateur, ou qu il soit. Et elle refuse, pendant une session de
// lecture, tout geste venu d ailleurs que des commandes du lecteur lui meme.
//
// La couronne du panneau de filtres reste donc ouvrante, parce que la section 5.7
// la dessine ainsi : l utilisateur a touche la fonction verrouillee, il a demande
// le mur. Ce n est pas un surgissement, c est une reponse.
//

/// Les cinq avantages listes par le mur, section 5.9 de DESIGN-SPEC.md.
///
/// L ordre des cas est celui du document. Il est repris tel quel a l ecran, et
/// la suite de tests le compare au document lui meme.
public enum AvantagePremium: String, Sendable, CaseIterable, Hashable, Identifiable {
    /// Traduction et colorisation par IA.
    case traductionEtColorisation

    /// Serveurs Komga, Kavita, Jellyfin, OPDS.
    case serveurs

    /// Suivis sur vos services de suivi.
    case suivis

    /// Telechargements hors ligne.
    case telechargements

    /// Sauvegarde et synchronisation iCloud.
    case sauvegardeEtSynchronisation

    public var id: String {
        rawValue
    }
}

/// Ce que le mur propose une fois les tarifs lus.
public struct OffrePremium: Sendable, Equatable {
    /// Produit mis en avant par le bouton principal.
    public let produit: ProduitPremium

    /// Vrai quand l essai de sept jours est encore ouvert.
    ///
    /// Faux, le bouton cesse de promettre une periode gratuite et le mur vend
    /// l abonnement pour ce qu il est.
    public let essaiDisponible: Bool

    public init(produit: ProduitPremium, essaiDisponible: Bool) {
        self.produit = produit
        self.essaiDisponible = essaiDisponible
    }

    /// Periode offerte par cette offre, nulle quand l essai est ferme.
    public var essai: PeriodeDEssai? {
        essaiDisponible ? produit.essai : nil
    }
}

/// D ou vient une demande d ouverture du mur.
public enum OrigineDuMurPremium: String, Sendable, CaseIterable, Hashable {
    /// Bloc cale en bas de la barre laterale, section 2.2.
    case appelDeLaBarreLaterale

    /// Ligne `Passer a Premium` de la section Abonnement des reglages.
    case ligneDAbonnementDesReglages

    /// Ligne de reglage verrouillee, dont la couronne remplace le controle.
    case ligneVerrouilleeDesReglages

    /// Couronne d un traitement verrouille du panneau de filtres, section 5.7.
    case panneauDeFiltresDuLecteur

    /// Troisieme etape de la premiere ouverture, section 5.10.
    case premiereOuverture

    /// Vrai quand l origine est une commande du lecteur.
    ///
    /// Seules ces origines peuvent ouvrir le mur pendant une session de lecture,
    /// parce que ce sont les seules que l utilisateur peut actionner sans quitter
    /// sa page.
    public var appartientAuLecteur: Bool {
        self == .panneauDeFiltresDuLecteur
    }
}

/// Ce qui declenche une demande d ouverture.
public enum DeclencheurDuMurPremium: String, Sendable, CaseIterable, Hashable {
    /// L utilisateur a touche une commande qui mene au mur.
    case actionDeLUtilisateur

    /// L application a decide seule, au lancement, en fin de chapitre, ou parce
    /// qu une fonction verrouillee a ete atteinte par un chemin automatique.
    case evenementDeLApplication
}

/// Pourquoi une demande d ouverture est refusee.
public enum MotifDeRefusDuMur: String, Sendable, Equatable, CaseIterable {
    /// Le mur ne s ouvre jamais sans geste de l utilisateur.
    case surgissementInterdit

    /// Une session de lecture est en cours, et la demande ne vient pas du
    /// lecteur.
    case lectureEnCours
}

/// Reponse de la garde a une demande d ouverture.
public enum DecisionDOuvertureDuMur: Sendable, Equatable {
    /// Le mur peut etre presente.
    case ouvrir

    /// Le mur reste ferme, avec sa cause.
    case refuser(MotifDeRefusDuMur)

    /// Vrai quand le mur peut etre presente.
    public var autorise: Bool {
        self == .ouvrir
    }
}

/// Une demande d ouverture du mur, telle qu une commande la pose.
///
/// La demande porte tout ce dont la garde a besoin, et la couche vue ne presente
/// le mur que sur une demande acceptee. C est ce qui rend la regle de la section
/// 10 impossible a contourner par inadvertance : il n existe aucun chemin qui
/// affiche le mur sans passer par cette decision.
public struct DemandeDuMurPremium: Sendable, Equatable {
    /// Commande qui demande le mur.
    public let origine: OrigineDuMurPremium

    /// Geste de l utilisateur, ou decision de l application.
    public let declencheur: DeclencheurDuMurPremium

    /// Vrai quand un chapitre est ouvert dans le lecteur.
    public let lectureEnCours: Bool

    public init(
        origine: OrigineDuMurPremium,
        declencheur: DeclencheurDuMurPremium = .actionDeLUtilisateur,
        lectureEnCours: Bool = false
    ) {
        self.origine = origine
        self.declencheur = declencheur
        self.lectureEnCours = lectureEnCours
    }

    /// Decision de la garde sur cette demande.
    public var decision: DecisionDOuvertureDuMur {
        GardeDuMurPremium.decision(
            origine: origine,
            declencheur: declencheur,
            lectureEnCours: lectureEnCours
        )
    }

    /// Vrai quand le mur peut etre presente.
    public var estAcceptee: Bool {
        decision.autorise
    }
}

/// Seule porte par laquelle le mur premium s ouvre.
public enum GardeDuMurPremium {
    /// Decision rendue sur une demande d ouverture.
    ///
    /// - Parameters:
    ///   - origine: la commande qui demande le mur.
    ///   - declencheur: geste de l utilisateur, ou decision de l application.
    ///   - lectureEnCours: vrai quand un chapitre est ouvert dans le lecteur.
    public static func decision(
        origine: OrigineDuMurPremium,
        declencheur: DeclencheurDuMurPremium,
        lectureEnCours: Bool
    ) -> DecisionDOuvertureDuMur {
        guard declencheur == .actionDeLUtilisateur else {
            return .refuser(.surgissementInterdit)
        }

        guard lectureEnCours == false || origine.appartientAuLecteur else {
            return .refuser(.lectureEnCours)
        }

        return .ouvrir
    }
}
