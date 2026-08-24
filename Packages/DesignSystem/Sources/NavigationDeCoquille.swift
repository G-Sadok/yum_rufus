import Core
import SwiftUI

//
// Forme de la navigation principale selon le gabarit, section 2.5 de
// DESIGN-SPEC.md.
//
// La decision est prise ici, hors de toute vue, pour qu elle soit verifiable
// par un test et identique sur les trois plateformes.
//

/// Classe de taille horizontale de la scene.
///
/// Reprise de la notion du systeme, mais redeclaree pour que la decision de
/// navigation reste testable sans construire une scene.
public enum ClasseDeTaille: String, CaseIterable, Sendable {
    /// iPhone, ou une scene etroite sur iPad.
    case compacte
    /// iPad plein ecran, macOS.
    case reguliere
}

/// Nature de l appareil qui affiche la coquille.
public enum PlateformeDAffichage: String, CaseIterable, Sendable {
    /// macOS, pointeur et clavier.
    case bureau
    /// iPadOS et iOS, doigt d abord.
    case tactile
}

/// Ce que la coquille sait de la scene au moment de choisir sa navigation.
public struct ContexteDeCoquille: Sendable, Equatable, Hashable {
    /// Nature de l appareil.
    public let plateforme: PlateformeDAffichage
    /// Classe de taille horizontale de la scene.
    public let classeHorizontale: ClasseDeTaille
    /// Vrai quand la scene est plus large que haute.
    public let estEnPaysage: Bool

    public init(
        plateforme: PlateformeDAffichage,
        classeHorizontale: ClasseDeTaille,
        estEnPaysage: Bool
    ) {
        self.plateforme = plateforme
        self.classeHorizontale = classeHorizontale
        self.estEnPaysage = estEnPaysage
    }

    /// Contexte d une fenetre macOS.
    public static let bureau = ContexteDeCoquille(
        plateforme: .bureau,
        classeHorizontale: .reguliere,
        estEnPaysage: true
    )
}

/// Forme que prend la navigation principale, section 2.5.
public enum PresentationDeNavigation: String, CaseIterable, Sendable {
    /// Barre laterale encastree de 196, macOS et iPad paysage.
    case barreLaterale
    /// Barre laterale repliee a 56, iPad portrait.
    case barreLateraleRepliee
    /// Barre d onglets basse, iPhone.
    case barreDOnglets

    /// Presentation imposee par le gabarit, tableau 2.5.
    ///
    /// macOS garde toujours la barre deployee. Sur tactile, une scene compacte
    /// passe en barre d onglets, une scene reguliere garde la barre laterale,
    /// repliee en portrait et deployee en paysage.
    public static func pour(_ contexte: ContexteDeCoquille) -> PresentationDeNavigation {
        switch (contexte.plateforme, contexte.classeHorizontale) {
        case (.bureau, _):
            .barreLaterale
        case (.tactile, .compacte):
            .barreDOnglets
        case (.tactile, .reguliere):
            contexte.estEnPaysage ? .barreLaterale : .barreLateraleRepliee
        }
    }

    /// Vrai quand la navigation prend la forme d une barre d onglets basse.
    public var estUneBarreDOnglets: Bool {
        self == .barreDOnglets
    }

    /// Etat de repli impose par la presentation.
    ///
    /// Une barre d onglets n a pas de repli, la valeur est alors sans effet.
    public var barreLateraleRepliee: Bool {
        self == .barreLateraleRepliee
    }
}

extension Jetons {
    /// Raccourcis clavier de la navigation principale.
    ///
    /// Commande plus le rang de l entree, convention du systeme pour une
    /// navigation a cinq destinations.
    public enum RaccourciDeNavigation {
        /// Touche associee a une destination.
        public static func touche(pour destination: DestinationPrincipale) -> KeyEquivalent {
            KeyEquivalent(Character(String(destination.rang)))
        }

        /// Modificateur associe aux raccourcis de navigation.
        public static let modificateur: EventModifiers = .command

        /// Touche qui replie ou deploie la barre laterale.
        ///
        /// Commande plus Controle plus S, convention du systeme pour cette
        /// bascule. Le document ne la fixe pas, la section 7 impose seulement
        /// que la navigation au clavier existe.
        public static let toucheDeRepli: KeyEquivalent = "s"

        /// Modificateurs de la bascule de repli.
        public static let modificateurDeRepli: EventModifiers = [.command, .control]
    }

    /// Symbole SF Symbols d une destination, tableau 1.10.
    public static func icone(de destination: DestinationPrincipale) -> String {
        switch destination {
        case .bibliotheque: Icone.bibliotheque
        case .historique: Icone.historique
        case .parcourir: Icone.parcourir
        case .rechercher: Icone.rechercher
        case .reglages: Icone.reglages
        }
    }
}
